//
//  Event.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

public struct Event: Codable {
    
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
    
    public enum EventError : Error {
        case InvalidId
        case InvalidSignature
        case EOSE
    }

    init(pubkey:String = "", content:SetMetadata) {
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
    
//    mutating func withId() -> NEvent {
//
//        let serializableEvent = NSerializableEvent(publicKey: self.publicKey, createdAt: self.createdAt, kind:self.kind, tags: self.tags, content: self.content)
//
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = .withoutEscapingSlashes
//        let serializedEvent = try! encoder.encode(serializableEvent)
//        let sha256Serialized = SHA256.hash(data: serializedEvent)
//
//        self.id = String(bytes:sha256Serialized.bytes)
//
//        return self
//    }

//    mutating func sign(_ keys:NKeys) throws -> NEvent {
//
//        let serializableEvent = NSerializableEvent(publicKey: keys.publicKeyHex(), createdAt: self.createdAt, kind:self.kind, tags: self.tags, content: self.content)
//
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = .withoutEscapingSlashes
//        let serializedEvent = try! encoder.encode(serializableEvent)
//        let sha256Serialized = SHA256.hash(data: serializedEvent)
//
//        let sig = try! keys.signature(for: sha256Serialized)
//
//
//        guard keys.publicKey.schnorr.isValidSignature(sig, for: sha256Serialized) else {
//            throw "Signing failed"
//        }
//
//        self.id = String(bytes:sha256Serialized.bytes)
//        self.publicKey = keys.publicKeyHex()
//        self.signature = String(bytes:sig.rawRepresentation.bytes)
//
//        return self
//    }

//    func verified() throws -> Bool {
//        L.og.debug("✍️ VERIFYING SIG ✍️")
//        let serializableEvent = NSerializableEvent(publicKey: self.publicKey, createdAt: self.createdAt, kind:self.kind, tags: self.tags, content: self.content)
//
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = .withoutEscapingSlashes
//        let serializedEvent = try! encoder.encode(serializableEvent)
//        let sha256Serialized = SHA256.hash(data: serializedEvent)
//
//        guard self.id == String(bytes:sha256Serialized.bytes) else {
//            throw "🔴🔴 Invalid ID 🔴🔴"
//        }
//
//        let xOnlyKey = try secp256k1.Signing.XonlyKey(rawRepresentation: self.publicKey.bytes, keyParity: 1)
//        let pubKey = secp256k1.Signing.PublicKey(xonlyKey: xOnlyKey)
//
//        // signature from this event
//        let schnorrSignature = try secp256k1.Signing.SchnorrSignature(rawRepresentation: self.signature.bytes)
//
//        // public and signature from this event is valid?
//        guard pubKey.schnorr.isValidSignature(schnorrSignature, for: sha256Serialized) else {
//            throw "Invalid signature"
//        }
//
//        return true
//    }

//    func eventJson(_ outputFormatting:JSONEncoder.OutputFormatting? = nil) -> String {
//        let encoder = JSONEncoder()
//        encoder.outputFormatting = outputFormatting ?? .withoutEscapingSlashes
//        let finalMessage = try! encoder.encode(self)
//
//        return String(data: finalMessage, encoding: .utf8)!
//    }
//
//    func wrappedEventJson() -> String {
//        return NRelayMessage.event(self)
//    }
//
//
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
