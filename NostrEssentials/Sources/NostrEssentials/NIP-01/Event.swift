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
    
    enum EventError : Error {
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

    init(pubkey:String = "", content:String = "", kind:Int = 1, created_at:Int = Int(Date.now.timeIntervalSince1970), id:String = "", tags:[Tag] = [], sig:String = "") {
        self.kind = kind
        self.created_at = created_at
        self.content = content
        self.id = id
        self.tags = tags
        self.pubkey = pubkey
        self.sig = sig
    }
    
}

struct SetMetadata: Codable {

    var name: String?
    var display_name: String?
    var about: String?
    var picture: String?
    var banner: String?
    var nip05: String? = nil
    var lud16: String? = nil
    var lud06: String? = nil

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
    
    func json() -> String? { toJson(self) }
}
