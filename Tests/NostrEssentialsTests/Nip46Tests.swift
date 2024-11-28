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
        
        // test percent encoded relays
        let input3 = "bunker://3740972e9a2807c38d131340b7bcbe1d1a093642a3d1285f0894ce8d51d4051f?relay=wss%3A%2F%2Fnos.lol&secret=KyZKDJqyROCR"
        
        let bunkerURL3 = parseBunkerUrl(input3)
        
        XCTAssertNotNil(bunkerURL3)
        
        guard let bunkerURL3 else { return }

        XCTAssertEqual(bunkerURL3.pubkey, "3740972e9a2807c38d131340b7bcbe1d1a093642a3d1285f0894ce8d51d4051f")
        XCTAssertEqual(bunkerURL3.secret, "KyZKDJqyROCR")
        XCTAssertEqual(bunkerURL3.relay, "wss://nos.lol") // first relay
        
        // test percent encoded relays and optional secret (no secret)
        let input4 = "bunker://a1198de2b9a4c3fbce77b011c0da31135d840f6c642ef843a7039fec03d48144?relay=wss%3A%2F%2Fpromenade.fiatjaf.com"
        
        let bunkerURL4 = parseBunkerUrl(input4)
        
        XCTAssertNotNil(bunkerURL4)
        
        guard let bunkerURL4 else { return }

        XCTAssertEqual(bunkerURL4.pubkey, "a1198de2b9a4c3fbce77b011c0da31135d840f6c642ef843a7039fec03d48144")
        XCTAssertNil(bunkerURL4.secret)
        XCTAssertEqual(bunkerURL4.relay, "wss://promenade.fiatjaf.com") // first relay
    }

}
