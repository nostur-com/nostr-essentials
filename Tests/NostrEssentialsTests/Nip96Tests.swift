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
        let mediaRequestBag = MediaRequestBag(apiUrl: URL(string: "https://nostrcheck.me/api/v2/media")!, mediaData: imageData)
        let uploader = Nip96Uploader()
                
        let expectation = self.expectation(description: "testMediaUpload")
        
        uploader.uploadingPublisher(for: mediaRequestBag, keys: keys)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { mediaRequestBag in
                uploader.processResponse(mediaRequestBag: mediaRequestBag)
            })
            .store(in: &subscriptions)
        
        // Awaiting fulfilment of our expecation before
        // performing our asserts:
        waitForExpectations(timeout: 10)
        
        XCTAssertTrue(uploader.finished)
        print(uploader.queued.first?.downloadUrl ?? "?")
//        switch uploader.state {
//        case .success(let url):
//            
//            print("Success: \(url)")
//        case .error(let message):
//            XCTFail("Expected .success state, error: \(message)")
//        case .initializing:
//            XCTFail("Expected .success state, still .initializing")
//        case .uploading:
//            XCTFail("Expected .success state, still .uploading")
//        case .processing(let percentage):
//            XCTFail("Expected .success state, still .processing: \(percentage ?? 0)")
//        }
    }
    
    func testMediaUploads() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        let apiUrl = URL(string: "https://nostrcheck.me/api/v2/media")!
//        let filepath = Bundle.module.url(forResource: "nostur-add-nsecbunker", withExtension: "mov")
        let filepath1 = Bundle.module.url(forResource: "upload-test", withExtension: "png")
        let imageData1 = try Data(contentsOf: filepath1!)
        let mediaRequestBag1 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData1)
        
        let filepath2 = Bundle.module.url(forResource: "bitcoin", withExtension: "png")
        let imageData2 = try Data(contentsOf: filepath2!)
        let mediaRequestBag2 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData2)
        
        let filepath3 = Bundle.module.url(forResource: "coffeechain", withExtension: "png")
        let imageData3 = try Data(contentsOf: filepath3!)
        let mediaRequestBag3 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData3)
        
        let filepath4 = Bundle.module.url(forResource: "beerstr", withExtension: "png")
        let imageData4 = try Data(contentsOf: filepath4!)
        let mediaRequestBag4 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData4)
        
        let uploader = Nip96Uploader()
        
        let expectation = self.expectation(description: "testMediaUpload")
        
        let mediaRequestBags = [mediaRequestBag1, mediaRequestBag2, mediaRequestBag3, mediaRequestBag4]
        
        uploader.uploadingPublishers(for: mediaRequestBags, keys: keys)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { mediaRequestBags in
                for mediaRequestBag in mediaRequestBags {
                    uploader.processResponse(mediaRequestBag: mediaRequestBag)
                }
            })
            .store(in: &subscriptions)
        
        // Awaiting fulfilment of our expecation before
        // performing our asserts:
        waitForExpectations(timeout: 10)
        
        // Asserting that our Combine pipeline yielded the
        // correct output:
        XCTAssertTrue(uploader.finished)
        XCTAssertEqual(uploader.queued.filter { $0.finished }.count, 4)
        for item in uploader.queued {
            print(item.downloadUrl ?? "?")
        }
    }
}
