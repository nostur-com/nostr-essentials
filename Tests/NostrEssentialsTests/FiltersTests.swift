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
        
        XCTAssertEqual(
            """
            {"authors":["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"]}
            """, filter.json())
        
    }
    
    func testIds() throws {
        let filter = Filters(ids: ["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"])
        
        XCTAssertEqual(
            """
            {"ids":["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"]}
            """, filter.json())
    }
    
    func testKinds() throws {
        let filter = Filters(kinds: [1])
        
        XCTAssertEqual(
            """
            {"kinds":[1]}
            """, filter.json())
        
    }
    
    func testSinceUntilLimit() throws {
        let filter = Filters(kinds: [1], since: 1676784320, until: 1678888888, limit: 777)
                        
        // final order is not determenistic but output should be something like:
        //  {"until":1678888888,"since":1676784320,"kinds":[1],"limit":777}
        
        XCTAssertTrue(filter.json()!.contains(###""until":1678888888"###))
        XCTAssertTrue(filter.json()!.contains(###""since":1676784320"###))
        XCTAssertTrue(filter.json()!.contains(###"limit":777"###))
        XCTAssertTrue(filter.json()!.contains(###""kinds":[1]"###))
    }
    
    func testTags() throws {
        let filterE = Filters(tagFilter: TagFilter(tag: "e", values: ["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"]))
                
        XCTAssertEqual(
            """
            {"#e":["5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"]}
            """, filterE.json())
        
        let filterP = Filters(tagFilter: TagFilter(tag: "p", values: ["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]))
                
        XCTAssertEqual(
            """
            {"#p":["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]}
            """, filterP.json())
    }
    
}
