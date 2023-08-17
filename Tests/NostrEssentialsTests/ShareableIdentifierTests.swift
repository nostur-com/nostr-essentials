//
//  ShareableIdentifierTests.swift
//  
//
//  Created by Fabian Lachman on 17/08/2023.
//

import XCTest
@testable import NostrEssentials

final class ShareableIdentifierTests: XCTestCase {

    func testDecodeNprofile() throws {
        let nprofile = try ShareableIdentifier("nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p")
        
        XCTAssertEqual(nprofile.pubkey, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
        XCTAssertEqual(nprofile.relays, ["wss://r.x.com","wss://djbas.sadkb.com"])
    }
    
    func testDecodeNevent() throws {
        let nevent = try ShareableIdentifier("nevent1qqs9ug9weddnm5c5nyqcmrc48hecah0z8faajhfakp7ajawhw26ya3czyzd7p0swvnfc52dfemy6tj80tkrnc2l62d32fd2cmf0ldx7rewupuqcyqqqqqqgpzdmhxue69uhhyetvv9ukzcnvv5hx7un8qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hszrthwden5te0dehhxtnvdakqz9mhwden5te0ve5kcar9wghxummnw3ezuamfdejsjauntt")
        
        XCTAssertEqual(nevent.id, "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7")
        
        XCTAssertEqual(nevent.pubkey, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
        
        XCTAssertEqual(nevent.relays, ["wss://relayable.org", "wss://relay.damus.io", "wss://nos.lol", "wss://filter.nostr.wine"])
        
        XCTAssertEqual(nevent.kind, 1)
    }
    
    func testDecodeNaddr() throws {
        let naddr = try ShareableIdentifier("naddr1qq8xummnw36hyttdd9ehx6t0dcpzpxlqhc8xf5u29x5uajd9erh4mpeu90a9xc4yk4vd5hlkn0puhwq7qvzqqqr4guqs6amnwvaz7tmwdaejumr0dsmq008z")
        
        XCTAssertEqual(naddr.pubkey, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
        
        XCTAssertEqual(naddr.dTag, "nostur-mission")
        XCTAssertEqual(naddr.kind, 30023)
        XCTAssertEqual(naddr.relays, ["wss://nos.lol"])
        XCTAssertEqual(naddr.aTag, "30023:9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e:nostur-mission")
    }
    
    func testDecodeNrelay() throws {
        let nrelay = try ShareableIdentifier("nrelay1qqxhwumn8ghj7u3w0qhxxmmdqyxhwumn8ghj7u3w0yhxxmmdqyxhwumn8ghj7mn0wvhxcmmvu3kclg")
        
        XCTAssertEqual(nrelay.relayUrl, "wss://r.x.com")
        XCTAssertEqual(nrelay.relays, ["wss://r.y.com", "wss://nos.lol"])
    }
    
    func testDecodeNpub() throws {
        let npub = try ShareableIdentifier("npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe")
        
        XCTAssertEqual(npub.pubkey, "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
    }
    
    func testDecodeNote() throws {
        let note = try ShareableIdentifier("note1tcs2aj6m8hf3fxgp3k83200n3mw7ywnmm9wnmvram96awu45fmrshq2hcy")
        
        XCTAssertEqual(note.id, "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7")
    }
    
    func testDecodeNsec() throws {
        let nsec = try ShareableIdentifier("nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc")
        
        XCTAssertEqual(nsec.privkey, "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
    }
    
    func testEncodeNevent() throws {
        let nevent = try ShareableIdentifier(
            "nevent",
            id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"
        )
        
        XCTAssertEqual(nevent.identifier, "nevent1qqs9ug9weddnm5c5nyqcmrc48hecah0z8faajhfakp7ajawhw26ya3c7mwrlm")
    }
    
    func testEncodeNeventWithOptionals() throws {
        let nevent = try ShareableIdentifier(
            "nevent",
            id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7",
            kind: 1,
            pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e",
            relays: ["wss://relayable.org", "wss://relay.damus.io", "wss://nos.lol", "wss://filter.nostr.wine"]
        )
        
        XCTAssertEqual(nevent.identifier, "nevent1qqs9ug9weddnm5c5nyqcmrc48hecah0z8faajhfakp7ajawhw26ya3czyzd7p0swvnfc52dfemy6tj80tkrnc2l62d32fd2cmf0ldx7rewupuqcyqqqqqqgpzdmhxue69uhhyetvv9ukzcnvv5hx7un8qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hszrthwden5te0dehhxtnvdakqz9mhwden5te0ve5kcar9wghxummnw3ezuamfdejsjauntt")
    }
    
    func testEncodeNaddr() throws {
        let naddr = try ShareableIdentifier(
            "naddr",
            kind: 30023,
            pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e",
            dTag: "nostur-mission"
        )
        
        XCTAssertEqual(naddr.identifier, "naddr1qq8xummnw36hyttdd9ehx6t0dcpzpxlqhc8xf5u29x5uajd9erh4mpeu90a9xc4yk4vd5hlkn0puhwq7qvzqqqr4guxh67ae")
    }
    
    func testEncodeNaddrWithOptionals() throws {
        let naddr = try ShareableIdentifier(
            "naddr",
            kind: 30023,
            pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e",
            dTag: "nostur-mission",
            relays: ["wss://nos.lol"]
        )
        
        XCTAssertEqual(naddr.identifier, "naddr1qq8xummnw36hyttdd9ehx6t0dcpzpxlqhc8xf5u29x5uajd9erh4mpeu90a9xc4yk4vd5hlkn0puhwq7qvzqqqr4guqs6amnwvaz7tmwdaejumr0dsmq008z")
    }
    
    func testEncodeNprofile() throws {
        let nprofile = try ShareableIdentifier(
            "nprofile",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
        )
        
        XCTAssertEqual(nprofile.identifier, "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8g2lcy6q")
    }
    
    func testEncodeNprofileWithOptionals() throws {
        let nprofile = try ShareableIdentifier(
            "nprofile",
            pubkey: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d",
            relays: ["wss://r.x.com","wss://djbas.sadkb.com"]
        )
        
        XCTAssertEqual(nprofile.identifier, "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p")
    }
    
    func testEncodeNrelay() throws {
        let nrelay = try ShareableIdentifier(
            "nrelay",
            relayUrl: "wss://r.x.com"
        )
        
        XCTAssertEqual(nrelay.identifier, "nrelay1qqxhwumn8ghj7u3w0qhxxmmdzq8v9f")
    }
    
    func testEncodeNrelayWithOptionals() throws {
        let nrelay = try ShareableIdentifier(
            "nrelay",
            relayUrl: "wss://r.x.com",
            relays: ["wss://r.y.com", "wss://nos.lol"]
        )
        
        XCTAssertEqual(nrelay.identifier, "nrelay1qqxhwumn8ghj7u3w0qhxxmmdqyxhwumn8ghj7u3w0yhxxmmdqyxhwumn8ghj7mn0wvhxcmmvu3kclg")
    }

    func testEncodeNpub() throws {
        let npub = try ShareableIdentifier(
            "npub",
            pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448"
        )
        
        XCTAssertEqual(npub.identifier, "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7")
    }
    
    func testEncodeNsec() throws {
        let nsec = try ShareableIdentifier(
            "nsec",
            pubkey: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e"
        )
        
        XCTAssertEqual(nsec.identifier, "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc")
    }
    
    func testEncodeNote() throws {
        let note = try ShareableIdentifier(
            "note",
            id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"
        )
        
        XCTAssertEqual(note.identifier, "note1tcs2aj6m8hf3fxgp3k83200n3mw7ywnmm9wnmvram96awu45fmrshq2hcy")
    }
}
