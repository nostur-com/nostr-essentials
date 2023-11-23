//
//  RelayConfig.swift
//
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation

public struct RelayConfig: Identifiable, Hashable, Equatable {
    public var id: String { url }
    
    public let url: String
    public var read: Bool
    public var write: Bool
    
    public init(url: String, read: Bool, write: Bool) {
        self.url = normalizeRelayUrl(url)
        self.read = read
        self.write = write
    }
}
