//
//  BlossomUploadResponse.swift
//
//
//  Created by Fabian Lachman on 05/05/2025.
//

import Foundation

public struct BlossomUploadResponse: Decodable {
    public let sha256: String
    public let size: Int
    public let uploaded: Int
    public var type: String?
    public let url: String
    
    public var nip94: [Tag]?
}
