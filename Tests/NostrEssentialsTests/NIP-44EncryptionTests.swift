//
//  NIP-44EncryptionTests.swift
//  
//
//  Created by Fabian Lachman on 30/12/2024.
//

import XCTest
@testable import NostrEssentials

final class NIP_44EncryptionTests: XCTestCase {
    
    var aliceKeys = try! Keys(privateKeyHex: "5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a")
    
    var bobKeys = try! Keys(privateKeyHex: "4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d")

    func testEncryptDecryptMessage() throws {
        let clearMessage = "hello"
        
        let encryptedMessage = Keys.encryptDirectMessageContent44(withPrivatekey: aliceKeys.privateKeyHex, pubkey: bobKeys.publicKeyHex, content: clearMessage)!
        
        let decryptedMessage = Keys.decryptDirectMessageContent44(withPrivateKey: bobKeys.privateKeyHex, pubkey: aliceKeys.publicKeyHex, content: encryptedMessage)
        
        XCTAssertEqual(clearMessage, decryptedMessage)
    }

}
