//
//  Nip05.swift
//  NostrEssentials
//
//  Created by Fabian Lachman on 09/01/2025.
//

import Foundation


public struct Nip05Parts {
    let name: String
    let domain: String
    let nip05url: URL?
    
    init(name: String, domain: String) {
        self.name = name
        self.domain = domain
        self.nip05url = URL(string: "https://\(domain)/.well-known/nostr.json?name=\(name)")
    }
}

struct NostrJson: Decodable {
    let names: [String: String]
}

public enum Nip05Error: Error {
    case invalidFormat
    case invalidURL
    case invalidResponse
    case userNotFound
    case networkError(Error)
}

public func parseNip05Address(_ address: String) throws -> Nip05Parts {
    let searchTrimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if searchTrimmed.contains("@"),
          let atIndex = searchTrimmed.firstIndex(of: "@"),
          atIndex != searchTrimmed.startIndex,
          atIndex != searchTrimmed.index(before: searchTrimmed.endIndex) {
    
        let name = String(searchTrimmed[..<atIndex])
        let domain = String(searchTrimmed[searchTrimmed.index(after: atIndex)...])
        
        return Nip05Parts(name: name, domain: domain)
        
    }
    else if searchTrimmed.contains("@"),
            let atIndex = searchTrimmed.firstIndex(of: "@"),
            atIndex == searchTrimmed.startIndex,
            atIndex != searchTrimmed.index(before: searchTrimmed.endIndex) {
        let name = "_"
        let domain = String(searchTrimmed[searchTrimmed.index(after: atIndex)...])
        
        return Nip05Parts(name: name, domain: domain)
    }
    else {
        throw Nip05Error.invalidFormat
    }
    
    
}

public func fetchPubkey(from nip05parts: Nip05Parts) async throws -> String {
    guard let url = nip05parts.nip05url else {
        throw Nip05Error.invalidURL
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let nostrJson = try JSONDecoder().decode(NostrJson.self, from: data)
        
        guard let pubkey = nostrJson.names[nip05parts.name], !pubkey.isEmpty else {
            throw Nip05Error.userNotFound
        }
        
        return pubkey
    } catch let _ as DecodingError {
        throw Nip05Error.invalidResponse
    } catch {
        throw Nip05Error.networkError(error)
    }
}

public func lookupNip05(_ address: String) async throws -> String {
    let parts = try parseNip05Address(address)
    return try await fetchPubkey(from: parts)
}
