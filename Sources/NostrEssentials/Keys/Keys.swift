//
//  Keys.swift
//
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation
import secp256k1
import CommonCrypto

public struct Keys {

    public let privateKey:secp256k1.Signing.PrivateKey
    public let publicKey:secp256k1.Signing.PublicKey
    
    public let privateKeyHex:String
    public let publicKeyHex:String

    public init(privateKey:secp256k1.Signing.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
        self.privateKeyHex = String(bytes: privateKey.rawRepresentation.bytes)
        self.publicKeyHex = String(bytes: privateKey.publicKey.xonly.bytes)
    }

    public init(privateKeyHex:String) throws {
        do {
            let privateKeyBytes = try privateKeyHex.bytes
            privateKey = try secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
            publicKey = privateKey.publicKey
            self.privateKeyHex = String(bytes: privateKey.rawRepresentation.bytes)
            self.publicKeyHex = String(bytes: privateKey.publicKey.xonly.bytes)
        }
        catch {
            throw KeyError.InvalidHex
        }
    }

    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Signing.SchnorrSignature {
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

    public enum KeyError: Error {
        case InvalidHex
        case NewKeyError
        case SigningFailure
    }
}
