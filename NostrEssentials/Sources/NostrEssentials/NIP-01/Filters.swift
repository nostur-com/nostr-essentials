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

struct Filters:Codable, REQelement {
    var ids:Set<String>?
    var authors:Set<String>?
    var kinds:Set<Int>?
    var since:Int?
    var until:Int?
    var limit:Int?
}
