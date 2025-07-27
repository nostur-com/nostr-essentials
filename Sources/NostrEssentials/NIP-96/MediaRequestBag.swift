//
//  MediaRequestBag.swift
//  NostrEssentials
//
//  Created by Fabian Lachman on 05/05/2025.
//

import Foundation
import SwiftUI
import Combine

public class MediaRequestBag: NSObject, Identifiable, ObservableObject, URLSessionTaskDelegate {
    
    public static func == (lhs: MediaRequestBag, rhs: MediaRequestBag) -> Bool {
        lhs.id == rhs.id
    }

    public var id: String { (sha256hex + apiUrl.absoluteString) }
    
    public var apiUrl: URL
    public var method: String
    public var httpBody: Data
    public var sha256hex: String // http body
    public var sha256file: String // hash of file
    public var boundary: String
    public var contentLength: Int
    public var authorizationHeader: String
    
    public var uploadResponse: UploadResponse? {
        didSet {
            self.objectWillChange.send()
            if let status = uploadResponse?.status, status == "processing", let percentage = uploadResponse?.percentage {
                state = .processing(percentage: percentage)
            }
            else if let uploadResponse = uploadResponse {
                if let url = uploadResponse.nip94Event.tags.first(where: { $0.type == "url"} )?.value, !url.isEmpty {
                    
                    if let dim = uploadResponse.nip94Event.tags.first(where: { $0.type == "dim"} )?.value, dim != "0x0" && dim != "" {
                        self.dim = dim
                    }
                    if let hash = uploadResponse.nip94Event.tags.first(where: { $0.type == "x"} )?.value, hash != "" {
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
    public var blurhash: String?
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
    
    public init(apiUrl: URL, method: String = "POST", uploadtype: String = "media", filename: String = "media.png", mediaData: Data, index: Int = 0, authorizationHeader: String, boundary: String, blurhash: String? = nil) {
        self.apiUrl = apiUrl
        self.method = method
        self.uploadtype = uploadtype
        self.filename = filename
        self.mediaData = mediaData
        self.index = index
        self.authorizationHeader = authorizationHeader
        self.blurhash = blurhash
              
        let contentType = contentType(for: filename)
        self.boundary = boundary
        self.httpBody = makeHttpBody(mediaData: mediaData, contentType: contentType, filename: filename, uploadtype: uploadtype, boundary: boundary)
        self.sha256file = mediaData.sha256().hexEncodedString()
        self.sha256hex = httpBody.sha256().hexEncodedString()
        let contentLength = self.httpBody.count
        self.contentLength = contentLength
        super.init()
        progressSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] totalBytesSent in
//                print("processResponse: totalBytesSent (index: \(index)) \(totalBytesSent)")
                let progress = totalBytesSent / Float(contentLength)
                if progress > 0.01 && progress < 1.0 {
                    self?.state = .uploading(percentage: min(100,Int(ceil(progress * 100))))
                }
            }
            .store(in: &subscriptions)
    }
    
    // --- MARK: URLSessionTaskDelegate
    
    private var progressSubject = PassthroughSubject<Float, Never>()
    private var subscriptions = Set<AnyCancellable>()
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        progressSubject.send(Float(totalBytesSent))
    }
}


public func makeHttpBody(mediaData: Data, contentType: String, filename: String = "media.png",  uploadtype: String = "media", boundary: String) -> Data {
   
    let body = NSMutableData()
    
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"mediafile\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
    body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
    body.append(mediaData)
    
    body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"uploadtype\"\r\n\r\n".data(using: .utf8)!)
    body.append(uploadtype.data(using: .utf8)!)
    
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    
    return (body as Data)
}

public func contentType(for filename: String) -> String {
    return switch filename.suffix(4) {
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
    case ".m4a":
        "audio/mp4"
    default:
        "image/jpeg"
    }
}
