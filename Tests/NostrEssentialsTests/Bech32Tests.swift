//
//  Bech32Tests.swift
//  
//
//  Created by Fabian Lachman on 17/08/2023.
//

import XCTest
@testable import NostrEssentials

final class Bech32Tests: XCTestCase {
 
    func testDecodingLNURL() throws {
        XCTAssertEqual(try? Bech32.decode(lnurl: "LNURL1DP68GURN8GHJ7UM9WFMXJCM99E3K7MF0V9CXJ0M385EKVCENXC6R2C35XVUKXEFCV5MKVV34X5EKZD3EV56NYD3HXQURZEPEXEJXXEPNXSCRVWFNV9NXZCN9XQ6XYEFHVGCXXCMYXYMNSERXFQ5FNS"), URL(string:"https://service.com/api?q=3fc3645b439ce8e7f2553a69e5267081d96dcd340693afabe04be7b0ccd178df")!)
        
    }

}
