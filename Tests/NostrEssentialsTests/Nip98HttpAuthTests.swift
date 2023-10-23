//
//  Nip98HttpAuthTests.swift
//
//
//  Created by Fabian Lachman on 20/10/2023.
//

import XCTest
@testable import NostrEssentials
import Combine

final class Nip98HttpAuthTests: XCTestCase {
    
    func testSignGetHttpAuthEvent() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", "https://nostrcheck.me/api/v2/media"]),
                Tag(["method", "GET"]),
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        XCTAssertEqual(signedEvent.kind, 27235)
        XCTAssertEqual(signedEvent.tags[0].type, "u")
        XCTAssertEqual(signedEvent.tags[0].value, "https://nostrcheck.me/api/v2/media")
        XCTAssertEqual(signedEvent.tags[1].type, "method")
        XCTAssertEqual(signedEvent.tags[1].value, "GET")
        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
    }
    
    func testSignPostHttpAuthEvent() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
        
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", "https://nostrcheck.me/api/v2/media"]),
                Tag(["method", "POST"]),
                Tag(["payload", "c8c32742c215a86b96e122810883a8e7a01ed0a05f24debc300997740c7416da"]), // hash request.httpBody with upload-test.png as payload
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        XCTAssertEqual(signedEvent.kind, 27235)
        XCTAssertEqual(signedEvent.tags[0].type, "u")
        XCTAssertEqual(signedEvent.tags[0].value, "https://nostrcheck.me/api/v2/media")
        XCTAssertEqual(signedEvent.tags[1].type, "method")
        XCTAssertEqual(signedEvent.tags[1].value, "POST")
        XCTAssertEqual(signedEvent.tags[2].type, "payload")
        XCTAssertEqual(signedEvent.tags[2].value, "c8c32742c215a86b96e122810883a8e7a01ed0a05f24debc300997740c7416da")
        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
    }
    
    func testPayloadHash() throws {
        guard let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png") else { return }
        
        let url = URL(string: "https://nostrcheck.me/api/v2/media")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "test-boundry"
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let body = NSMutableData()
        
        let imageData = try! Data(contentsOf: filepath)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mediafile\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"uploadtype\"\r\n\r\n".data(using: .utf8)!)
        body.append("media".data(using: .utf8)!)
        
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body as Data
        
        let sha256hex = imageData.sha256().hexEncodedString() // "2211458b50e7354b40e7261ebc7ad735fdb26bbb14d8f53c3465e58c7b035830"
        
        // upload-test.png added to body should hash to this:
        XCTAssertEqual(sha256hex, "2211458b50e7354b40e7261ebc7ad735fdb26bbb14d8f53c3465e58c7b035830")
    }
    
    func testEncodeEventToBase64() throws {
        let unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "",
            kind: 27235,
            created_at: 1676784320,
            tags: [
                Tag(["u", "https://nostrcheck.me/api/v2/media"]),
                Tag(["method", "GET"])
            ]
        )
        
        XCTAssertEqual(unsignedEvent.base64(), "eyJwdWJrZXkiOiIxYmU4OTlkNGIzNDc5YTVhM2ZlZjVmYjU1YmYzYzJkN2Y1YWFiYmY4MWY0ZDEzYzUyM2FmYTc2MDQ2MmNkNDQ4IiwiY29udGVudCI6IiIsImlkIjoiIiwiY3JlYXRlZF9hdCI6MTY3Njc4NDMyMCwic2lnIjoiIiwia2luZCI6MjcyMzUsInRhZ3MiOltbInUiLCJodHRwczpcL1wvbm9zdHJjaGVjay5tZVwvYXBpXC92MlwvbWVkaWEiXSxbIm1ldGhvZCIsIkdFVCJdXX0=")
        print(NSString(string:unsignedEvent.json()!))
        print(NSString(string:unsignedEvent.base64()!))
        
    }
    
}
