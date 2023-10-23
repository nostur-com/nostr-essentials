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
                Tag(["payload", "c8c32742c215a86b96e122810883a8e7a01ed0a05f24debc300997740c7416da"]), // hash of media file
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
