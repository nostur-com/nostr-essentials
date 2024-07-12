//
//  RemoteSigningHelpers.swift
//
//
//  Created by Fabian Lachman on 05/07/2024.
//

import Foundation

public struct BunkerURL {
    public let pubkey: String
    public let secret: String
    public var relay: String?
}

public func parseBunkerUrl(_ input: String) -> BunkerURL? {
    // Ensure the input starts with "bunker://"
       guard input.starts(with: "bunker://") else {
           return nil
       }

       // Remove the "bunker://" prefix
       let withoutScheme = input.dropFirst("bunker://".count)
       
       // Separate the main part and the query string
       let components = withoutScheme.split(separator: "?", maxSplits: 1)
       guard components.count == 2 else {
           return nil
       }

       let mainPart = String(components[0])
       let queryString = String(components[1])

       // Extract the pubkey from the main part
       let pubkey = mainPart

       // Parse the query string
       var secret: String?
       var relay: String?
       let queryItems = queryString.split(separator: "&")
       for item in queryItems {
           let keyValue = item.split(separator: "=", maxSplits: 1)
           if keyValue.count == 2 {
               let key = String(keyValue[0])
               let value = String(keyValue[1])
               if key == "secret" {
                   secret = value
               } else if key == "relay" {
                   if relay != nil { continue }
                   relay = value.removingPercentEncoding ?? value
               }
           }
       }

       // Ensure we have both a pubkey and a secret
       guard let unwrappedSecret = secret else {
           return nil
       }

       return BunkerURL(pubkey: pubkey, secret: unwrappedSecret, relay: relay)
}
