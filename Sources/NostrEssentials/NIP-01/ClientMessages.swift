//
//  ClientMessages.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

/**
 NIP-01:
 From client to relay: sending events and creating subscriptions

 Clients can send 3 types of messages, which must be JSON arrays, according to the following patterns:

 ["EVENT", <event JSON as defined above>], used to publish events.
 ["REQ", <subscription_id>, <filters JSON>...], used to request events and subscribe to new updates.
 ["CLOSE", <subscription_id>], used to stop previous subscriptions.
 <subscription_id> is an arbitrary, non-empty string of max length 64 chars, that should be used to represent a subscription. Relays should manage <subscription_id>s independently for each WebSocket connection; even if <subscription_id>s are the same string, they should be treated as different subscriptions for different connections.

 <filters> is a JSON object that determines what events will be sent in that subscription, see Filters.swift
 */

public struct ClientMessage: Encodable {
    
    public enum ClientMessageType {
        case EVENT
        case REQ
        case CLOSE
    }
    
    public let type: ClientMessageType
    
    // if EVENT:
    public var event: Event?
    
    // if REQ or CLOSE:
    public var subscriptionId: String?

    // if REQ
    public var filters: [Filters]?
    
    public init(type: ClientMessageType, event: Event? = nil, subscriptionId: String? = UUID().uuidString, filters: [Filters]? = nil) {
        self.type = type
        self.event = event
        self.subscriptionId = subscriptionId
        self.filters = filters
    }
        
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        if type == .REQ {
            guard let filters = filters, !filters.isEmpty else { throw EncodingError.FiltersMissing }
            try container.encode("REQ") // "REQ"
            try container.encode(subscriptionId ?? UUID().uuidString)
            for filter in filters {
                try container.encode(filter)
            }
        }
        
        if type == .CLOSE {
            guard let subscriptionId = subscriptionId else { throw EncodingError.SubscriptionIdMissing }
            try container.encode("CLOSE") // "REQ"
            try container.encode(subscriptionId)
        }
        
        if type == .EVENT {
            guard let event = event else { throw EncodingError.EventMissing }
            try container.encode("EVENT") // "REQ"
            try container.encode(event)
        }
    }
    
    public enum EncodingError: Error {
        case FiltersMissing
        case SubscriptionIdMissing
        case EventMissing
    }

    public func json() -> String? { toJson(self) }
}

protocol REQelement: Encodable {}

extension String: REQelement {}

public struct REQmessage: Encodable {
    var elements: [REQelement]
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        for element in elements {
            if let stringElement = element as? String {
                try container.encode(stringElement)
            } else if let filterElement = element as? Filters {
                try container.encode(filterElement)
            }
        }
    }
    
    public func json() -> String? { toJson(self) }
}
