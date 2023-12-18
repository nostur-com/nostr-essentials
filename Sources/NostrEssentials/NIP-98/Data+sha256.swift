//
//  Data+sha256.swift
//  
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation
import CryptoKit

extension Data {
    public func sha256() -> Data {
        let digest = SHA256.hash(data: self)
        return Data(digest)
    }
}
