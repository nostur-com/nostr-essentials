//
//  Dip01Tests.swift
//  
//
//  Created by Fabian Lachman on 26/11/2023.
//

import XCTest
@testable import NostrEssentials

final class Dip01Tests: XCTestCase {

    func testReadImetaTag() throws {
        let exampleEventJson = ###"{"pubkey":"215e2d416a8663d5b2e44f30d6c46750db7254cdbd2cf87fea4c1549d97486d4","content":"GM #coffeechain https://image.nostr.build/54d6d3f12b348c6923adbd3f01881064b5f402425dc762b25c31b5d600cf9c37.jpg ","id":"d454532ea605a568392750fed9c414300debc9fc10d6bc75b544905dddd65dfd","created_at":1700980865,"sig":"59eebc4c00c1c765b54672d989e67b506a6ce41845413a69a8335f801ed7cb304e01e57a9d699d9aa125827111d31a621a99e668b10229c1f6ef1042c7467b61","kind":1,"tags":[["imeta","url https://image.nostr.build/54d6d3f12b348c6923adbd3f01881064b5f402425dc762b25c31b5d600cf9c37.jpg","blurhash eKHUUl4:?ZofE1~VMxRjkCWBtOM{E1t6xH%KjsM|bIoMIpt7-payWB","dim 3024x4032"],["t","coffeechain"],["r","https://image.nostr.build/54d6d3f12b348c6923adbd3f01881064b5f402425dc762b25c31b5d600cf9c37.jpg"]]}"###
        
        let exampleEvent = Event.fromJson(exampleEventJson)
        
        XCTAssertEqual(exampleEvent?.tags.first?.type, "imeta")
        XCTAssertEqual(exampleEvent?.iMeta(for: "https://image.nostr.build/54d6d3f12b348c6923adbd3f01881064b5f402425dc762b25c31b5d600cf9c37.jpg")?.dim, "3024x4032")
        XCTAssertEqual(exampleEvent?.iMeta(for: "https://image.nostr.build/54d6d3f12b348c6923adbd3f01881064b5f402425dc762b25c31b5d600cf9c37.jpg")?.blurhash, "eKHUUl4:?ZofE1~VMxRjkCWBtOM{E1t6xH%KjsM|bIoMIpt7-payWB")
    }

}
