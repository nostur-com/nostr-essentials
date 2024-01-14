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
    
    
    func testParseQuotes() throws {
        let r = NostrRegexes.default
        
        // Content with 2 quoted posts, one in note1 style and another in nevent1.
        let exampleContent = ###"another test\n\na nostr:note1\n\nnostr:note1kcgpeeq5x7p2tnt4retpknt5y5usfc5u339stxqfy22at7mmtssshd6zz9\n\na nostr:nevent1\n\nnostr:nevent1qqsrhuv4pqzns9qtwzw2xhewwgj8d80f87c85tad5uvf4w6cfeahgvc8476ky\n"###
        
        // Lets scan for quoted posts and get the hex id's (to put in q tags for example)
        let qTags: [String] = r.matchingStrings(exampleContent, regex: r.cache[.nostrUri]!)
            .compactMap { match in
                guard match.count == 3 else { return nil }
                if match[2] == "note1" {
                    return Keys.hex(note1: match[1])
                }
                else if match[2] == "nevent1" {
                    return (try? ShareableIdentifier(match[1]))?.id
                }
                return nil
            }
        
        XCTAssertEqual(qTags, [
            "b6101ce4143782a5cd751e561b4d74253904e29c8c4b0598092295d5fb7b5c21",
            "3bf195080538140b709ca35f2e7224769de93fb07a2fada7189abb584e7b7433"
        ])
    }


}
