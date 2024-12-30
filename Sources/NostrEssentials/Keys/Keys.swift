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

    public let privateKey: secp256k1.Schnorr.PrivateKey
    public let publicKey: secp256k1.Schnorr.XonlyKey
    
    public let privateKeyHex: String
    public let publicKeyHex: String

    public init(privateKey: secp256k1.Schnorr.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey = privateKey.xonly
        self.privateKeyHex = String(bytes: privateKey.dataRepresentation.bytes) 
        self.publicKeyHex = String(bytes: privateKey.xonly.bytes)
    }

    public init(privateKeyHex: String) throws {
        do {
            let privateKeyBytes = try privateKeyHex.bytes
            privateKey = try secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
            publicKey = privateKey.xonly
            self.privateKeyHex = String(bytes: privateKey.dataRepresentation.bytes)
            self.publicKeyHex = String(bytes: privateKey.xonly.bytes)
        }
        catch {
            throw KeyError.InvalidHex
        }
    }

    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Schnorr.SchnorrSignature {
        return try privateKey.signature(for: digest)
    }

    public static func newKeys() throws -> Keys {
        do {
            return try self.init(privateKey: secp256k1.Schnorr.PrivateKey())
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
