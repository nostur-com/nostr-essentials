//
//  RelayConnections.swift
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

}
