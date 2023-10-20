//
//  Nip96Tests.swift
//  
//
//  Created by Fabian Lachman on 18/10/2023.
//

import XCTest
@testable import NostrEssentials
import Combine

final class Nip96Tests: XCTestCase {
    
    private var subscriptions: Set<AnyCancellable> = []
    
    override func setUpWithError() throws {
        subscriptions = []
    }
    
    func testDecodeNip96WellKnownJson() throws {
        // Response taken from https://nostrcheck.me/.well-known/nostr/nip96.json
        let response = ###"{"api_url":"https://nostrcheck.me/api/v2/media","download_url":"https://nostrcheck.me/media","supported_nips":[1,78,94,96,98],"tos_url":"https://nostrcheck.me/register/tos.php","content_types":["image/png","image/jpg","image/jpeg","image/gif","image/webp","video/mp4","video/quicktime","video/mpeg","video/webm","audio/mpeg","audio/mpg","audio/mpeg3","audio/mp3"],"plans":{"free":{"name":"Free Tier","is_nip98_required":false,"url":"","max_byte_size":104857600,"file_expiration":[0,0],"media_transformations":{"image":["resizing","format_conversion","compression"],"video":["resizing","format_conversion","compression"]}}}}"###
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let nip96wellKnown = try decoder.decode(NIP96WellKnown.self, from: response.data(using: .utf8)!)
        
        XCTAssertEqual(nip96wellKnown.apiUrl, "https://nostrcheck.me/api/v2/media")
        XCTAssertEqual(nip96wellKnown.downloadUrl, "https://nostrcheck.me/media")
        XCTAssertEqual(nip96wellKnown.supportedNips, [1,78,94,96,98])
        XCTAssertEqual(nip96wellKnown.tosUrl, "https://nostrcheck.me/register/tos.php")
        XCTAssertEqual(nip96wellKnown.contentTypes, ["image/png","image/jpg","image/jpeg","image/gif","image/webp","video/mp4","video/quicktime","video/mpeg","video/webm","audio/mpeg","audio/mpg","audio/mpeg3","audio/mp3"])
    }
    
    func testMediaUpload() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
//        let filepath = Bundle.module.url(forResource: "nostur-add-nsecbunker", withExtension: "mov")
        let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png")
        let imageData = try Data(contentsOf: filepath!)
        let mediaRequestParams = MediaRequestParams(apiUrl: "https://nostrcheck.me/api/v2/media", mediaData: imageData)
        let uploader = Nip96Uploader()
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", mediaRequestParams.apiUrl]),
                Tag(["method", mediaRequestParams.method]),
                Tag(["payload", mediaRequestParams.sha256hex]), // hash request.httpBody with upload-test.png as payload
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        //        print(NSString(string:signedEvent.json()!))
        //        print(NSString(string:signedEvent.base64()!))
        
        guard let base64 = signedEvent.base64() else { throw NSError(domain: "Error", code: 999) }
        let authorization = "Nostr \(base64)"
        
        let expectation = self.expectation(description: "testMediaUpload")
        
        try uploader.uploadingPublisher(for: mediaRequestParams, authorization: authorization)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { response in
                uploader.processResponse(response, mediaRequestParams: mediaRequestParams, authorization: authorization)
            })
            .store(in: &subscriptions)
        
        // Awaiting fulfilment of our expecation before
        // performing our asserts:
        waitForExpectations(timeout: 10)
        
        // Asserting that our Combine pipeline yielded the
        // correct output:
        switch uploader.state {
        case .success(let url):
            XCTAssert(true)
            print("Success: \(url)")
        case .error(let message):
            XCTFail("Expected .success state, error: \(message)")
        case .initializing:
            XCTFail("Expected .success state, still .initializing")
        case .uploading:
            XCTFail("Expected .success state, still .uploading")
        case .processing(let percentage):
            XCTFail("Expected .success state, still .processing: \(percentage ?? 0)")
        }
    }
}
