//
//  ClientMessagesTests.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import XCTest
@testable import NostrEssentials

final class ClientMessagesTests: XCTestCase {

    func testREQmessageSingleFilter() throws {
//        ["REQ", <subscription_id>, <filters JSON>...], used to request events and subscribe to new updates.
        
        let filter = Filters(kinds:[1], limit: 10)
        
        let requestMessage = ClientMessage(type:.REQ, subscriptionId:"test", filters: [filter])
        
        // final order is not determenistic but output should be something like:
        //  ["REQ","test",{"kinds":[1],"limit":10}]
        
        XCTAssertTrue(requestMessage.json()!.contains(###"["REQ","test","###))
        XCTAssertTrue(requestMessage.json()!.contains(###""kinds":[1]"###))
        XCTAssertTrue(requestMessage.json()!.contains(###""limit":10"###))
    }
    
    func testREQmessageMultipleFilters() throws {
//        ["REQ", <subscription_id>, <filters JSON>...], used to request events and subscribe to new updates.
        
        let filter1 = Filters(kinds:[7], limit: 100)
        let filter2 = Filters(kinds:[9735], limit: 200)
        
        let requestMessage = ClientMessage(type:.REQ, subscriptionId:"multitest", filters: [filter1,filter2])
        
        // final order is not determenistic but output should be something like:
        // ["REQ","multitest",{"kinds":[7],"limit":100},{"kinds":[9735],"limit":200}]
        
        XCTAssertTrue(requestMessage.json()!.contains(###"["REQ","multitest","###))
        XCTAssertTrue(requestMessage.json()!.contains(###""kinds":[7]"###))
        XCTAssertTrue(requestMessage.json()!.contains(###""limit":100"###))
        XCTAssertTrue(requestMessage.json()!.contains(###""kinds":[9735]"###))
        XCTAssertTrue(requestMessage.json()!.contains(###""limit":200"###))
    }
    
    func testPFilter() throws {
        
        let pFilter = Filters(tagFilter: TagFilter(tag: "p", values: ["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]))
        let requestMessage = ClientMessage(type: .REQ, subscriptionId: "example2", filters: [pFilter])

        XCTAssertEqual(requestMessage.json(),
                        """
                        ["REQ","example2",{"#p":["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]}]
                        """
        )
    }

    func testCLOSEmessage() throws {
//  ["CLOSE", <subscription_id>], used to stop previous subscriptions.
        
        let closeMessage = ClientMessage(type:.CLOSE, subscriptionId:"subscription1")

            XCTAssertEqual(
                """
                ["CLOSE","subscription1"]
                """,
                closeMessage.json()
            )

    }
    
    func testEVENTmessage() throws {
//  ["EVENT", <event JSON>], used to publish events.
        
        let event = Event(pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e", content: "I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com", kind: 1, created_at: 1676784320, id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7", tags: [], sig: "207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a")
        
        let eventMessage = ClientMessage(type:.EVENT, event:event)
        
        // final order is not determenistic but output should be something like:
        // ["EVENT",{"pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","content":"I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com","id":"5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7","created_at":1676784320,"sig":"207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a","kind":1,"tags":[]}]
        
        XCTAssertTrue(eventMessage.json()!.contains(###"["EVENT",{""###))
        XCTAssertTrue(eventMessage.json()!.contains(###""pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e""###))
        XCTAssertTrue(eventMessage.json()!.contains(###""content":"I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com""###))
        XCTAssertTrue(eventMessage.json()!.contains(###""id":"5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7""###))
        XCTAssertTrue(eventMessage.json()!.contains(###""created_at":167678432"###))
        XCTAssertTrue(eventMessage.json()!.contains(###""sig":"207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a""###))
        XCTAssertTrue(eventMessage.json()!.contains(###""kind":1"###))
        XCTAssertTrue(eventMessage.json()!.contains(###""tags":[]"###))
    }
}
