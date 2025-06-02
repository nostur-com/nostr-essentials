//
//  BlossomTests.swift
//
//
//  Created by Fabian Lachman on 05/05/2025.
//

import XCTest
@testable import NostrEssentials
import Combine

final class BlossomTests: XCTestCase {
    
    private var subscriptions: Set<AnyCancellable> = []
    
    override func setUpWithError() throws {
        subscriptions = []
    }
    
    func testSignAuthorizationEvent() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Upload bitcoin.pdf",
            kind: 24242,
            tags: [
                Tag(["t", "upload"]),
                Tag(["expiration", "1808858680"]),
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        
        XCTAssertEqual(signedEvent.kind, 24242)
        XCTAssertEqual(signedEvent.tags[0].type, "t")
        XCTAssertEqual(signedEvent.tags[0].value, "upload")
        XCTAssertEqual(signedEvent.content, "Upload bitcoin.pdf")
        

        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
    }
    
    func testSignUploadAuthorizationEvent() throws {
         
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Upload bitcoin.pdf",
            kind: 24242,
            tags: [
                Tag(["t", "upload"]),
                Tag(["x", "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553"]),
                Tag(["expiration", "1808858680"]),
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        
        XCTAssertEqual(signedEvent.kind, 24242)
        XCTAssertEqual(signedEvent.tags[0].type, "t")
        XCTAssertEqual(signedEvent.tags[0].value, "upload")
        
        XCTAssertEqual(signedEvent.tags[1].type, "x")
        XCTAssertEqual(signedEvent.tags[1].value, "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553")
        
        XCTAssertEqual(signedEvent.tags[2].type, "expiration")
        XCTAssertEqual(signedEvent.tags[2].value, "1808858680")
        
        XCTAssertEqual(signedEvent.content, "Upload bitcoin.pdf")
        

        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
    }
    
    func testSignMediaAuthorizationEvent() throws {
         
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Upload and expect processing",
            kind: 24242,
            tags: [
                Tag(["t", "upload"]),
                Tag(["x", "08718084031ef9b9ec91e1aee5b6116db025fba6946534911d720f714a98b961"]), // happy4u.jpg
                Tag(["expiration", "1808858680"]),
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        
        XCTAssertEqual(signedEvent.kind, 24242)
        XCTAssertEqual(signedEvent.tags[0].type, "t")
        XCTAssertEqual(signedEvent.tags[0].value, "upload")
        
        XCTAssertEqual(signedEvent.tags[1].type, "x")
        XCTAssertEqual(signedEvent.tags[1].value, "08718084031ef9b9ec91e1aee5b6116db025fba6946534911d720f714a98b961")
        
        XCTAssertEqual(signedEvent.tags[2].type, "expiration")
        XCTAssertEqual(signedEvent.tags[2].value, "1808858680")
        
        XCTAssertEqual(signedEvent.content, "Upload and expect processing")
        

        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
    }
    
    func testBlossomMediaUpload() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        // pubkey: 1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448
        // npub: npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7
        
        let filepath = Bundle.module.url(forResource: "beerstr", withExtension: "png")
        let imageData = try Data(contentsOf: filepath!)
        let authHeader = try getBlossomAuthorizationHeader(keys, sha256hex: imageData.sha256().hexEncodedString())
        let uploadItem = BlossomUploadItem(data: imageData, contentType: "image/png", authorizationHeader: authHeader)
        let uploader = BlossomUploader(URL(string: "http://localhost:3000")!)
        uploader.queued = [uploadItem]
                
        let expectation = self.expectation(description: "testMediaUpload")
        
        uploader.uploadingPublisher(for: uploadItem)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { uploadItem in
                uploader.processResponse(uploadItem: uploadItem)
            })
            .store(in: &subscriptions)
        
        // Awaiting fulfilment of our expecation before
        // performing our asserts:
        waitForExpectations(timeout: 10)
        
        XCTAssertTrue(uploader.finished)
        print(uploader.queued.first?.downloadUrl ?? "?")
    }
    
