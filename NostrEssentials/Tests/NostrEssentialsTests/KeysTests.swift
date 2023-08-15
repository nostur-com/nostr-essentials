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
        
        XCTAssertEqual(keys.privateKeyHex().count, 64)
        XCTAssertEqual(keys.publicKeyHex().count, 64)
    }
    
    func testKeyImport() throws {
        let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

        XCTAssertEqual(keys.publicKeyHex(), "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448")
    }

}
