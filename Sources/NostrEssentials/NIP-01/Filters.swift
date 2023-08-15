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

public struct Filters:Codable, REQelement {
    public var ids:Set<String>?
    public var authors:Set<String>?
    public var kinds:Set<Int>?
    public var since:Int?
    public var until:Int?
    public var limit:Int?
    
    public init(ids: Set<String>? = nil, authors: Set<String>? = nil, kinds: Set<Int>? = nil, since: Int? = nil, until: Int? = nil, limit: Int? = nil) {
        self.ids = ids
        self.authors = authors
        self.kinds = kinds
        self.since = since
        self.until = until
        self.limit = limit
    }
    
    public func json() -> String? { toJson(self) }
}