    func testMultipleBlossomUploads() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")



        let filepath1 = Bundle.module.url(forResource: "upload-test", withExtension: "png")
        let imageData1 = try Data(contentsOf: filepath1!)
        let authHeader1 = try getBlossomAuthorizationHeader(keys, sha256hex: imageData1.sha256().hexEncodedString())
        let uploadItem1 = BlossomUploadItem(data: imageData1, authorizationHeader: authHeader1)
        
        let filepath2 = Bundle.module.url(forResource: "bitcoin", withExtension: "png")
        let imageData2 = try Data(contentsOf: filepath2!)
        let authHeader2 = try getBlossomAuthorizationHeader(keys, sha256hex: imageData2.sha256().hexEncodedString())
        let uploadItem2 = BlossomUploadItem(data: imageData2, authorizationHeader: authHeader2)
        
        let filepath3 = Bundle.module.url(forResource: "coffeechain", withExtension: "png")
        let imageData3 = try Data(contentsOf: filepath3!)
        let authHeader3 = try getBlossomAuthorizationHeader(keys, sha256hex: imageData3.sha256().hexEncodedString())
        let uploadItem3 = BlossomUploadItem(data: imageData3, authorizationHeader: authHeader3)
        
        let filepath4 = Bundle.module.url(forResource: "beerstr", withExtension: "png")
        let imageData4 = try Data(contentsOf: filepath4!)
        let authHeader4 = try getBlossomAuthorizationHeader(keys, sha256hex: imageData4.sha256().hexEncodedString())
        let uploadItem4 = BlossomUploadItem(data: imageData4, authorizationHeader: authHeader4)
        
        let uploader = BlossomUploader(URL(string: "http://localhost:3000")!)
        
        let expectation = self.expectation(description: "testMediaUpload")
        
        let uploadItems = [uploadItem1, uploadItem2, uploadItem3, uploadItem4]
        uploader.queued = uploadItems
        uploader.uploadingPublishers(for: uploadItems)
            .sink(receiveCompletion: { _ in
                expectation.fulfill()
            }, receiveValue: { uploadItems in
                for uploadItem in uploadItems {
                    uploader.processResponse(uploadItem: uploadItem)
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
            print(item.sha256processed ?? "?")
        }
    }
    
    func testBlossomHeadMedia() async throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        let testSuccess = try await testBlossomServer(URL(string: "http://localhost:3000")!, keys: keys)
        
        XCTAssertTrue(testSuccess)
    }
    
    func testBlossomMirror() async throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        let filepath = Bundle.module.url(forResource: "48af54ea036b2b5a6d64142286eee45e862c2091740959be5d2af0872618593e", withExtension: "jpg")
        let imageData = try Data(contentsOf: filepath!)
        let authHeader = try getBlossomAuthorizationHeader(keys, sha256hex: imageData.sha256().hexEncodedString())
        let mirrorUploader = BlossomUploader(URL(string: "https://media.utxo.nl")!)
        
        let uploadItem = BlossomUploadItem(data: imageData, index: 0, contentType: "image/jpg", authorizationHeader: authHeader)
        uploadItem.downloadUrl = "https://image.nostr.build/48af54ea036b2b5a6d64142286eee45e862c2091740959be5d2af0872618593e.jpg"
        uploadItem.sha256processed = "48af54ea036b2b5a6d64142286eee45e862c2091740959be5d2af0872618593e"
        
        guard let sha256processed = uploadItem.sha256processed else { return }
        guard let authHeader = try? getBlossomAuthorizationHeader(keys, sha256hex: sha256processed, action: .upload) else {
            return
        }
        
        let testSuccess = try await mirrorUploader.mirrorUpload(uploadItem: uploadItem, authorizationHeader: authHeader)
        
        XCTAssertTrue(testSuccess)
    }
    
    
}
