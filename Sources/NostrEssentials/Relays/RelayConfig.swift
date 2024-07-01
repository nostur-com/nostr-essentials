//
//  RelayConfig.swift
//
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation

public struct RelayConfig: Identifiable, Hashable, Equatable {
    public var id: String { url.lowercased() }
    
    public let url: String
    public var read: Bool
    public var write: Bool
    
    public init(url: String, read: Bool, write: Bool) {
        self.url = normalizeRelayUrl(url)
        self.read = read
        self.write = write
    }
    
    mutating func setRead(_ value: Bool) {
        self.read = value
    }
    
    mutating func setWrite(_ value: Bool) {
        self.write = value
    }
}
