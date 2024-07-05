//
//  Nip46Tests.swift
//  
//
//  Created by Fabian Lachman on 05/07/2024.
//

import XCTest
@testable import NostrEssentials

final class Nip46Tests: XCTestCase {

    func testParseBunkerURLs() throws {
        let input = "bunker://b55ca1f1aa95d5dc45877b8331a9598c53e38ef4a7bc436d765b11d660fc39c9?relay=wss://relay.nsec.app&secret=c57119f73dcad9d2fc08f807215132d1"
        
        let bunkerURL = parseBunkerUrl(input)
        
        XCTAssertNotNil(bunkerURL)
        
        guard let bunkerURL else { return }

        XCTAssertEqual(bunkerURL.pubkey, "b55ca1f1aa95d5dc45877b8331a9598c53e38ef4a7bc436d765b11d660fc39c9")
        XCTAssertEqual(bunkerURL.secret, "c57119f73dcad9d2fc08f807215132d1")
        XCTAssertEqual(bunkerURL.relay, "wss://relay.nsec.app")
        
        // multiple relays
        let input2 = "bunker://b55ca1f1aa95d5dc45877b8331a9598c53e38ef4a7bc436d765b11d660fc39c9?relay=wss://nos.lol&relay=wss://relay.nsec.app&secret=c57119f73dcad9d2fc08f807215132d1"
        
        let bunkerURL2 = parseBunkerUrl(input2)
        
        XCTAssertNotNil(bunkerURL2)
        
        guard let bunkerURL2 else { return }

        XCTAssertEqual(bunkerURL2.pubkey, "b55ca1f1aa95d5dc45877b8331a9598c53e38ef4a7bc436d765b11d660fc39c9")
        XCTAssertEqual(bunkerURL2.secret, "c57119f73dcad9d2fc08f807215132d1")
        XCTAssertEqual(bunkerURL2.relay, "wss://nos.lol") // first relay
    }

}
