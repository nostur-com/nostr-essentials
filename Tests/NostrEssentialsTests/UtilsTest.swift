//
//  Test.swift
//  NostrEssentials
//
//  Created by Fabian Lachman on 21/10/2024.
//

import Testing
@testable import NostrEssentials

struct UtilsTest {

    @Test func normalizeRelayUrlsTest() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        
        #expect(normalizeRelayUrl("ws://localhost:8008/") == "ws://localhost:8008")
        #expect(normalizeRelayUrl("wss://example.com/") == "wss://example.com")
        #expect(normalizeRelayUrl("wss://example.com") == "wss://example.com")
        #expect(normalizeRelayUrl("wss://example.com/path") == "wss://example.com/path")
        #expect(normalizeRelayUrl("wss://example.com/PATH") != "wss://example.com/path")
        #expect(normalizeRelayUrl("wss://example.com/path/") == "wss://example.com/path/")
        #expect(normalizeRelayUrl("ws://example.com:80/") == "ws://example.com")
        #expect(normalizeRelayUrl("wss://example.com:443") == "wss://example.com")
        #expect(normalizeRelayUrl("wss://example.com:443/path") == "wss://example.com/path")
        #expect(normalizeRelayUrl("wss://example.com:443/path/") == "wss://example.com/path/")
        #expect(normalizeRelayUrl("wss://example.com:4437") == "wss://example.com:4437")
        #expect(normalizeRelayUrl("ws://example.com:80") == "ws://example.com")
        #expect(normalizeRelayUrl("ws://example.com:80/path") == "ws://example.com/path")
        #expect(normalizeRelayUrl("ws://example.com:80/path/") == "ws://example.com/path/")
        #expect(normalizeRelayUrl("broken") == "broken")
        #expect(normalizeRelayUrl("") == "")
    }

}
