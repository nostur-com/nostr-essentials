//
//  File.swift
//  
//
//  Created by Fabian Lachman on 05/01/2024.
//

import Foundation

// We need to know:
// - Per pubkey, which write relays are used, this should give us:
// - A list of relays with related pubkeys that can be found on each relay
//
//  This can be sorted, it will probably look like:
//  relay A: 80 pubkeys
//  relay B: 50 pubkeys
//  relay C: 45 pubkeys
//  relay D: 20 pubkeys
//  relay E: 5 pubkeys
//  relay F: 1 pubkey
//  relay G: 1 pubkey
//  relay H: 1 pubkey
//  relay I: 1 pubkey
//  relay J: 1 pubkey
//  relay K: 1 pubkey
//  relay L: 1 pubkey


public struct PreferredRelays {
    
    public init(findEventsRelays: [String : Set<String>], reachUserRelays: [String : Set<String>]) {
        self.findEventsRelays = findEventsRelays
        self.reachUserRelays = reachUserRelays
    }
    
    // Relays where we can find posts from someone. (key = relayUrl, value = pubkeys writing to that relay)
    // NIP-65: When seeking events from a user, Clients SHOULD use the WRITE relays of the user's kind:10002.
    public let findEventsRelays: [String: Set<String>]
    
    // Relays we should use to get a message to someone (key = relayUrl, value = pubkeys reading from that relay)
    // NIP-65: Broadcast the event all READ relays of each tagged user
    public let reachUserRelays: [String: Set<String>]
}

// Takes kind:10002 events, check to which relays the kind:10002 author writes to, and also which relays the author reads from,
// return those as 2 dictionaries in PreferredRelays.
public func pubkeysByRelay(_ kind10002s: [Event], ignoringRelays ignoreRelays: Set<String> = []) -> PreferredRelays {
    
    return PreferredRelays(
        findEventsRelays: kind10002s.reduce([:]) { (partialResult: [String: Set<String>], kind10002: Event) in
            var nextResult = partialResult
            kind10002.tags.filter { tag in // Only write relays
                tag.type == "r" && (tag.tag.count == 2 || (tag.tag.count == 3 && tag.tag[2] == "write"))
            }
            .compactMap { $0.value } // ["r","wss://nos.lol"] to "wss://nos.lol"
            .map { normalizeRelayUrl($0) }
            // Don't use relays that are widely known to be special purpose relays, not meant for finding events to (eg blastr)
            .filter({ relayUrl in !ignoreRelays.contains(relayUrl) })
            .forEach { relayUrl in
                if nextResult[relayUrl] == nil {
                    nextResult[relayUrl] = [kind10002.pubkey]
                }
                else {
                    nextResult[relayUrl]?.insert(kind10002.pubkey)
                }
            }
            return nextResult
        },
        reachUserRelays: kind10002s.reduce([:]) { (partialResult: [String: Set<String>], kind10002: Event) in
            var nextResult = partialResult
            kind10002.tags.filter { tag in // Only read relays
                tag.type == "r" && (tag.tag.count == 2 || (tag.tag.count == 3 && tag.tag[2] == "read"))
            }
            .compactMap { $0.value } // ["r","wss://nos.lol"] to "wss://nos.lol"
            .map { normalizeRelayUrl($0) }
            // Don't use relays that are widely known to be special purpose relays, not meant for reading from (eg blastr)
            .filter({ relayUrl in !ignoreRelays.contains(relayUrl) })
            .forEach { relayUrl in
                if nextResult[relayUrl] == nil {
                    nextResult[relayUrl] = [kind10002.pubkey]
                }
                else {
                    nextResult[relayUrl]?.insert(kind10002.pubkey)
                }
            }
            return nextResult
        }
    )
}


// MARK: READING EVENTS

// Multiple nostr requests derived from a single request by matching the pubkeys to specific relays using the Outbox model.
// Creating this require knowing which pubkeys are using which relays (kind 10002 / NIP-65)
public struct RequestPlan {
    // We need:
    // - Query for our relay set
    // - Queries for outbox relays
    
    // The main request, as if we were not using the inbox/outbox model
    // Should be sent to our main relays
    public let originalRequest: [Filters]
    
    // The requests specific to each relay (different pubkeys per relay)
    // Should be sent to each pubkey's write relay (which is the key of this dictionary)
    public let findEventsRequests: [String: FindEventsRequest]
}

public struct FindEventsRequest {
    public let pubkeys: Set<String>
    private let _filters: [Filters]
    
