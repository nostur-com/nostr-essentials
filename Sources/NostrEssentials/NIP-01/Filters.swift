//
//  Filters.swift
//  NIP-01
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

/**
  NIP-01:
 <filters> is a JSON object that determines what events will be sent in that subscription, it can have the following attributes:

 {
   "ids": <a list of event ids>,
   "authors": <a list of lowercase pubkeys, the pubkey of an event must be one of these>,
   "kinds": <a list of a kind numbers>,
   "#<single-letter>": <a list of event ids that are referenced in the tag specified by the single letter>,
   "since": <an integer unix timestamp in seconds, events must be newer than this to pass>,
   "until": <an integer unix timestamp in seconds, events must be older than this to pass>,
   "limit": <maximum number of events to be returned in the initial query>
 }
 */

public struct Filters: Encodable, REQelement {
    public var ids:Set<String>?
    public var authors:Set<String>?
    public var kinds:Set<Int>?
    private var tagFilter:TagFilter?
    public var since:Int?
    public var until:Int?
    public var limit:Int?
    
    public init(ids: Set<String>? = nil, authors: Set<String>? = nil, kinds: Set<Int>? = nil, tagFilter:TagFilter? = nil, since: Int? = nil, until: Int? = nil, limit: Int? = nil) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.tagFilter = tagFilter
        self.since = since
        self.until = until
        self.limit = limit
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode other properties
        if let ids = ids {
            try container.encode(ids, forKey: .ids)
        }
        if let authors = authors {
            try container.encode(authors, forKey: .authors)
        }
        if let kinds = kinds {
            try container.encode(kinds, forKey: .kinds)
        }
        if let since = since {
            try container.encode(since, forKey: .since)
        }
        if let until = until {
            try container.encode(until, forKey: .until)
        }
        if let limit = limit {
            try container.encode(limit, forKey: .limit)
        }
        
        // Special encoding for tagFilter
        if let tagFilter = tagFilter {
            var nestedContainer = encoder.container(keyedBy: DynamicKey.self)
            let key = DynamicKey(stringValue: "#\(tagFilter.tag)")!
            try nestedContainer.encode(tagFilter.values, forKey: key)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case ids, authors, kinds, since, until, limit
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    
    public func json() -> String? { toJson(self) }
}

public struct TagFilter {
    public var tag:String // "e" or "p" or "t", etc...
    public var values:[String] // <a list of event ids, or other values that are referenced in the tag specified by the single letter>
    
    public init(tag: String, values: [String]) {
        self.tag = tag
        self.values = values
    }
}
