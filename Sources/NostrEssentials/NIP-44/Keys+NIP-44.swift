//
//  Keys+NIP-44.swift
//
//
//  Created by Fabian Lachman on 30/12/2024.
//

import Foundation
import secp256k1

public class Keys44: NIP44v2Encrypting {
    
}

extension Keys {
    static public func decryptDirectMessageContent44(withPrivateKey privateKey: String?, pubkey: String, content: String) -> String? {
        let eee = Keys44()
        guard let privateKey, let privPair = try? Keys(privateKeyHex: privateKey) else { return nil }
        guard let xOnlyKey = try? secp256k1.Schnorr.XonlyKey(dataRepresentation: pubkey.bytes, keyParity: 1) else { return nil }
        
        guard let sharedSecret = try? eee.conversationKey(
            privateKeyA: privPair.privateKey.dataRepresentation,
            publicKeyB: Data(xOnlyKey.bytes)
        ) else {
            return nil
        }
        // Verify payload.
        guard let decrypted = try? eee.decrypt(payload: content, conversationKey: sharedSecret.bytes) else {
            return nil
        }
        return decrypted
    }
    
    static public func encryptDirectMessageContent44(withPrivatekey privateKey: String?, pubkey: String, content: String) -> String? {
        let eee = Keys44()
        guard let privateKey, let privPair = try? Keys(privateKeyHex: privateKey) else { return nil }
        guard let xOnlyKey = try? secp256k1.Schnorr.XonlyKey(dataRepresentation: pubkey.bytes, keyParity: 1) else { return nil }
        
        guard let sharedSecret = try? eee.conversationKey(
            privateKeyA: privPair.privateKey.dataRepresentation,
            publicKeyB: Data(xOnlyKey.bytes)
        ) else {
            return nil
        }
        // Verify payload.
        guard let ciphertext = try? eee.encrypt(
            plaintext: content,
            conversationKey: sharedSecret.bytes
        ) else {
            return nil
        }
        return ciphertext
    }
}

extension Data {

    /// Random data of a given size.
    static func randomBytes(count: Int) -> Data {
        var bytes = [Int8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("can't copy secure random data")
        }
        return Data(bytes: bytes, count: count)
    }
}
