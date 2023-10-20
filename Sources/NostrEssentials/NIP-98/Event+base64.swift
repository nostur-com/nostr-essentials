//
//  Event+base64.swift
//  
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation

extension Event {
    func base64() -> String? {
        guard let json = self.json() else { return nil }
        guard let jsonData = json.data(using: .utf8, allowLossyConversion: true) else { return nil }
        return jsonData.base64EncodedString()
    }
}


