//
//  Nip96WellKnown.swift
//
//
//  Created by Fabian Lachman on 18/10/2023.
//

import Foundation

// https://github.com/arthurfranca/nips/blob/nip-95-contender/96.md

public struct NIP96WellKnown: Codable {
    public let apiUrl:String // "https://nostrcheck.me/api/v2/media"
    public var downloadUrl:String? // https://nostrcheck.me/media" If absent, downloads are served from the api_url
    public var supportedNips:[Int]?
    public var tosUrl:String? // "https://nostrcheck.me/register/tos.php"
    public var contentTypes: [String]? // ["image/jpeg", "video/webm", "audio/*"]
}
