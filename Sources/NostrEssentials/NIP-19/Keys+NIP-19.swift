//
//  Keys+NIP-19.swift
//  
//  Extension on Keys for working with npub/nsec
//
//  Created by Fabian Lachman on 17/08/2023.
//

import Foundation

extension Keys {
    public func npub() -> String {
        let bech32 = Bech32()
        let publicKeyData = Data(bytes: privateKey.publicKey.xonly.bytes, count: 32)
            .convertBits(from: 8, to: 5, pad: true)!
        return bech32.encode("npub", values: publicKeyData)
    }
    
    public func nsec() -> String {
        let bech32 = Bech32()
        let privateKeyData = privateKey.rawRepresentation.convertBits(from: 8, to: 5, pad: true)!
        return bech32.encode("nsec", values: privateKeyData)
    }
    
    static public func npub(hex:String) -> String {
        return Self.bech32(hex, prefix: "npub")
    }
    
    static public func nsec(hex:String) -> String {
        return Self.bech32(hex, prefix: "nsec")
    }
    
    static public func bech32(_ idOrKey:String, prefix:String) -> String {
        let data = Data(bytes: idOrKey.hexToBytes(), count: 32)
            .convertBits(from: 8, to: 5, pad: true)!
        
        let bech32 = Bech32()
        return bech32.encode(prefix, values: data)
    }
    
    static public func hex(_ idORkey:String) -> String {
        let bech32 = Bech32()
        let (_, checksum) = try! bech32.decode(idORkey)
        let key = checksum.convertBits(from: 5, to: 8, pad: false)!.makeBytes()
        return key.hexString()
    }
    
    static public func hex(nsec:String) -> String {
        return Self.hex(nsec)
    }
    
    static public func hex(npub:String) -> String {
        return Self.hex(npub)
    }
    
    static public func hex(note1:String) -> String {
        return Self.hex(note1)
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
