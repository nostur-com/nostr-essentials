//
//  EventTests.swift
//  
//
//  Created by Fabian Lachman on 17/08/2023.
//

import XCTest
@testable import NostrEssentials

final class EventTests: XCTestCase {

    func testEventToJson() throws {
        let event = Event(pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e", content: "I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com", kind: 1, created_at: 1676784320, id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7", tags: [], sig: "207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a")
        
        // final order is not determenistic but output should be something like:
        // {"pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","content":"I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com","id":"5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7","created_at":1676784320,"sig":"207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a","kind":1,"tags":[]}
        
        XCTAssertTrue(event.json()!.contains(###""pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e""###))
        XCTAssertTrue(event.json()!.contains(###""content":"I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com""###))
        XCTAssertTrue(event.json()!.contains(###""id":"5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7""###))
        XCTAssertTrue(event.json()!.contains(###""created_at":1676784320"###))
        XCTAssertTrue(event.json()!.contains(###""sig":"207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a""###))
        XCTAssertTrue(event.json()!.contains(###""kind":1"###))
        XCTAssertTrue(event.json()!.contains(###""tags":[]"###))
    }

    func testSignEvent() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Hello World", kind: 1, created_at: 1676784320
        )

        let signedEvent = try unsignedEvent.sign(keys)
        XCTAssertEqual(signedEvent.pubkey, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
        XCTAssertEqual(signedEvent.id, "f3eb5bc07a397bc275dd2ea3e5774a5cc308ec94856d04894d1328d414942dcc")
        XCTAssertEqual(signedEvent.created_at, 1676784320)
        XCTAssertEqual(signedEvent.kind, 1)
        XCTAssertEqual(try signedEvent.verified(), true)
        
    }
    
    func testComputeId() throws {
        var unsignedEvent = Event(
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
            content: "Hello World", kind: 1, created_at: 1676784320
        )

        let unsignedEventWithId = unsignedEvent.withId()
        XCTAssertEqual(unsignedEventWithId.id,"f3eb5bc07a397bc275dd2ea3e5774a5cc308ec94856d04894d1328d414942dcc")
    }

}
