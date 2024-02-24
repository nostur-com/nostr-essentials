//
//  KeysTests.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import XCTest
@testable import NostrEssentials

final class KeysTests: XCTestCase {

    func testKeyGeneration() throws {
        let keys = try Keys.newKeys()
        
        XCTAssertEqual(keys.privateKeyHex.count, 64) // a 64 character key as hex string
        XCTAssertEqual(keys.publicKeyHex.count, 64) // a 64 character key as hex string
    }
    
    func testKeyImport() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

        XCTAssertEqual(keys.publicKeyHex, "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
    }
    
    func testKeysToNsecNpub() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

        XCTAssertEqual(keys.nsec(), "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc")
        
        XCTAssertEqual(keys.npub(), "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7")
    }
    
    func testPubkeyHexToNpub() throws {
        XCTAssertEqual(Keys.npub(hex: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448"), "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7")
    }
    
    func testPrivkeyHexToNsec() throws {
        XCTAssertEqual(Keys.nsec(hex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e"), "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc")
    }
    
    func testNpubToPubkeyHex() throws {
        XCTAssertEqual(Keys.hex(npub: "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"), "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
    }

    func testNsecToPrivkeyHex() throws {
        XCTAssertEqual(Keys.hex(nsec: "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc"), "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")
    }
    
    func testInvalidKeyShouldReturnNil() throws {
        XCTAssertNil(Keys.hex(nsec: "nsec1vq5nxhd4lalala"))
        XCTAssertNil(Keys.hex(nsec: "nplub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"))
        XCTAssertNil(Keys.hex(nsec: "pub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"))
        XCTAssertNil(Keys.hex(nsec: "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7]"))
    }

}
