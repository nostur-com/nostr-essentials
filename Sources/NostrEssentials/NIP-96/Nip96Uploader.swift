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

public class Nip96Uploader: ObservableObject {
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
    
    public init() { }
    
    private var subscriptions = Set<AnyCancellable>()
    
    public func uploadingPublisher(for mediaRequestBag: MediaRequestBag, keys: Keys) -> AnyPublisher<MediaRequestBag, Error> {
        let authorization = (try? mediaRequestBag.getAuthorizationHeader(keys)) ?? ""
        var request = URLRequest(url: mediaRequestBag.apiUrl)
        request.httpMethod = "POST"
        let contentType = "multipart/form-data; boundary=\(mediaRequestBag.boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = mediaRequestBag.httpBody
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        queued.append(mediaRequestBag)
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .tryMap() { element -> Data in
                let httpResponse = element.response as? HTTPURLResponse
                switch httpResponse?.statusCode {
                case 200,202:
                    return element.data
                case 401:
                    throw URLError(.userAuthenticationRequired)
                default:
                    throw URLError(.badServerResponse)
                }
            }
            .decode(type: UploadResponse.self, decoder: decoder)
            .receive(on: RunLoop.main)
            .map { response in
                mediaRequestBag.uploadResponse = response
                return mediaRequestBag
            }
            .eraseToAnyPublisher()
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
    
    public var uploadResponse:UploadResponse? {
        didSet {
            if let status = uploadResponse?.status, status == "processing", let percentage = uploadResponse?.percentage {
                state = .processing(percentage: percentage)
            }
            else if let url = uploadResponse?.nip94Event.tags.first(where: { $0.type == "url"} )?.value {
                downloadUrl = url
                state = .success(url)
            }
            else {
                state = .error(message: "Media service did not return url")
            }
        }
    }
    @Published public var state:UploadState = .initializing
    @Published public var downloadUrl:String?
    
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
        
        let boundary = UUID().uuidString
        self.boundary = boundary
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mediafile\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(mediaData)
        
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploadtype\"\r\n\r\n".data(using: .utf8)!)
        body.append(uploadtype.data(using: .utf8)!)
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        self.httpBody = body as Data
        self.sha256hex = self.httpBody.sha256().hexEncodedString()
    }
    
    public func getAuthorizationHeader(_ keys:Keys) throws -> String {
        var unsignedEvent = Event(
            pubkey: keys.publicKeyHex,
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", apiUrl.absoluteString]),
                Tag(["method", method]),
                Tag(["payload", sha256hex]), // hash request.httpBody with upload-test.png as payload
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        guard let base64 = signedEvent.base64() else { throw NSError(domain: "Unable to create json() or base64", code: 999) }
        return "Nostr \(base64)"
    }
}

public class MultiUpload: ObservableObject {
    public let mediaRequestBag:MediaRequestBag
    @Published public var state:UploadState = .initializing
    
    init(mediaRequestBag: MediaRequestBag) {
        self.mediaRequestBag = mediaRequestBag
        self.state = state
    }
}

public enum UploadState {
    case initializing
    case uploading
    case processing(percentage:Int?)
    case success(String)
    case error(message:String)
}
