//
//  Utils.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

public func toJson(_ object:Encodable) -> String? {
    let encoder = JSONEncoder()
    guard let encoded = try? encoder.encode(object), let jsonString = String(data: encoded, encoding: .utf8) else {
        return nil
    }
    return jsonString
}

// Removes trailing slash, but only if its not part of path
// Makes url lowercased
// Removes :80 or :443
public func normalizeRelayUrl(_ url:String) -> String {
    let step1 = url.replacingOccurrences(of: "://", with: "")
    
    if (step1.components(separatedBy:"/").count - 1) == 1 && url.suffix(1) == "/" {
        return url.dropLast(1)
            .lowercased()
            .replacingOccurrences(of: ":80", with: "")
            .replacingOccurrences(of: ":443", with: "")
    }
    
    return url
        .lowercased()
        .replacingOccurrences(of: ":80", with: "")
        .replacingOccurrences(of: ":443", with: "")
    
    // "wss://example.com/" -> "wss://example.com"
    // "wss://example.com" -> "wss://example.com"
    // "wss://example.com/path" -> "wss://example.com/path"
    // "wss://example.com/path/" -> "wss://example.com/path/"
    // "ws://example.com:80/" -> "ws://example.com"
    // "wss://example.com:443" -> "wss://example.com"
    // "wss://example.com:443/path" -> "wss://example.com/path"
    // "wss://example.com:443/path/" -> "wss://example.com/path/"
}
