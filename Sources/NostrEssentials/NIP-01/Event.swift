//
//  Event.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation
import secp256k1

public struct Event: Codable, Equatable, Identifiable {
    
    public static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id && lhs.sig == rhs.sig
    }
    
    public var id: String
    public var pubkey: String
    public var created_at: Int
    public var kind: Int
    public var tags: [Tag]
    public var content: String
    public var sig: String

    enum CodingKeys: String, CodingKey {
        case id
        case pubkey
        case created_at
        case kind
        case tags
        case content
        case sig
    }

    public init(pubkey:String = "", content:SetMetadata) {
        self.created_at = Int(Date.now.timeIntervalSince1970)
        self.kind = 0
        self.content = content.json() ?? ""
        self.id = ""
        self.tags = []
        self.pubkey = pubkey
        self.sig = ""
    }

    public init(pubkey:String = "", content:String = "", kind:Int = 1, created_at:Int = Int(Date.now.timeIntervalSince1970), id:String = "", tags:[Tag] = [], sig:String = "") {
        self.kind = kind
        self.created_at = created_at
        self.content = content
        self.id = id
        self.tags = tags
        self.pubkey = pubkey
        self.sig = sig
    }
    
    public mutating func withId() -> Event {
        self.id = self.computeId()
        return self
    }
    
    private func computeId(_ event:Event? = nil) -> String {
        let idDigest = self.computeIdDigest(event ?? self)
        return String(bytes:idDigest.bytes)
    }
    
    private func computeId(_ idDigest:SHA256Digest) -> String {
        return String(bytes:idDigest.bytes)
    }
    
    private func computeIdDigest( _ event:Event? = nil) -> SHA256Digest {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        
        let event = event ?? self
        let sEvent = SerializableEvent(pubkey: event.pubkey, created_at: event.created_at, kind: event.kind, tags: event.tags, content: event.content)
        
        let serializedEvent = try! encoder.encode(sEvent)
        return SHA256.hash(data: serializedEvent)
    }

    public mutating func sign(_ keys:Keys, replaceAuthor:Bool = false) throws -> Event {
        
        guard replaceAuthor || self.pubkey == keys.publicKeyHex else {
            throw EventError.PubkeyMismatch
        }
        
        self.pubkey = keys.publicKeyHex
        let sha256Serialized = self.computeIdDigest()
        let sig = try! keys.signature(for: sha256Serialized)

        guard keys.publicKey.isValidSignature(sig, for: sha256Serialized) else {
            throw Keys.KeyError.SigningFailure
        }

        self.sig = String(bytes: sig.bytes)
        self.id = self.computeId(sha256Serialized)

        return self
    }
    
    public func isRumor() -> Bool {
        let sha256Serialized = self.computeIdDigest()

        if self.id != String(bytes:sha256Serialized.bytes) {
            return false
        }
        if self.sig.isEmpty {
            return true
        }
        return false
    }

    public func verified() throws -> Bool {
        let sha256Serialized = self.computeIdDigest()

        guard self.id == String(bytes:sha256Serialized.bytes) else {
            throw EventError.InvalidId
        }

        let xOnlyKey = try secp256k1.Schnorr.XonlyKey(dataRepresentation: self.pubkey.bytes, keyParity: 1)

        // signature from this event
        let schnorrSignature = try secp256k1.Schnorr.SchnorrSignature(dataRepresentation: self.sig.bytes)

        // public and signature from this event is valid?
        guard xOnlyKey.isValidSignature(schnorrSignature, for: sha256Serialized) else {
            throw EventError.InvalidSignature
        }

        return true
    }
    
    public enum EventError: Error {
        case InvalidId
        case InvalidSignature
        case PubkeyMismatch
    }

    public func json() -> String? { toJson(self) }

//    func bolt11() -> String? {
//        tags.first(where: { $0.type == "bolt11" })?.tag[safe: 1]
//    }
//
//    func pTags() -> [String] {
//        tags.filter { $0.type == "p" } .map { $0.pubkey }
//    }
//
//    func eTags() -> [String] {
//        tags.filter { $0.type == "e" } .map { $0.id }
//    }
//
//    func firstA() -> String? {
//        tags.first(where: { $0.type == "a" })?.value
//    }
//
//    func firstP() -> String? {
//        tags.first(where: { $0.type == "p" })?.pubkey
//    }
//
//    func firstE() -> String? {
//        tags.first(where: { $0.type == "e" })?.id
//    }
//
//    func lastP() -> String? {
//        tags.last(where: { $0.type == "p" })?.pubkey
//    }
//
//    func lastE() -> String? {
//        tags.last(where: { $0.type == "e" })?.id
//    }
//
//    func tagNamed(_ type:String) -> String? {
//        tags.first(where: { $0.type == type })?.value
//    }
}

// Need this one in addition to Event because id must be 0 and should have no sig
private struct SerializableEvent: Encodable {
    public let id = 0
    public let pubkey: String
    public let created_at: Int
    public let kind: Int
    public let tags: [Tag]
    public let content: String

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(id)
        try container.encode(pubkey)
        try container.encode(created_at)
        try container.encode(kind)
        try container.encode(tags)
        try container.encode(content)
    }
}

public struct SetMetadata: Codable {

    public var name: String?
    public var display_name: String?
    public var about: String?
    public var picture: String?
    public var banner: String?
    public var nip05: String? = nil
    public var lud16: String? = nil
    public var lud06: String? = nil
    
    public init(name: String? = nil, display_name: String? = nil, about: String? = nil, picture: String? = nil, banner: String? = nil, nip05: String? = nil, lud16: String? = nil, lud06: String? = nil) {
        self.name = name
        self.display_name = display_name
        self.about = about
        self.picture = picture
        self.banner = banner
        self.nip05 = nip05
        self.lud16 = lud16
        self.lud06 = lud06
    }

    enum CodingKeys: String, CodingKey {
        case name
        case display_name
        case about
        case picture
        case banner
        case nip05
        case lud16
        case lud06
    }
    
    public func json() -> String? { toJson(self) }
}

extension Event {
    static public func fromJson(_ jsonString: String) -> Event? {
        guard let exampleEventData = jsonString.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Event.self, from: exampleEventData)
    }
}
