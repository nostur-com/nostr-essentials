//
//  Keys.swift
//
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation
import secp256k1
import CommonCrypto

struct Keys {

    public let privateKey:secp256k1.Signing.PrivateKey
    public let publicKey:secp256k1.Signing.PublicKey

    init(privateKey:secp256k1.Signing.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
    }

    init(privateKeyHex:String) throws {
        do {
            let privateKeyBytes = try privateKeyHex.bytes
            privateKey = try secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
            publicKey = privateKey.publicKey
        }
        catch {
            throw KeyError.InvalidHex
        }
    }

    func privateKeyHex() -> String {
        return String(bytes: privateKey.rawRepresentation.bytes)
    }

    func publicKeyHex() -> String {
        return String(bytes: privateKey.publicKey.xonly.bytes)
    }

    func signature<D: Digest>(for digest: D) throws -> secp256k1.Signing.SchnorrSignature {
        return try privateKey.schnorr.signature(for: digest)
    }

    public static func newKeys() throws -> Keys {
        do {
            return try self.init(privateKey: secp256k1.Signing.PrivateKey())
        }
        catch {
            throw KeyError.NewKeyError
        }
    }

    enum KeyError: Error {
        case InvalidHex
        case NewKeyError
    }
}
