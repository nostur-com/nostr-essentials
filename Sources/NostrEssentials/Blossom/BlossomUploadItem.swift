//
//  BlossomUploadItem.swift
//  NostrEssentials
//
//  Created by Fabian Lachman on 05/05/2025.
//

import Foundation
import Combine

public class BlossomUploadItem: NSObject, Identifiable, ObservableObject, URLSessionTaskDelegate {
    
    public static func == (lhs: BlossomUploadItem, rhs: BlossomUploadItem) -> Bool {
        lhs.id == rhs.id
    }

    public var id: String { sha256 + index.description }

    public var contentType: String?
    public var sha256: String
    public var sha256processed: String?
    public var authorizationHeader: String
    
    public var uploadResponse: BlossomUploadResponse? {
        didSet {
            self.objectWillChange.send()
            if let uploadResponse = uploadResponse {
                if let nip94 = uploadResponse.nip94 {
                    if let dim = nip94.first(where: { $0.type == "dim"} )?.value, dim != "0x0" && dim != "" {
                        self.dim = dim
                    }
                    
                    if let hash = nip94.first(where: { $0.type == "x"} )?.value, hash != "" {
                        self.sha256processed = hash
                    }
                    
                    if let url = nip94.first(where: { $0.type == "url"} )?.value, !url.isEmpty {
                        self.downloadUrl = url
                        state = .success(url)
                    }
                }
                
                if self.sha256processed == nil {
                    self.sha256processed = uploadResponse.sha256
                }
                
                if self.downloadUrl == nil {
                    self.downloadUrl = uploadResponse.url
                    state = .success(uploadResponse.url)
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
    
    public var finished: Bool { // helper because we can't do == on enum with param
        switch state {
        case .success(_):
            return true
        default:
            return false
        }
    }
    
    public let mediaData: Data
    public let index: Int
    
    public init(data: Data, index: Int = 0, contentType: String? = nil, authorizationHeader: String) {
        self.index = index
        self.sha256 = data.sha256().hexEncodedString()
        let contentLength = data.count
        self.mediaData = data
        self.contentType = contentType
        self.authorizationHeader = authorizationHeader
        
        super.init()
        
        progressSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] totalBytesSent in
                guard let self else { return }
                let progress = totalBytesSent / Float(contentLength)
                if progress > 0.01 && progress < 1.0 {
                    self.state = .uploading(percentage: min(100,Int(ceil(progress * 100))))
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
