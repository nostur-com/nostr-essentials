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
    let step1 = url.replacingOccurrences(of: "://", with: "") // to count slashes but not the first
    
    let step2 = if (step1.components(separatedBy:"/").count - 1) == 1 && url.suffix(1) == "/" { // only 1 trailing slash?
        url
            .replacingOccurrences(of: ":80/", with: "/")
            .replacingOccurrences(of: ":443/", with: "/")
            .dropLast(1)
            .lowercased()
    }
    else {
        url
            .replacingOccurrences(of: ":80/", with: "/")
            .replacingOccurrences(of: ":443/", with: "/")
            .lowercased()
    }
    
    return if step2.suffix(3) == ":80" {
        String(step2.dropLast(3))
    }
    else if step2.suffix(4) == ":443" {
        String(step2.dropLast(4))
    }
    else {
        step2
    }

    // "wss://example.com/" -> "wss://example.com"
    // "wss://example.com" -> "wss://example.com"
    // "wss://example.com/path" -> "wss://example.com/path"
    // "wss://example.com/path/" -> "wss://example.com/path/"
    // "ws://example.com:80/" -> "ws://example.com"
    // "wss://example.com:443" -> "wss://example.com"
    // "wss://example.com:443/path" -> "wss://example.com/path"
    // "wss://example.com:443/path/" -> "wss://example.com/path/"
}
