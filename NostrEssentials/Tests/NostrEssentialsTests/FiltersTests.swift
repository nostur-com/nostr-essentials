//
//  FiltersTests.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import XCTest
@testable import NostrEssentials

final class FiltersTests: XCTestCase {

    func testAuthors() throws {
        let filter = Filters(authors: ["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"])
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(filter) {
            XCTAssertEqual(
                """
{"authors":["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"]}
""", String(data: encoded, encoding: .utf8)!)
        }
    }
    
    func testIds() throws {
        let filter = Filters(ids: ["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"])
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(filter) {
            XCTAssertEqual(
                """
{"ids":["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"]}
""", String(data: encoded, encoding: .utf8)!)
        }
    }
    
    func testKinds() throws {
        let filter = Filters(kinds: [1])
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(filter) {
            XCTAssertEqual(
                """
{"kinds":[1]}
""", String(data: encoded, encoding: .utf8)!)
        }
    }
    
    func testSinceUntilLimit() throws {
        let filter = Filters(kinds: [1], since: 1676784320, until: 1678888888, limit: 777)
        
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(filter) {
            XCTAssertEqual(
                """
{"until":1678888888,"since":1676784320,"kinds":[1],"limit":777}
""", String(data: encoded, encoding: .utf8)!)
        }
    }

}
