//
//  RelayMessage.swift
//
//
//  Created by Fabian Lachman on 26/11/2023.
//

import Foundation

/**
 Relays can send 4 types of messages, which must also be JSON arrays, according to the following patterns:

 ["EVENT", <subscription_id>, <event JSON as defined above>], used to send events requested by clients.
 ["OK", <event_id>, <true|false>, <message>], used to indicate acceptance or denial of an EVENT message.
 ["EOSE", <subscription_id>], used to indicate the end of stored events and the beginning of events newly received in real-time.
 ["NOTICE", <message>], used to send human-readable error messages or other things to clients.
 */

public enum RelayMessageType: String {
    case EVENT
    case NOTICE
    case EOSE
    case OK
    case AUTH
}

public struct RelayMessage {

    public var relays: RelayBag
    public let type: RelayMessageType
    public let message: String
    public var subscriptionId:String?
    public var event: Event?
    
    public var id:String?
    public var success:Bool?
    
    public init(relayUrl: String, type: RelayMessageType, message: String, subscriptionId: String? = nil,
         id:String? = nil, success: Bool? = nil, event: Event? = nil) {
        self.relays = RelayBag(relays: [relayUrl])
        self.type = type
        self.message = message
        self.subscriptionId = subscriptionId
        self.event = event
        self.id = id
        self.success = success
    }
}

public struct Message: Decodable {
    private var container: UnkeyedDecodingContainer
    public let values: [Any]

    public init(from decoder: Decoder) throws {
        container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        let subscription = try container.decode(String.self)
        values = [type, subscription]
    }
    
    public var type: String { (values.first as? String) ?? "" }
    public var subscription: String {
        guard values.count > 1, let secondValue = values[1] as? String else { return "" }
        return secondValue
    }
    
    public lazy var event:Event? = {
        return try? self.container.decode(Event.self)
    }()
}

public func parseRelayMessage(text: String, relay: String) throws -> RelayMessage {
    guard let dataFromString = text.data(using: .utf8, allowLossyConversion: false) else {
        throw RelayMessageParsingError.FAILED_TO_PARSE
    }
    
    guard text.prefix(7) != ###"["EOSE""### 
    else {
        let decoder = JSONDecoder()
        guard let eose = try? decoder.decode(Message.self, from: dataFromString) else {
            throw RelayMessageParsingError.FAILED_TO_PARSE
        }
        return RelayMessage(relayUrl: relay, type: .EOSE, message: text, subscriptionId: eose.subscription)
    }
    
    guard text.prefix(7) != ###"["AUTH""### else {
        return RelayMessage(relayUrl: relay, type: .AUTH, message: text)
    }
    
    guard text.prefix(9) != ###"["NOTICE""### 
    else {
        let decoder = JSONDecoder()
        guard let notice = try? decoder.decode(Message.self, from: dataFromString) else {
            throw RelayMessageParsingError.FAILED_TO_PARSE
        } // same format as eose, but instead of subscription id it will be the notice text. do proper later
        return RelayMessage(relayUrl: relay, type: .NOTICE, message: notice.subscription)
    }
    
    guard text.prefix(5) != ###"["OK""### 
    else {
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CommandResult.self, from: dataFromString) else {
            throw RelayMessageParsingError.FAILED_TO_PARSE
        }
        return RelayMessage(relayUrl: relay, type: .OK, message: text, id :result.id, success: result.success)
    }
    
    guard text.prefix(8) == ###"["EVENT""### 
    else {
        throw RelayMessageParsingError.UNKNOWN_MESSAGE_TYPE
    }
    
    let decoder = JSONDecoder()
    
    // Try to get just the ID so if it is duplicate we don't parse whole event for nothing
    // Should be implemented when optimizing for performance. Disabled in this package
//    if let mMessage = try? decoder.decode(MinimalMessage.self, from: dataFromString) {
//        // skip if duplicate, update RelayBag so we still know from which relays a message came from if multiple
//    }

    guard var relayMessage = try? decoder.decode(Message.self, from: dataFromString) else {
        throw RelayMessageParsingError.FAILED_TO_PARSE
    }

    guard let event = relayMessage.event else {
        throw RelayMessageParsingError.MISSING_EVENT
    }
    
    return RelayMessage(relayUrl: relay, type: .EVENT, message: text, subscriptionId: relayMessage.subscription, event: event)
}

public enum RelayMessageParsingError: Error {
    case FAILED_TO_PARSE // Failed to parse raw websocket
    case UNKNOWN_MESSAGE_TYPE // NOT EVENT, NOTICE or EOSE
    case FAILED_TO_PARSE_EVENT // Could parse raw websocket but not event
    case DUPLICATE_ID // We already received this message (in cache, not db, db check is later)
    case NOT_IN_WOT // Message not in Web of Trust, we don't want it
    case MISSING_EVENT
    case INVALID_SIGNATURE
    case DUPLICATE_ALREADY_SAVED
    case DUPLICATE_ALREADY_PARSED
    case DUPLICATE_ALREADY_RECEIVED
    case DUPLICATE_UNKNOWN
}

public class RelayBag {
    public var relays:Set<String> = [] // Set of relay urls (received from)
    public init(relays: Set<String>) {
        self.relays = relays
    }
}

// Structs to optimize/reduce parsing/decoding of duplicate messages
// Not active because that part is disabled in parseRelayMessage(), see comments in that function
// Still shown here for reference
public struct MinimalMessage: Decodable {
    private var container:UnkeyedDecodingContainer
    
    public let subscriptionId: String
    public let id: String
    public let kind: Int
    public let pubkey: String

    public init(from decoder: Decoder) throws {
        container = try decoder.unkeyedContainer()
        _ = try container.decode(String.self) // Discard "EVENT"
        subscriptionId = try container.decode(String.self) // for handling callbacks
        let minimalevent = try container.decode(MinimalEvent.self)
        id = minimalevent.id
        kind = minimalevent.kind
        pubkey = minimalevent.pubkey
    }
}

// Instead of full Event, this is a minimal one to reduce parsing of duplicate events
// We need:
// - id to check duplicates
// - kind + pubkey to know if we received our contact list this session
public struct MinimalEvent: Decodable {
    public let id: String
    public let kind: Int
    public let pubkey: String
}
