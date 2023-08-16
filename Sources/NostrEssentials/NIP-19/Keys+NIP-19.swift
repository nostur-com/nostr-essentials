//
//  Keys+NIP-19.swift
//  
//  Extension on Keys for working with npub/nsec
//
//  Created by Fabian Lachman on 17/08/2023.
//

import Foundation

extension Keys {
    var npub:String {
        let bech32 = Bech32()
        let publicKeyData = Data(bytes: privateKey.publicKey.xonly.bytes, count: 32)
            .convertBits(from: 8, to: 5, pad: true)!
        return bech32.encode("npub", values: publicKeyData)
    }
    
    var nsec:String {
        let bech32 = Bech32()
        let privateKeyData = privateKey.rawRepresentation.convertBits(from: 8, to: 5, pad: true)!
        return bech32.encode("nsec", values: privateKeyData)
    }
    
    static public func npub(hex:String) -> String {
        let data = Data(bytes: hex.hexToBytes(), count: 32)
            .convertBits(from: 8, to: 5, pad: true)!
        
        let bech32 = Bech32()
        return bech32.encode("npub", values: data)
    }
    
    static public func nsec(hex:String) -> String {
        let data = Data(bytes: hex.hexToBytes(), count: 32)
            .convertBits(from: 8, to: 5, pad: true)!
        
        let bech32 = Bech32()
        return bech32.encode("nsec", values: data)
    }
    
    
    static public func hex(nsec:String) -> String {
        let bech32 = Bech32()
        let (_, checksum) = try! bech32.decode(nsec)
        let key = checksum.convertBits(from: 5, to: 8, pad: false)!.makeBytes()
        return key.hexString()
    }
    
    static public func hex(npub:String) -> String {
        let bech32 = Bech32()
        let (_, checksum) = try! bech32.decode(npub)
        let key = checksum.convertBits(from: 5, to: 8, pad: false)!.makeBytes()
        return key.hexString()
    }
    
    
}

extension String {
    // CHATGPT3.5 version
    func hexToBytes() -> [UInt8] {
        var startIndex = self.startIndex
        return stride(from: 0, to: self.count, by: 2).compactMap { _ in
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

extension Array where Element == UInt8 {
    
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension Data {
    
    // CHATGPT3.5
    public func makeBytes() -> [UInt8] {
        var array = Array<UInt8>(repeating: 0, count: count)
        array.withUnsafeMutableBytes { buffer in
            _ = copyBytes(to: buffer)
        }
        return array
    }
    
}
