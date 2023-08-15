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

struct ClientMessage: Encodable {
    
    enum ClientMessageType {
        case EVENT
        case REQ
        case CLOSE
    }
    
    let type:ClientMessageType
    
    // if EVENT:
    var event:Event?
    
    // if REQ or CLOSE:
    var subscriptionId:String?

    // if REQ
    var filters:[Filters]?
        
    
    func encode(to encoder: Encoder) throws {
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
    
    enum EncodingError: Error {
        case FiltersMissing
        case SubscriptionIdMissing
        case EventMissing
    }

    func json() -> String? { toJson(self) }
}

protocol REQelement: Codable {}

extension String: REQelement {}

struct REQmessage: Codable {
    var elements: [REQelement]
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        var elements: [REQelement] = []
        while !container.isAtEnd {
            if let stringElement = try? container.decode(String.self) {
                elements.append(stringElement)
            } else if let filterElement = try? container.decode(Filters.self) {
                elements.append(filterElement)
            }
        }
        
        self.elements = elements
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        for element in elements {
            if let stringElement = element as? String {
                try container.encode(stringElement)
            } else if let filterElement = element as? Filters {
                try container.encode(filterElement)
            }
        }
    }
    
    func json() -> String? { toJson(self) }
}
