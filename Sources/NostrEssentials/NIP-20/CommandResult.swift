//
//  CommandResult.swift
//  
//
//  Created by Fabian Lachman on 26/11/2023.
//

import Foundation

// NIP-20: ["OK", <event_id>, <true|false>, <message>]
// Example: ["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, ""]
public struct CommandResult: Decodable {
    private let values: [Any]

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let _ = try container.decode(String.self) // ok
        let id = try container.decode(String.self) // id
        let success = try container.decode(Bool.self) // success
        if let message = try? container.decode(String.self) { // message
            values = [id, success, message]
        }
        else {
            values = [id, success]
        }
    }
        
    public var id: String { (values.first as? String) ?? "" }
    public var success: Bool {
        guard values.count > 1, let secondValue = values[1] as? Bool else { return false }
        return secondValue
    }
    public var message: String? {
        guard values.count > 2, let thirdValue = values[2] as? String else { return nil }
        return thirdValue
    }
}
