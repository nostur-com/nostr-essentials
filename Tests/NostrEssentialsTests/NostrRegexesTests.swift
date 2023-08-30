//
//  NostrRegexesTests.swift
//  
//
//  Created by Fabian Lachman on 30/08/2023.
//

import XCTest
@testable import NostrEssentials

final class NostrRegexesTests: XCTestCase {

    func testSimpleMatch() throws {
        let r = NostrRegexes.default
        
        let exampleContent = "Hello npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe! Is this your hex pubkey? 9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e?"
        
        r.matchingStrings(exampleContent, regex: r.cache[.npub]!)
            .forEach { match in
                XCTAssertEqual(match.first, "npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe")
            }
        
        r.matchingStrings(exampleContent, regex: r.cache[.hexId]!)
            .forEach { match in
                XCTAssertEqual(match.first, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
            }
        
    }


}
