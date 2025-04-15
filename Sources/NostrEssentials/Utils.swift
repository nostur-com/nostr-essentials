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
    guard let urlObj = URL(string: url),
          let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
          let scheme = components.scheme,
          let host = components.host else {
        return url
    }
    
    var mutableComponents = components
    
    if mutableComponents.path == "/" {
        mutableComponents.path = ""
    }
    
    let defaultPortForScheme: [String: Int] = ["ws": 80, "wss": 443]
    if let port = mutableComponents.port, port == defaultPortForScheme[scheme] {
        mutableComponents.port = nil
    }
    
    let schemeLower = scheme.lowercased()
    let hostLower = host.lowercased()
    
    var normalizedUrl = schemeLower + "://" + hostLower
    if let port = mutableComponents.port {
        normalizedUrl = normalizedUrl + ":" + String(port)
    }
    normalizedUrl = normalizedUrl + mutableComponents.path
    
    return normalizedUrl
}
