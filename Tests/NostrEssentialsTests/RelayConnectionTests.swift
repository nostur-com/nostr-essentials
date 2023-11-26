//
//  RelayConnectionTests.swift
//  
//
//  Created by Fabian Lachman on 23/11/2023.
//

import XCTest
@testable import NostrEssentials

final class RelayConnectionTests: XCTestCase {
    
    func testDefineRelayConfig() {
        // Define a relay (to be added to a ConnectionPool instance)
        let myRelayConfig = RelayConfig(url: "wss://nos.lol/", read: true, write: true)
        
        XCTAssertEqual(myRelayConfig.url, "wss://nos.lol") // note that the trailing slash is removed on the root domain
        XCTAssertEqual(myRelayConfig.read, true)
        XCTAssertEqual(myRelayConfig.write, true)
    }

    func testConnection() throws {
        // This test configures a ConnectionPool instance
        // It sets it up with an example delegate MyTestApp which handles the relay responses, in this case to pass the tests
        
        let expectation = self.expectation(description: "testRelayConnection")
        
        // Implement RelayConnectionDelegate somewhere in your app to handle responses from relays
        // This is an example app that just logs to console and changes some test vars on connect/receive:
        class MyTestApp: RelayConnectionDelegate {
            
            // These are test case related:
            
            private var expectation: XCTestExpectation
            public var testDidConnect = false
            public var testDidReceiveMessage = false {
                didSet {
                    if oldValue != testDidReceiveMessage {
                        expectation.fulfill()
                    }
                }
            }
            
            init(_ expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            
            // These are the delegate methods you need to implement in your app:
            
            func didConnect(_ url: String) {
                print("connected to: \(url)")
                self.testDidConnect = true
            }
            
            func didDisconnect(_ url: String) {
                print("disconnected from: \(url)")
            }
            
            func didReceiveMessage(_ url: String, message: String) {
                print("message received from \(url): \(message)")
                self.testDidReceiveMessage = true
            }
            
            func didDisconnectWithError(_ url: String, error: Error) {
                print("disconnected from: \(url), with error: \(error.localizedDescription)")
            }
        }
        
        // Instantiate example app
        let myApp = MyTestApp(expectation)
        
        // Define a relay
        let myFirstRelay = RelayConfig(url: "wss://nos.lol", read: true, write: true)
        
        // Set up the connection pool
        let pool = ConnectionPool(delegate: myApp)
        
        // Add the relay to the connection pool
        let myRelayConnection = pool.addConnection(myFirstRelay)
        
        // Connect to the relay
        myRelayConnection.connect()
        
        // create a nostr request
        let lastMessageFromPubkey = ClientMessage(type: .REQ, filters: [Filters(authors: Set(["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"]), limit: 1)])
        
        // send request to the pool (which sends it to all "read" relays)
        pool.sendMessage(lastMessageFromPubkey) // .connect() might not be completed here yet, but message will be queued and sent after connect.
        
        waitForExpectations(timeout: 10)
        XCTAssertEqual(myApp.testDidConnect, true)
        XCTAssertEqual(myApp.testDidReceiveMessage, true)
    }
    
    
    func testParseRelayEventResponse() throws {
        // Example response as returned in RelayConnectionDelegate.didReceiveMessage(_ url: String, message: String) { }
        let message = ###"["EVENT","049F01AF-CA70-4C10-972B-FDF066465DD0",{"pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","content":"Just ignore labels outside WoT and increase significance of labels from direct follows.","id":"c948ad1d37abfafd887d74194f5649cce3c94711aa5eeed7e8a4ee5e4fd1dbe1","created_at":1700163275,"sig":"ed93a1dcba18e47bb9b0ed2fa98316db6cde787f51aa13ba8f08fd2f8c0775749122042bc3c6242c203e1840b1948f3b590d56fe3668cf2807ef556bdf29285e","kind":1,"tags":[["e","9e0f6c6e2a257a4b1a888dbadc150fa219ca269447f0da0d14081493f2005dc2","","root"],["e","31a21327b74818221f1b79d09e0e4552eeeb954be4e818cb9e0283524cf92f30","","reply"],["p","8a981f1ae3fab3300b548c4f20654cb0f1d350498c4b66849b73e8546001dca0"],["p","9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"],["client","Nostur"]]}]"###
        let url = "wss://nos.lol" // relay url
        
        let parsedEvent = try parseRelayMessage(text: message, relay: url)
        
        // Reading values
        XCTAssertEqual(parsedEvent.subscriptionId, "049F01AF-CA70-4C10-972B-FDF066465DD0")
        XCTAssertEqual(parsedEvent.event?.id, "c948ad1d37abfafd887d74194f5649cce3c94711aa5eeed7e8a4ee5e4fd1dbe1")
        XCTAssertEqual(parsedEvent.event?.content, "Just ignore labels outside WoT and increase significance of labels from direct follows.")
        XCTAssertEqual(parsedEvent.event?.pubkey, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
        XCTAssertEqual(parsedEvent.event?.sig, "ed93a1dcba18e47bb9b0ed2fa98316db6cde787f51aa13ba8f08fd2f8c0775749122042bc3c6242c203e1840b1948f3b590d56fe3668cf2807ef556bdf29285e")
        XCTAssertEqual(parsedEvent.event?.tags.count, 5)
        XCTAssertEqual(parsedEvent.event?.tags.first?.type, "e")
        XCTAssertEqual(parsedEvent.event?.tags.first?.value, "9e0f6c6e2a257a4b1a888dbadc150fa219ca269447f0da0d14081493f2005dc2")
        XCTAssertEqual(parsedEvent.event?.tags.last?.type, "client")
        XCTAssertEqual(parsedEvent.event?.tags.last?.value, "Nostur")
    }

}
