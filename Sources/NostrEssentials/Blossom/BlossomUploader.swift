//
//  BlossomUploader.swift
//
//
//  Created by Fabian Lachman on 05/05/2025.
//

import Foundation
import SwiftUI
import Combine

public class BlossomUploader: NSObject, ObservableObject {
    
    private let server: URL
    
    private var uploadUrl: URL { server.appendingPathComponent("upload") }
    private var mediaUrl: URL { server.appendingPathComponent("media") }
    private var mirrorUrl: URL { server.appendingPathComponent("mirror") }
    
    @Published public var queued: [BlossomUploadItem] = []
    
    public var total: Int { queued.count }
    public var finished: Bool {
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
    
    public init(_ server: URL) {
        self.server = server
    }
    
    private var subscriptions = Set<AnyCancellable>()
    public var onFinish: (() -> Void)? = nil
    
    public func uploadingPublisher(for uploadItem: BlossomUploadItem) -> AnyPublisher<BlossomUploadItem, Error> {
        
            
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: uploadItem, delegateQueue: nil)
        
        var request = URLRequest(url: uploadItem.verb == .media ? mediaUrl : uploadUrl)
        request.httpMethod = "PUT"
        if let contentType = uploadItem.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue(uploadItem.authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("\(uploadItem.sha256)", forHTTPHeaderField:  "X-SHA-256")
        request.httpBody = uploadItem.mediaData
        
        uploadItem.state = .uploading(percentage: 0)

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
                            let uploadResponse = try decoder.decode(BlossomUploadResponse.self, from: data)
                            DispatchQueue.main.async {
                                self.objectWillChange.send()
                                uploadItem.uploadResponse = uploadResponse
                                promise(.success(uploadItem))
                            }
                        } catch {
                            promise(.failure(error))
                        }
                    case 401, 403:
                        promise(.failure(URLError(.userAuthenticationRequired)))
                    default:
                        promise(.failure(URLError(.badServerResponse)))
                }
            }.resume()
        }.eraseToAnyPublisher()
    }
    
    public func processResponse(uploadItem: BlossomUploadItem) {
        guard let response = uploadItem.uploadResponse else { return }
        self.objectWillChange.send()
        uploadItem.uploadResponse = response
        
        if (self.finished) {
            self.onFinish?()
            self.onFinish = nil
        }
    }
    
    public func uploadingPublishers(for uploadItems: [BlossomUploadItem]) -> AnyPublisher<[BlossomUploadItem], Error> {
        let uploadingPublishers = uploadItems.map { uploadingPublisher(for: $0) }
        return Publishers.MergeMany(uploadingPublishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    public enum Verb: String {
        case get = "get"
        case upload = "upload"
        case media = "media"
        case list = "list"
        case delete = "delete"
    }
    
    // Ask server to download (mirror) the file from some url
    public func mirrorUpload(uploadItem: BlossomUploadItem, authorizationHeader: String? = nil) async throws -> Bool {
        guard let downloadUrl = uploadItem.downloadUrl else { return false }
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            
        var request = URLRequest(url: mirrorUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader ?? uploadItem.authorizationHeader, forHTTPHeaderField: "Authorization")
        
        let body = "{\"url\": \"\(downloadUrl)\"}"
        request.httpBody = body.data(using: .utf8)

        // set content length to body.count
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await session.data(for: request)
        if let response = response as? HTTPURLResponse {
//            print("Response: \(response)")
//            print("Data: \(String(data: data, encoding: .utf8) ?? "No data")")
            return response.statusCode == 200
        }
        return false
    }
}


// Helper to test if a given server url supports uploading
public func testBlossomServer(_ serverURL: URL, testHash: String? = nil, keys: Keys) async throws -> SupportedBlossomType {
    let testHash = testHash ?? "08718084031ef9b9ec91e1aee5b6116db025fba6946534911d720f714a98b961"
    let authorization = (try? getBlossomAuthorizationHeader(keys, sha256hex: testHash, action: .upload)) ?? ""
            
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData // Disable cache
    config.urlCache = nil // Ensure no caching
    let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
    // First try /media endpoint
    var mediaRequest = URLRequest(url: serverURL.appendingPathComponent("media"))
    mediaRequest.httpMethod = "HEAD"
    mediaRequest.setValue("image/png", forHTTPHeaderField: "X-Content-Type")
    mediaRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    mediaRequest.setValue("184292", forHTTPHeaderField: "X-Content-Length")
    mediaRequest.setValue(testHash, forHTTPHeaderField: "X-SHA-256")

    let (_, responseMedia) = try await session.data(for: mediaRequest)
    
    if (responseMedia as? HTTPURLResponse)?.statusCode == 200 {
        return .media
    }
        
    // Try /upload endpoint
    var uploadRequest = URLRequest(url: serverURL.appendingPathComponent("upload"))
    uploadRequest.httpMethod = "HEAD"
    uploadRequest.setValue("image/png", forHTTPHeaderField: "X-Content-Type")
    uploadRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    uploadRequest.setValue("184292", forHTTPHeaderField: "X-Content-Length")
    uploadRequest.setValue(testHash, forHTTPHeaderField: "X-SHA-256")
    
    let (_, responseUpload) = try await session.data(for: uploadRequest)
    
    if (responseUpload as? HTTPURLResponse)?.statusCode == 200 {
        return .upload
    }
    
    if (responseUpload as? HTTPURLResponse)?.statusCode == 401 || (responseUpload as? HTTPURLResponse)?.statusCode == 403 {
        return .unauthorized
    }
    
    if (responseMedia as? HTTPURLResponse)?.statusCode == 401 || (responseMedia as? HTTPURLResponse)?.statusCode == 403 {
        return .unauthorized
    }
    
    return .none
}

// Helper to test if a given server url supports uploading
public func testBlossomServer(_ serverURL: URL, authorization: String) async throws -> SupportedBlossomType {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData // Disable cache
    config.urlCache = nil // Ensure no caching
    let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        
    // First try /media endpoint
    var mediaRequest = URLRequest(url: serverURL.appendingPathComponent("media"))
    mediaRequest.httpMethod = "HEAD"
    mediaRequest.setValue("image/png", forHTTPHeaderField: "X-Content-Type")
    mediaRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    mediaRequest.setValue("184292", forHTTPHeaderField: "X-Content-Length")

    let (_, responseMedia) = try await session.data(for: mediaRequest)
    
    if (responseMedia as? HTTPURLResponse)?.statusCode == 200 {
        return .media
    }
        
    // Try /upload endpoint
    var uploadRequest = URLRequest(url: serverURL.appendingPathComponent("upload"))
    uploadRequest.httpMethod = "HEAD"
    uploadRequest.setValue("image/png", forHTTPHeaderField: "X-Content-Type")
    uploadRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    uploadRequest.setValue("184292", forHTTPHeaderField: "X-Content-Length")
    
    let (_, responseUpload) = try await session.data(for: uploadRequest)
    
    if (responseUpload as? HTTPURLResponse)?.statusCode == 200 {
        return .upload
    }
    
    if (responseUpload as? HTTPURLResponse)?.statusCode == 401 || (responseUpload as? HTTPURLResponse)?.statusCode == 403 {
        return .unauthorized
    }
    
    if (responseMedia as? HTTPURLResponse)?.statusCode == 401 || (responseMedia as? HTTPURLResponse)?.statusCode == 403 {
        return .unauthorized
    }
    
    return .none
}

public enum SupportedBlossomType {
    case media
    case upload
    case unauthorized
    case none
}

public func getBlossomAuthorizationHeader(_ keys: Keys, sha256hex: String, action: BlossomUploader.Verb = .upload) throws -> String {
                    
    // 5 minutes from now timestamp
    let expirationTimestamp = Int(Date().timeIntervalSince1970) + 300
    
    var unsignedEvent = Event(
        pubkey: keys.publicKeyHex,
        content: "Upload",
        kind: 24242,
        tags: [
            Tag(["t", action.rawValue]),
            Tag(["x", sha256hex]), // hash of file
            Tag(["expiration", expirationTimestamp.description]),
        ]
    )
    
    let signedEvent = try unsignedEvent.sign(keys)

    guard let base64 = signedEvent.base64() else { throw NSError(domain: "Unable to create json() or base64", code: 999) }
    return "Nostr \(base64)"
}