    init(pubkeys: Set<String>, filters: [Filters]) {
        self.pubkeys = pubkeys
        self._filters = filters
    }
    
    public var filters: [Filters] {
        _filters.map { filter in
            var filterWithAuthors = filter
            filterWithAuthors.authors = pubkeys
            return filterWithAuthors
        }
    }
}

public func createRequestPlan(pubkeys: Set<String>,
                       reqFilters: [Filters],
                       ourReadRelays: Set<String>, // Should be only our read relays
                       preferredRelays: PreferredRelays,
                              skipTopRelays: Int = 0) -> RequestPlan {
    
    var findEventsRequests: [String: FindEventsRequest] = [:]
    var pubkeysAccountedFor: Set<String> = []
    var skipped = 0
    
    // Create outbox requests per relay
    for (relay, relayPubkeys) in preferredRelays.findEventsRelays
        // Don't use a relay that is already in our main relay set, we want redundancy
        .filter({ item in !ourReadRelays.contains(item.key) }) // <-- TODO: FILTER OR NOT (SPEED VS REDUDANCY)
            
        // Only use the outbox relays for the pubkeys in this request
        .filter({ item in item.value.intersection(pubkeys).count > 0 })

        // Sort the relays by most pubkeys
        .sorted(by: { $0.value.count > $1.value.count })
    {
        if skipped < skipTopRelays { // Skip top relays so we don't end up using the same centralized relays again
            skipped = skipped + 1
            continue
        }

        // remove any pubkeys we already have accounted for in a previous request
        let pubkeysForThisRelay = relayPubkeys.intersection(pubkeys.subtracting(pubkeysAccountedFor))
        if pubkeysForThisRelay.isEmpty { continue }
        
        // Take the original request and set the pubkeys for this relay as authors
        let relayScopedFilters = reqFilters.map { filter in
            var scopedAuthorsFilter = filter
            scopedAuthorsFilter.authors = pubkeysForThisRelay
            return scopedAuthorsFilter
        }
        
        // Represent the request as a OutboxRequest struct for easier handling in other parts of app
        // Save it in a dict where the key is the relay url for this request
        findEventsRequests[relay] = FindEventsRequest(pubkeys: pubkeysForThisRelay, filters: relayScopedFilters)
        
        // Track which pubkeys we already have requests so we can skip them in the the next iteration
        pubkeysAccountedFor.formUnion(pubkeysForThisRelay)
    }
     
    return RequestPlan(
        originalRequest: reqFilters, findEventsRequests: findEventsRequests
    )
}

// MARK: WRITING EVENTS


// SEND TO OUR RELAY SET + READ RELAYS OF GIVEN PUBKEYS (REPLYING TO)
public struct WritePlan {
    // Should be sent to each pubkey's read relay (which is the key of this dictionary)
    public let relays: [String: Set<String>] // [relay: pubkeys]
}

public func createWritePlan(pubkeys: Set<String>,
                       ourWriteRelays: Set<String>, // Should be only our write relays
                       preferredRelays: PreferredRelays) -> WritePlan {
    
    var destinationRelays: [String: Set<String>] = [:] // [relay: pubkeys]
    var pubkeysAccountedFor: Set<String> = []
    
    // Find inboxes for pubkeys
    for (relay, relayPubkeys) in preferredRelays.reachUserRelays
        // Don't use a relay that is already in our main relay set, we want redundancy
        .filter({ item in !ourWriteRelays.contains(item.key) }) // <-- TODO: FILTER OR NOT (SPEED VS REDUDANCY)
            
        // Only use the relays for the pubkeys we need to reach
        .filter({ item in item.value.intersection(pubkeys).count > 0 })

        // Sort the relays by most pubkeys
        .sorted(by: { $0.value.count > $1.value.count })
    {
        

        // remove any pubkeys we already have accounted for in a previous request
        let pubkeysForThisRelay = relayPubkeys.intersection(pubkeys.subtracting(pubkeysAccountedFor))
        if pubkeysForThisRelay.isEmpty { continue }
                
        // Represent the request as a OutboxRequest struct for easier handling in other parts of app
        // Save it in a dict where the key is the relay url for this request
        destinationRelays[relay] = pubkeysForThisRelay
        
        // Track which pubkeys we already have requests so we can skip them in the the next iteration
        pubkeysAccountedFor.formUnion(pubkeysForThisRelay)
    }
     
    return WritePlan(relays: destinationRelays)
}
