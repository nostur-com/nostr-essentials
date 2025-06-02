//
//  Nip96Uploader.swift
//
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation
import SwiftUI
import Combine

public class Nip96Uploader: NSObject, ObservableObject {
    @Published public var queued:[MediaRequestBag] = []
    
    public var total:Int { queued.count }
    public var finished:Bool {
        let successCount = queued.filter({ bag in
            switch bag.state {
            case .success(_):
                return true
            default:
                return false
            }
        }).count
        return total == successCount && total != 0
    }
    
    public override init() { }
    
    private var subscriptions = Set<AnyCancellable>()
    public var onFinish: (() -> Void)? = nil
    
    public func uploadingPublisher(for mediaRequestBag: MediaRequestBag) -> AnyPublisher<MediaRequestBag, Error> {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: mediaRequestBag, delegateQueue: nil)
        
        var request = URLRequest(url: mediaRequestBag.apiUrl)
        request.httpMethod = "POST"
        let contentType = "multipart/form-data; boundary=\(mediaRequestBag.boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(mediaRequestBag.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("\(mediaRequestBag.httpBody.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = mediaRequestBag.httpBody
        
        mediaRequestBag.state = .uploading(percentage: 0)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase        

        return Future { promise in
            session.dataTask(with: request) { (data, response, error) in
                guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                    promise(.failure(URLError(.badServerResponse)))
                    return
                }
                
//                print("Response: \(httpResponse)")
//                print("Data: \(String(data: data, encoding: .utf8) ?? "No data")")
                
                switch httpResponse.statusCode {
                    case 200, 201, 202:
                        do {
                            let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
                            DispatchQueue.main.async {
                                self.objectWillChange.send()
                                mediaRequestBag.uploadResponse = uploadResponse
                                promise(.success(mediaRequestBag))
                            }
                        } catch {
                            promise(.failure(error))
                        }
                    case 401:
                        promise(.failure(URLError(.userAuthenticationRequired)))
                    default:
                        promise(.failure(URLError(.badServerResponse)))
                }
            }.resume()
        }.eraseToAnyPublisher()
    }

    
    public func checkStatus(for mediaRequestBag: MediaRequestBag) -> AnyPublisher<MediaRequestBag, Error> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let timer = Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
        
        return timer
            .flatMap { _ in
                URLSession.shared.dataTaskPublisher(for: mediaRequestBag.apiUrl)
                    .map(\.data)
                    .decode(type: UploadResponse.self, decoder: decoder)
                    .receive(on: RunLoop.main)
                    .map { response in
                        self.objectWillChange.send()
                        mediaRequestBag.uploadResponse = response
                        if (self.finished) {
                            self.onFinish?()
                            self.onFinish = nil
                        }
                        return mediaRequestBag
                    }
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(60), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .eraseToAnyPublisher()
    }
    
    public func processResponse(mediaRequestBag:MediaRequestBag) {
        guard let response = mediaRequestBag.uploadResponse else { return }
        switch response.status {
        case "processing":
            mediaRequestBag.state = .processing(percentage: response.percentage ?? 0)
            checkStatus(for: mediaRequestBag)
                .receive(on: RunLoop.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { mediaRequestBag in
                        guard let response = mediaRequestBag.uploadResponse else { return }
                        if response.status == "processing" {
                            self.objectWillChange.send()
                            mediaRequestBag.state = .processing(percentage: response.percentage ?? 0)
                        }
                        else if response.status == "completed" || response.status == "success"  {
                            self.objectWillChange.send()
                            mediaRequestBag.uploadResponse = response
                        }
                    })
                .store(in: &self.subscriptions)
            
        case "success", "completed":
            self.objectWillChange.send()
            mediaRequestBag.uploadResponse = response
            
            if (self.finished) {
                self.onFinish?()
                self.onFinish = nil
            }
        default:
            return
        }
    }
    
    public func uploadingPublishers(for multipleMediaRequestBag: [MediaRequestBag]) -> AnyPublisher<[MediaRequestBag], Error> {
        let uploadingPublishers = multipleMediaRequestBag.map { uploadingPublisher(for: $0) }
        return Publishers.MergeMany(uploadingPublishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    public static func getAuthorizationHeader(_ keys: Keys, apiUrl: URL, method: String, sha256hex: String) throws -> String {
        var unsignedEvent = Event(
            pubkey: keys.publicKeyHex,
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", apiUrl.absoluteString]),
                Tag(["method", method]),
                Tag(["payload", sha256hex]), // hash of entire request.httpBody
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)

        guard let base64 = signedEvent.base64() else { throw NSError(domain: "Unable to create json() or base64", code: 999) }
        return "Nostr \(base64)"
    }
}

public enum errors: Error {
    case invalidApiUrl
}

public enum UploadState: Equatable, Hashable {
    case initializing
    case uploading(percentage: Int?)
    case processing(percentage: Int?)
    case success(String)
    case error(message: String)
}
