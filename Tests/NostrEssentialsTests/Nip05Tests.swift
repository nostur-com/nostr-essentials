//
//  Dip01Tests.swift
//  
//
//  Created by Fabian Lachman on 26/11/2023.
//

import XCTest
@testable import NostrEssentials

final class Nip05Tests: XCTestCase {
    
      func testParseValidNip05Address() throws {
          let parts = try parseNip05Address("fabian@nostur.com")
          
          XCTAssertEqual(parts.name, "fabian")
          XCTAssertEqual(parts.domain, "nostur.com")
          XCTAssertNotNil(parts.nip05url)
          XCTAssertEqual(parts.nip05url?.absoluteString, "https://nostur.com/.well-known/nostr.json?name=fabian")
          
         
      }
    
      func testParseValidRootNip05Address() throws {
          let parts = try parseNip05Address("@nostur.com")
          
          XCTAssertEqual(parts.name, "_")
          XCTAssertEqual(parts.domain, "nostur.com")
          XCTAssertNotNil(parts.nip05url)
          XCTAssertEqual(parts.nip05url?.absoluteString, "https://nostur.com/.well-known/nostr.json?name=_")
      }
    
    func testNip05Lookup() async throws {
        let pubkey = try await lookupNip05("fabian@nostur.com")
        
        XCTAssertEqual(pubkey, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
    }
    
}
