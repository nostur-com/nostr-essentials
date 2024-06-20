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
    
    public func uploadingPublisher(for mediaRequestBag: MediaRequestBag, keys: Keys) -> AnyPublisher<MediaRequestBag, Error> {
        let authorization = (try? mediaRequestBag.getAuthorizationHeader(keys)) ?? ""
            
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: mediaRequestBag, delegateQueue: nil)
        
        var request = URLRequest(url: mediaRequestBag.apiUrl)
        request.httpMethod = "POST"
        let contentType = "multipart/form-data; boundary=\(mediaRequestBag.boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("\(mediaRequestBag.httpBody.count)", forHTTPHeaderField: "Content-Length")
//        print("Sending header: \(authorization)")
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

public class MediaRequestBag: NSObject, Identifiable, ObservableObject, URLSessionTaskDelegate {
    
    public static func == (lhs: MediaRequestBag, rhs: MediaRequestBag) -> Bool {
        lhs.id == rhs.id
    }

    public var id: String { (sha256hex + apiUrl.absoluteString) }
    
    public var apiUrl: URL
    public var method: String
    public var httpBody: Data
    public var sha256hex: String
    public var boundary: String
    public var contentLength: Int
    
    public var uploadResponse: UploadResponse? {
        didSet {
            self.objectWillChange.send()
            if let status = uploadResponse?.status, status == "processing", let percentage = uploadResponse?.percentage {
                state = .processing(percentage: percentage)
            }
            else if let uploadResponse = uploadResponse {
                if let url = uploadResponse.nip94Event.tags.first(where: { $0.type == "url"} )?.value {
                    
                    if let dim = uploadResponse.nip94Event.tags.first(where: { $0.type == "dim"} )?.value, dim != "0x0" {
                        self.dim = dim
                    }
                    if let hash = uploadResponse.nip94Event.tags.first(where: { $0.type == "x"} )?.value {
                        self.sha256 = hash
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
    @Published public var state: UploadState = .initializing
    @Published public var downloadUrl: String?
    public var dim: String? // "640x480" dimensions of processed image in imeta format  (DIP-01)
    public var sha256: String? // hash of processed image
    
    public var finished: Bool { // helper because we can't do == on enum with param
        switch state {
        case .success(_):
            return true
        default:
            return false
        }
    }
    
    private let uploadtype: String // "avatar" "banner" or "media"
    private let filename: String
    private let mediaData: Data
    public let index: Int
    
    public init(apiUrl: URL, method: String = "POST", uploadtype: String = "media", filename: String = "media.png", mediaData: Data, index: Int = 0) {
        self.apiUrl = apiUrl
        self.method = method
        self.uploadtype = uploadtype
        self.filename = filename
        self.mediaData = mediaData
        self.index = index
        
        let body = NSMutableData()
        
        let contentType = switch filename.suffix(4) {
        case ".3gp":
            "video/3gpp"
        case ".mov":
            "video/quicktime"
        case ".ogg":
            "video/ogg"
        case ".webm":
            "video/webm"
        case ".png":
            "image/png"
        case ".mp4":
            "video/mp4"
        default:
            "image/jpg"
        }
        
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
        let contentLength = self.httpBody.count
        self.contentLength = contentLength
        super.init()
        progressSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] totalBytesSent in
                print("processResponse: totalBytesSent (index: \(index)) \(totalBytesSent)")
                let progress = totalBytesSent / Float(contentLength)
                if progress > 0.01 && progress < 1.0 {
                    self?.state = .uploading(percentage: min(100,Int(ceil(progress * 100))))
                }
            }
            .store(in: &subscriptions)
    }
    
    public func getAuthorizationHeader(_ keys: Keys) throws -> String {
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
    
    // --- MARK: URLSessionTaskDelegate
    
    private var progressSubject = PassthroughSubject<Float, Never>()
    private var subscriptions = Set<AnyCancellable>()
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        progressSubject.send(Float(totalBytesSent))
    }
}

public enum UploadState: Equatable, Hashable {
    case initializing
    case uploading(percentage:Int?)
    case processing(percentage:Int?)
    case success(String)
    case error(message:String)
}
