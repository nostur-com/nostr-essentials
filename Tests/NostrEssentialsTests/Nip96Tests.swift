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
        // pubkey: 1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448
        // npub: npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7
        
//        let filepath = Bundle.module.url(forResource: "nostur-add-nsecbunker", withExtension: "mov")
        let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png")
//        let filepath = Bundle.module.url(forResource: "30mb", withExtension: "jpg")
        let imageData = try Data(contentsOf: filepath!)
        
        
        let apiUrl = URL(string: "http://localhost:8080/wp-json/nostrmedia/v1/upload/")!
//        let apiUrl = URL(string: "https://media.utxo.nl/wp-json/nostrmedia/v1/upload/")!
//        let apiUrl = URL(string: "https://nostrcheck.me/api/v2/media")!
        
        // Need http body to calculate hash
        let boundary = UUID().uuidString
        let body = makeHttpBody(mediaData: imageData, contentType: "image/png", filename: "upload-test.png", uploadtype: "media", boundary: boundary)
        
        let sha256hex = body.sha256().hexEncodedString()
        
        let authorizationHeader = try Nip96Uploader.getAuthorizationHeader(keys, apiUrl: apiUrl, method: "POST", sha256hex: sha256hex)
        
        let mediaRequestBag = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData, authorizationHeader: authorizationHeader, boundary: boundary)
        let uploader = Nip96Uploader()
        
        
        
        uploader.queued = [mediaRequestBag]
                
        let expectation = self.expectation(description: "testMediaUpload")
        
        uploader.uploadingPublisher(for: mediaRequestBag)
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
    
    func testMultipleMediaUploads() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
//        let apiUrl = URL(string: "https://nostrcheck.me/api/v2/media")!
        let apiUrl = URL(string: "http://localhost:8080/wp-json/nostrmedia/v1/upload/")!
        let boundary = UUID().uuidString
//        let filepath = Bundle.module.url(forResource: "nostur-add-nsecbunker", withExtension: "mov")
        let filepath1 = Bundle.module.url(forResource: "upload-test", withExtension: "png")
        let imageData1 = try Data(contentsOf: filepath1!)
        
        
        // Need http body to calculate hash
        let body1 = makeHttpBody(mediaData: imageData1, contentType: "image/png", filename: "upload-test.png", uploadtype: "media", boundary: boundary)
        
        let authorizationHeader = try Nip96Uploader.getAuthorizationHeader(keys, apiUrl: apiUrl, method: "POST", sha256hex: body1.sha256().hexEncodedString())
        
        let mediaRequestBag1 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData1, authorizationHeader: authorizationHeader, boundary: boundary)
        
        let filepath2 = Bundle.module.url(forResource: "bitcoin", withExtension: "png")
        let imageData2 = try Data(contentsOf: filepath2!)
        
        // Need http body to calculate hash
        let body2 = makeHttpBody(mediaData: imageData1, contentType: "image/png", filename: "bitcoin.png", uploadtype: "media", boundary: boundary)
        
        let authorizationHeader2 = try Nip96Uploader.getAuthorizationHeader(keys, apiUrl: apiUrl, method: "POST", sha256hex: body2.sha256().hexEncodedString())
        
        let mediaRequestBag2 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData2, authorizationHeader: authorizationHeader2, boundary: boundary)
        
        let filepath3 = Bundle.module.url(forResource: "coffeechain", withExtension: "png")
        let imageData3 = try Data(contentsOf: filepath3!)
        
        // Need http body to calculate hash
        let body3 = makeHttpBody(mediaData: imageData3, contentType: "image/png", filename: "coffeechain.png", uploadtype: "media", boundary: boundary)
        
        let authorizationHeader3 = try Nip96Uploader.getAuthorizationHeader(keys, apiUrl: apiUrl, method: "POST", sha256hex: body3.sha256().hexEncodedString())
        
        let mediaRequestBag3 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData3, authorizationHeader: authorizationHeader3, boundary: boundary)
        
        let filepath4 = Bundle.module.url(forResource: "beerstr", withExtension: "png")
        let imageData4 = try Data(contentsOf: filepath4!)
        
        // Need http body to calculate hash
        let body4 = makeHttpBody(mediaData: imageData4, contentType: "image/png", filename: "beerstr.png", uploadtype: "media", boundary: boundary)
        
        let authorizationHeader4 = try Nip96Uploader.getAuthorizationHeader(keys, apiUrl: apiUrl, method: "POST", sha256hex: body4.sha256().hexEncodedString())
        
        let mediaRequestBag4 = MediaRequestBag(apiUrl: apiUrl, mediaData: imageData4, authorizationHeader: authorizationHeader4, boundary: boundary)
        
        let uploader = Nip96Uploader()
        
        let expectation = self.expectation(description: "testMediaUpload")
        
        let mediaRequestBags = [mediaRequestBag1, mediaRequestBag2, mediaRequestBag3, mediaRequestBag4]
        uploader.queued = mediaRequestBags
        uploader.uploadingPublishers(for: mediaRequestBags)
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
            print(item.dim ?? "?")
            print(item.sha256 ?? "?")
        }
    }
    
    func testPayloadHash() throws {
        guard let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png") else { return }
    
        let imageData = try! Data(contentsOf: filepath)
      
        let sha256hex = imageData.sha256().hexEncodedString() // "2211458b50e7354b40e7261ebc7ad735fdb26bbb14d8f53c3465e58c7b035830"
        
        // upload-test.png should hash to this:
        XCTAssertEqual(sha256hex, "2211458b50e7354b40e7261ebc7ad735fdb26bbb14d8f53c3465e58c7b035830")
    }
}
