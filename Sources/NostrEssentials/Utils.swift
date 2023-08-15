//
//  Utils.swift
//  
//
//  Created by Fabian Lachman on 15/08/2023.
//

import Foundation

public func toJson(_ object:Encodable) -> String? {
    let encoder = JSONEncoder()
    guard let encoded = try? encoder.encode(object), let jsonString = String(data: encoded, encoding: .utf8) else {
        return nil
    }
    return jsonString
}
