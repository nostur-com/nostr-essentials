//
//  Tag.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

public struct Tag: Codable {
    public let tag: [String]
    public var type: String { tag.first ?? "" } // "e", "p", "t", etc..
    public var id: String? { tag[1] } // for convenience
    public var pubkey: String? { tag[1] } // for convenience
    public var value: String? { tag[1] } // for convenience
    
    public init(_ tag:[String]) {
        self.tag = tag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        tag = try container.decode([String].self)

        guard !tag.isEmpty else {
            throw DecodingError.MissingTag
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(contentsOf: tag)
    }
    
    public enum DecodingError: Error {
        case MissingTag
    }
    
    public func json() -> String? { toJson(self) }
}
