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


    func testMatchBolt11() throws {
        let r = NostrRegexes.default
        
        let exampleTags = ###"[["p","eab0e756d32b80bcd464f3d844b8040303075a13eabc3599a762c9ac7ab91f4f"],["e","393121b1031c409a3b0efa45b6aae82adba32510468a5f129f022995d07c3795"],["P","6ad3e2a34818b153c81f48c58f44e5199e7b4fc8dbe37810a000dce3c90b7740"],["bolt11","lnbc1u1pnza24ppp5jq83dwwwuy3dn6x37f3547gq6d2cvq9943g5p3cqgzmjhfq5mvxshp5z0uhtng8jlwhwuggwghvtv7jgut5xpnlfhu8uxqvqzmx4us3x6vscqzzsxqyz5vqsp5stc3l4dxzljetl8vkpk8cs5ak9ryr2ttjg06mnxnfentkwrwj7eq9qyyssqaemrtrs90dzyv9vksu5jmffqwrw6qcxvq0gvvyytq0p7yddr3vksypg0ehs73tlewfn94h3jqe45qxrpmeqk9qpwwxvu4l3qg6r9pcspmp7xr9"],["preimage","5d899e1b1f5aeda8b052499ded89c66301f3398823670d7017360365a7517fee"],["description","{\"id\":\"eb541dc9a94b9ad1f9333fe8ea10945b69a0a390341de40ae92c6206422cc038\",\"sig\":\"fdc32c1c801c748e73f3101e07ed83c139396d78123d518f189e637e80dad5e07d80a7ce578dedc365066f78c21f215c3dce8f4bd23ce88cf0d477df457cea44\",\"created_at\":1714334369,\"tags\":[[\"p\",\"eab0e756d32b80bcd464f3d844b8040303075a13eabc3599a762c9ac7ab91f4f\"],[\"e\",\"393121b1031c409a3b0efa45b6aae82adba32510468a5f129f022995d07c3795\"],[\"relays\",\"wss://relay.nostr.band\",\"wss://theforest.nostr1.com\",\"wss://wss://support.nostr1.com\",\"wss://relayable.org\",\"wss://nostr.mutinywallet.com\",\"ws://umbrel.local:4848\",\"wss://nostr.wine\",\"wss://purplepag.es\",\"ws://umheps4fzpckynshufbtbo3qox26fsv4u4bfqibgrvj7gpzjnt77giqd.onion\",\"wss://nos.lol\"]],\"pubkey\":\"6ad3e2a34818b153c81f48c58f44e5199e7b4fc8dbe37810a000dce3c90b7740\",\"content\":\"\",\"kind\":9734}"]]"###
        
        if let match = r.cache[.bolt11]!.firstMatch(in: exampleTags, range: NSRange(exampleTags.startIndex..., in: exampleTags)) {
            
            if let range = Range(match.range(at: 1), in: exampleTags) {
                XCTAssertEqual(String(exampleTags[range]), ###"lnbc1u1pnza24ppp5jq83dwwwuy3dn6x37f3547gq6d2cvq9943g5p3cqgzmjhfq5mvxshp5z0uhtng8jlwhwuggwghvtv7jgut5xpnlfhu8uxqvqzmx4us3x6vscqzzsxqyz5vqsp5stc3l4dxzljetl8vkpk8cs5ak9ryr2ttjg06mnxnfentkwrwj7eq9qyyssqaemrtrs90dzyv9vksu5jmffqwrw6qcxvq0gvvyytq0p7yddr3vksypg0ehs73tlewfn94h3jqe45qxrpmeqk9qpwwxvu4l3qg6r9pcspmp7xr9"###)
            }
        }
    }
    
}
