//
//  ShareableIdentifier.swift
//
//
//  Created by Fabian Lachman on 17/08/2023.
//

import Foundation

// NIP-19: Shareable identifiers with extra metadata

public class ShareableIdentifier: Hashable {
    
    static public func == (lhs: ShareableIdentifier, rhs: ShareableIdentifier) -> Bool {
        lhs.bech32string == rhs.bech32string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bech32string)
    }
    
    public var id: String?
    public var dTag: String? { id }
    public var aTag: String? {
        guard let kind = kind else { return nil }
        guard let dTag = dTag else { return nil }
        guard let pubkey = pubkey else { return nil }
        return String(format: "%d:%@:%@", kind, pubkey, dTag)
    }
    let bech32string: String
    public var identifier: String { bech32string }
    public let prefix: String
    
    public var pubkey: String?
    public var privkey: String?
    public var relayUrl: String?
    public var relays: [String] = []
    public var relay:String? { relayUrl }
    public var kind: Int?
    
    public init(_ bech32string: String) throws {
        self.bech32string = bech32string
        
        if bech32string.count == 63 {
            if bech32string.prefix(4) == "npub" {
                self.prefix = "npub"
                self.pubkey = Keys.hex(bech32string)
                return
            }
            if bech32string.prefix(4) == "nsec" {
                self.prefix = "nsec"
                self.privkey = Keys.hex(bech32string)
                return
            }
            if bech32string.prefix(4) == "note" {
                self.prefix = "note"
                self.id = Keys.hex(bech32string)
                return
            }
        }
        
        let (prefix, tlvData) = try Bech32.decode(other: bech32string)
        self.prefix = prefix
        
        var currentIndex = 0
        while currentIndex < tlvData.count {
            guard currentIndex + 2 < tlvData.count else {
                throw EncodingError.InvalidFormat
            }
            let type = tlvData[currentIndex]
            let length = Int(tlvData[currentIndex + 1])
            guard currentIndex + 2 + length <= tlvData.count else {
                throw EncodingError.InvalidFormat
            }
            let value = tlvData.subdata(in: (currentIndex + 2)..<(currentIndex + 2 + length))
            currentIndex += 2 + length
            
            switch type {
                case 0:
                    switch prefix {
                        case "nprofile":
                            pubkey = value.hexEncodedString()
                        case "nevent":
                            id = value.hexEncodedString()
                        case "nrelay":
                            relayUrl = String(data: value, encoding: .utf8)
                        case "naddr":
                            id = String(data: value, encoding: .utf8) // identifier / "d" tag
                        default:
                            throw EncodingError.InvalidPrefix
                    }
                case 1:
                    let relay = String(data: value, encoding: .utf8)!
                    relays.append(relay)
                case 2:
                    switch prefix {
                        case "naddr":
                            pubkey = value.hexEncodedString()
                        case "nevent":
                            pubkey = value.hexEncodedString()
                        default:
                            throw EncodingError.InvalidPrefix
                    }
                case 3:
                    switch prefix {
                        case "naddr":
                            kind = Int(value.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian)
                        case "nevent":
                            kind = Int(value.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian)
                        default:
                            throw EncodingError.InvalidPrefix
                    }
                default:
                    throw EncodingError.InvalidType
            }
        }
    }
    
    // naddr/nevent/nprofile,nrelay
    public init(_ prefix: String, id: String? = nil, kind: Int? = nil, pubkey: String? = nil, dTag: String? = nil, relayUrl: String? = nil, relays: [String] = []) throws {
        
        if prefix == "npub", let pubkey {
            self.prefix = prefix
            self.bech32string = Keys.npub(hex: pubkey)
            return
        }
        if prefix == "note", let id {
            self.prefix = prefix
            self.bech32string = Keys.bech32(id, prefix: "note")
            return
        }
        if prefix == "nsec", let pubkey {
            self.prefix = prefix
            self.bech32string = Keys.nsec(hex: pubkey)
            return
        }
        
        self.prefix = prefix
        self.kind = kind
        self.pubkey = pubkey
        self.id = dTag ?? (id ?? nil)
        self.relayUrl = relayUrl
        self.relays = relays
        
        var tlvData = Data()
        
        if let dTag, prefix == "naddr" {
            // Append TLV for the special type
            let dTagValue = dTag.data(using: .utf8)!
            tlvData.append(0) // Type
            tlvData.append(UInt8(dTagValue.count)) // Length
            tlvData.append(contentsOf: dTagValue) // Value
        }
        else if let id, prefix == "nevent" {
            // Append TLV for the special type
            let id = id.hexToBytes()
            tlvData.append(0) // Type
            tlvData.append(UInt8(id.count)) // Length
            tlvData.append(contentsOf: id) // Value
        }
        else if let pubkey, prefix == "nprofile" {
            let authorValue = pubkey.hexToBytes()
            tlvData.append(0)
            tlvData.append(UInt8(authorValue.count))
            tlvData.append(contentsOf: authorValue)
        }
        else if let relayUrl, prefix == "nrelay" {
            let value = relayUrl.data(using: .utf8)!
            tlvData.append(0)
            tlvData.append(UInt8(value.count))
            tlvData.append(value)
        }
        
        if prefix != "nprofile", let pubkey {
            let authorValue = pubkey.hexToBytes()
            tlvData.append(2)
            tlvData.append(UInt8(authorValue.count))
            tlvData.append(contentsOf: authorValue)
        }
        
        if let kind {
            var kindValue = UInt32(kind).bigEndian
            let kindBytes = withUnsafeBytes(of: &kindValue) { Array($0) }
            tlvData.append(3) // Type
            tlvData.append(UInt8(kindBytes.count)) // Length (assuming 4 bytes)
            tlvData.append(contentsOf: kindBytes) // Value
        }
        
        if !relays.isEmpty {
            for relay in relays {
                let value = relay.data(using: .utf8)!
                tlvData.append(1)
                tlvData.append(UInt8(value.count))
                tlvData.append(value)
            }
        }
        
        let bech32 = Bech32()
        self.bech32string = bech32.encode(prefix, values: tlvData, eightToFive: true)
    }
    
    
    public init(aTag: String) throws {
        self.prefix = "naddr"
        
        let elements = aTag.split(separator: ":")
        guard elements.count >= 3 else {
            throw EncodingError.InvalidAtag
        }
        
        let aTagKind = elements[0]
        let aTagPubkey = elements[1]
        let aTagDefinition = elements[2]
        
        self.kind = Int(aTagKind)
        self.pubkey = String(aTagPubkey)
        self.id = String(aTagDefinition)
        
        var tlvData = Data()
        
        // Append TLV for the special type
        let dTagValue = String(aTagDefinition).data(using: .utf8)!
        tlvData.append(0) // Type
        tlvData.append(UInt8(dTagValue.count)) // Length
        tlvData.append(contentsOf: dTagValue) // Value
        
        let authorValue = String(aTagPubkey).hexToBytes()
        tlvData.append(2)
        tlvData.append(UInt8(authorValue.count))
        tlvData.append(contentsOf: authorValue)
        
        guard let kind = Int(aTagKind) else {
            throw EncodingError.InvalidAtag
        }
        
        var kindValue = UInt32(kind).bigEndian
        let kindBytes = withUnsafeBytes(of: &kindValue) { Array($0) }
        tlvData.append(3) // Type
        tlvData.append(UInt8(kindBytes.count)) // Length (assuming 4 bytes)
        tlvData.append(contentsOf: kindBytes) // Value
        
        let bech32 = Bech32()
        self.bech32string = bech32.encode(prefix, values: tlvData, eightToFive: true)
    }
    
    
    public enum EncodingError: Error {
        case InvalidFormat
        case InvalidType
        case InvalidPrefix
        case InvalidAtag
    }
}


extension Data {
    public func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
