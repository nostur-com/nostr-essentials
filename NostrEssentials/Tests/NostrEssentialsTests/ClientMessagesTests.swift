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
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(requestMessage) {
            XCTAssertEqual(
                """
["REQ","test",{"kinds":[1],"limit":10}]
""", String(data: encoded, encoding: .utf8)!)
        }
    }
    
    func testREQmessageMultipleFilters() throws {
//        ["REQ", <subscription_id>, <filters JSON>...], used to request events and subscribe to new updates.
        
        let filter1 = Filters(kinds:[7], limit: 100)
        let filter2 = Filters(kinds:[9735], limit: 200)
        
        let requestMessage = ClientMessage(type:.REQ, subscriptionId:"multitest", filters: [filter1,filter2])
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(requestMessage) {
            XCTAssertEqual(
                """
["REQ","multitest",{"kinds":[7],"limit":100},{"kinds":[9735],"limit":200}]
""", String(data: encoded, encoding: .utf8)!)
        }
    }

    func testCLOSEmessage() throws {
//  ["CLOSE", <subscription_id>], used to stop previous subscriptions.
        
        let closeMessage = ClientMessage(type:.CLOSE, subscriptionId:"subscription1")
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(closeMessage) {
            XCTAssertEqual(
                """
["CLOSE","subscription1"]
""", String(data: encoded, encoding: .utf8)!)
        }
    }
    
    func testEVENTmessage() throws {
//  ["EVENT", <event JSON>], used to publish events.
        
        let event = Event(pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e", content: "I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com", kind: 1, created_at: 1676784320, id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7", tags: [], sig: "207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a")
        
        let eventMessage = ClientMessage(type:.EVENT, event:event)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(eventMessage) {
            XCTAssertEqual(
                """
["EVENT",{"pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","content":"I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com","id":"5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7","created_at":1676784320,"sig":"207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a","kind":1,"tags":[]}]
""", String(data: encoded, encoding: .utf8)!)
        }
    }
}
