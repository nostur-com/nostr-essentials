//
//  NIP-59GiftWrapTests.swift
//
//
//  Created by Fabian Lachman on 27/11/2025.
//

import XCTest
@testable import NostrEssentials

final class NIP_59GiftWrapTests: XCTestCase {
    
    var aliceKeys = try! Keys(privateKeyHex: "5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a") // pubkey: 87d3561f19b74adbe8bf840682992466068830a9d8c36b4a0c99d36f826cb6cb
    
    var bobKeys = try! Keys(privateKeyHex: "4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d") // pubkey: fa3b4f81a620c66514bda0302847df167ed02a483141b5939e57bdd0cf76ad3b
    
    func testCreateRumor() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Hello World", kind: 1, created_at: 1676784320
        )
        XCTAssertEqual(unsignedEvent.isRumor(), false) // missing ID so is not rumor
        
        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(try signedEvent.verified(), true) // event is signed
        XCTAssertEqual(signedEvent.isRumor(), false) // signed event can't be a rumor
        
        let rumorFromUnsignedEvent = createRumor(unsignedEvent) // makes sure ID is present and sig is removed
        XCTAssertEqual(rumorFromUnsignedEvent.isRumor(), true) // has ID and no sig
        
        let rumorFromSignedEvent = createRumor(signedEvent) // makes sure ID is present and sig is removed
        XCTAssertEqual(rumorFromSignedEvent.isRumor(), true) // has ID and no sig
    }

    func testCreateSeal() throws {
        let keys = aliceKeys
        
        // First create a rumor
        var unsignedEvent = Event(
            pubkey: aliceKeys.publicKeyHex,
            content: "Hello World", kind: 1, created_at: 1676784320
        )

        let rumor = createRumor(unsignedEvent) // makes sure ID is present and sig is removed
        XCTAssertEqual(rumor.isRumor(), true) // has ID and no sig
        
        
        // Create the seal (use bob as receiver)
        let seal = createSignedSeal(rumor, ourKeys: aliceKeys, receiverPubkey: bobKeys.publicKeyHex)
        
        XCTAssertNotNil(seal)
        
        if let seal {
            XCTAssertEqual(seal.tags.count, 0) // Make sure seal has no tags
            XCTAssertFalse(seal.content.contains("created_at")) // Make sure content is encrypted
            XCTAssertEqual(seal.kind, 13) // Should be kind 13
            XCTAssertTrue(try seal.verified())
        }
    }
    
}
