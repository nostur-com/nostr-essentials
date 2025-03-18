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
public func normalizeRelayUrl(_ url: String) -> String {
    guard let urlObj = URL(string: url) else {
        return url.lowercased()
    }
    
    var components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false)!
    
    // Normalize path: remove trailing slash if path is "/"
    if components.path == "/" {
        components.path = ""
    }
    
    // Remove default ports (80 for "ws", 443 for "wss")
    let defaultPortForScheme: [String: Int] = ["ws": 80, "wss": 443]
    if let port = components.port, let scheme = components.scheme,
       port == defaultPortForScheme[scheme] {
        components.port = nil
    }
    
    // Lowercase each part before reconstructing
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    components.path = components.path.lowercased()
    
    // Manually construct the string for efficiency
    var normalizedUrl = components.scheme! + "://" + components.host!
    if let port = components.port {
        normalizedUrl += ":" + String(port)
    }
    normalizedUrl += components.path
    
    return normalizedUrl
}
