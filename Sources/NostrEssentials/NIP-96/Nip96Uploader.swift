//
//  Nip96Uploader.swift
//
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation
import SwiftUI
import Combine
import Collections

public class Nip96Uploader: NSObject, ObservableObject, URLSessionTaskDelegate {
    @Published public var queued:OrderedSet<MediaRequestBag> = []
    
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
    
    
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        progressSubject.send(Float(totalBytesSent))
    }
    
    private var progressSubject = PassthroughSubject<Float, Never>()
    private var subscriptions = Set<AnyCancellable>()
    
    public func uploadingPublisher(for mediaRequestBag: MediaRequestBag, keys: Keys) -> AnyPublisher<MediaRequestBag, Error> {
        let authorization = (try? mediaRequestBag.getAuthorizationHeader(keys)) ?? ""
            
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: mediaRequestBag.apiUrl)
        request.httpMethod = "POST"
        let contentType = "multipart/form-data; boundary=\(mediaRequestBag.boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("\(mediaRequestBag.httpBody.count)", forHTTPHeaderField: "Content-Length")
//        print("Sending header: \(authorization)")
        request.httpBody = mediaRequestBag.httpBody
        
        mediaRequestBag.state = .uploading(percentage: 0)
        progressSubject
            .receive(on: RunLoop.main)
            .sink { totalBytesSent in
                let progress = totalBytesSent / Float(mediaRequestBag.contentLength)
                if progress > 0.01 && progress < 1.0 {
                    mediaRequestBag.state = .uploading(percentage: min(100,Int(ceil(progress * 100))))
                }
            }
            .store(in: &subscriptions)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        queued.append(mediaRequestBag)

        return Future { promise in
            session.dataTask(with: request) { (data, response, error) in
                guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                    promise(.failure(URLError(.badServerResponse)))
                    return
                }
                switch httpResponse.statusCode {
                    case 200, 201, 202:
                        do {
                            let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
                            DispatchQueue.main.async {
                                mediaRequestBag.uploadResponse = uploadResponse
                            }
                            promise(.success(mediaRequestBag))
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
//                        print("Media uploading (checkStatus): UploadResponse: \(response)")
                        mediaRequestBag.uploadResponse = response
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
//                        print("Media uploading (processResponse): UploadResponse: \(response)")
                        if response.status == "processing" {
                            mediaRequestBag.state = .processing(percentage: response.percentage ?? 0)
                        }
                        else if response.status == "completed" || response.status == "success"  {
                            mediaRequestBag.uploadResponse = response
                        }
                    })
                .store(in: &self.subscriptions)
            
        case "success", "completed":
            mediaRequestBag.uploadResponse = response
        default:
            return
        }
    }
    
    public func uploadingPublishers(for multipleMediaRequestBag: [MediaRequestBag], keys: Keys) -> AnyPublisher<[MediaRequestBag], Error> {
        let uploadingPublishers = multipleMediaRequestBag.map { uploadingPublisher(for: $0, keys: keys) }
        return Publishers.MergeMany(uploadingPublishers)
            .collect()
            .eraseToAnyPublisher()
    }
}

public enum errors: Error {
    case invalidApiUrl
}

public class MediaRequestBag: Hashable, Identifiable, ObservableObject {
        
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MediaRequestBag, rhs: MediaRequestBag) -> Bool {
        lhs.id == rhs.id
    }

    public var id:String { (sha256hex + apiUrl.absoluteString) }
    
    public var apiUrl:URL
    public var method:String
    public var httpBody:Data
    public var sha256hex:String
    public var boundary:String
    public var contentLength:Int
    
    public var uploadResponse:UploadResponse? {
        didSet {
            if let status = uploadResponse?.status, status == "processing", let percentage = uploadResponse?.percentage {
                state = .processing(percentage: percentage)
            }
            else if let uploadResponse = uploadResponse {
                if let url = uploadResponse.nip94Event.tags.first(where: { $0.type == "url"} )?.value {
                    
                    if let dim = uploadResponse.nip94Event.tags.first(where: { $0.type == "dim"} )?.value {
                        self.dim = dim
                    }
                    if let hash = uploadResponse.nip94Event.tags.first(where: { $0.type == "x"} )?.value {
                        self.hash = hash
                    }
                    
                    downloadUrl = url
                    state = .success(url)
                }
                else {
                    state = .error(message: "Media service did not return url")
                }
            }
            else {
                state = .error(message: "Media service did not return url")
            }
        }
    }
    @Published public var state:UploadState = .initializing
    @Published public var downloadUrl:String?
    public var dim:String? // "640x480" dimensions of processed image in imeta format  (DIP-01)
    public var hash:String? // hash of processed image
    
    public var finished:Bool { // helper because we can't do == on enum with param
        switch state {
        case .success(_):
            return true
        default:
            return false
        }
    }
    
    private let uploadtype:String // "avatar" "banner" or "media"
    private let filename:String
    private let mediaData:Data
    
    public init(apiUrl:URL, method:String = "POST", uploadtype: String = "media", filename: String = "media.png", mediaData: Data) {
        self.apiUrl = apiUrl
        self.method = method
        self.uploadtype = uploadtype
        self.filename = filename
        self.mediaData = mediaData
        
        let body = NSMutableData()
        
        let contentType = filename.suffix(4) == ".png" ? "image/png" : "image/jpg"
        
        let boundary = UUID().uuidString
        self.boundary = boundary
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mediafile\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(mediaData)
        
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploadtype\"\r\n\r\n".data(using: .utf8)!)
        body.append(uploadtype.data(using: .utf8)!)
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        self.httpBody = body as Data
        
        self.sha256hex = httpBody.sha256().hexEncodedString()
        self.contentLength = self.httpBody.count
    }
    
    public func getAuthorizationHeader(_ keys:Keys) throws -> String {
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
//        print("Sending 27235: \(signedEvent.json() ?? "")")
        guard let base64 = signedEvent.base64() else { throw NSError(domain: "Unable to create json() or base64", code: 999) }
        return "Nostr \(base64)"
    }
}

public enum UploadState {
    case initializing
    case uploading(percentage:Int?)
    case processing(percentage:Int?)
    case success(String)
    case error(message:String)
}
