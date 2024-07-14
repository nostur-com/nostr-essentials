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
        let keys = try Keys(privateKeyHex: "150cd0ca65047d9b8d781cc380c50f3962bc043b7fec409deda9cc8c622e5cf1")
        
        var unsignedEvent = Event(
            pubkey: "312b2cce0c84018eb0eedafc3f3fc4a0bf9177bd3e3ad740767d615b57ea56f8",
            content: "",
            kind: 27235,
            tags: [
                Tag(["u", "http://localhost:8080/wp-json/nostrmedia/v1/upload/"]),
                Tag(["method", "POST"]),
                Tag(["payload", "35c461dee98aad4739707c6cca5d251a1617bfd928e154995ca6f4ce8156cffc"]), // hash of media file
            ]
        )
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "312b2cce0c84018eb0eedafc3f3fc4a0bf9177bd3e3ad740767d615b57ea56f8")
        XCTAssertEqual(signedEvent.kind, 27235)
        XCTAssertEqual(signedEvent.tags[0].type, "u")
        XCTAssertEqual(signedEvent.tags[0].value, "http://localhost:8080/wp-json/nostrmedia/v1/upload/")
        XCTAssertEqual(signedEvent.tags[1].type, "method")
        XCTAssertEqual(signedEvent.tags[1].value, "POST")
        XCTAssertEqual(signedEvent.tags[2].type, "payload")
        XCTAssertEqual(signedEvent.tags[2].value, "35c461dee98aad4739707c6cca5d251a1617bfd928e154995ca6f4ce8156cffc")
        XCTAssertEqual(try signedEvent.verified(), true)
        print(NSString(string:signedEvent.json()!))
        print(NSString(string:signedEvent.base64()!))
        
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
        
        XCTAssertTrue(unsignedEvent.base64()!.starts(with: "ey"))
        XCTAssertTrue(unsignedEvent.base64()!.suffix(1) == "=")
        
        print(NSString(string:unsignedEvent.json()!))
        print(NSString(string:unsignedEvent.base64()!))
        
    }
    
}
