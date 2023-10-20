//
//  Nip96Uploader.swift
//
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation
import SwiftUI
import Combine

public class Nip96Uploader: ObservableObject {
    
    @Published public var state:uploadState = .initializing
    
    private var subscriptions = Set<AnyCancellable>()
    
    public func uploadingPublisher(for mediaRequestParams: MediaRequestParams, authorization:String) throws -> AnyPublisher<UploadResponse, Error> {
        
        guard let url = URL(string: mediaRequestParams.apiUrl) else { throw errors.invalidApiUrl }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let contentType = "multipart/form-data; boundary=\(mediaRequestParams.boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = mediaRequestParams.httpBody
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .tryMap() { element -> Data in
                guard let httpResponse = element.response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 || httpResponse.statusCode == 202
                else { throw URLError(.badServerResponse) }
                return element.data
            }
            .decode(type: UploadResponse.self, decoder: decoder)
            .eraseToAnyPublisher()
    }
    
    public func checkStatus(for mediaRequestParams: MediaRequestParams, authorization:String) throws -> AnyPublisher<UploadResponse, Error> {
        guard let url = URL(string: mediaRequestParams.apiUrl) else { throw errors.invalidApiUrl }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let timer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
        
        return timer
            .flatMap { _ in
                URLSession.shared.dataTaskPublisher(for: url)
                    .map(\.data)
                    .decode(type: UploadResponse.self, decoder: decoder)
                    .eraseToAnyPublisher()
            }
            .timeout(.seconds(60), scheduler: DispatchQueue.main, customError: { URLError(.timedOut) })
            .eraseToAnyPublisher()
    }
    
    public func processResponse(_ response:UploadResponse, mediaRequestParams:MediaRequestParams, authorization:String) {
        switch response.status {
        case "processing":
            state = .processing(percentage: response.percentage ?? 0)
            do {
                try checkStatus(for: mediaRequestParams, authorization: authorization)
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { response in
                            if response.status == "processing" {
                                self.state = .processing(percentage: response.percentage ?? 0)
                            }
                            else if response.status == "completed" || response.status == "success"  {
                                if let url = response.nip94Event.tags.first(where: { $0.type == "url"} )?.value {
                                    self.state = .success(url: url)
                                }
                                else {
                                    self.state = .error(message: "Media service did not return url")
                                }
                            }
                        })
                    .store(in: &self.subscriptions)
            }
            catch errors.invalidApiUrl {
                state = .error(message: "invalid api url")
            }
            catch {
                state = .error(message: "other error")
            }
        case "success", "completed":
            if let url = response.nip94Event.tags.first(where: { $0.type == "url"} )?.value {
                state = .success(url: url)
            }
            else {
                state = .error(message: "Media service did not return url")
            }
        default:
            return
        }
    }
    
    public enum uploadState {
        case initializing
        case uploading
        case processing(percentage:Int?)
        case success(url:String)
        case error(message:String)
    }
}

public enum errors: Error {
    case invalidApiUrl
}

public struct MediaRequestParams {
    
    public var apiUrl:String
    public var method:String
    public var httpBody:Data
    public var sha256hex:String
    public var boundary:String
    
    private let uploadtype:String // "avatar" "banner" or "media"
    private let filename:String
    private let mediaData:Data
    
    public init(apiUrl:String, method:String = "POST", uploadtype: String = "media", filename: String = "media.png", mediaData: Data) {
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
}
