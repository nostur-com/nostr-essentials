//
//  UploadResponse.swift
//
//
//  Created by Fabian Lachman on 20/10/2023.
//

import Foundation

public struct UploadResponse: Decodable {
    public let status: String // "success" if successful or "error" if not
    public var message: String? // Free text success, failure or info message  "Upload successful.",
    public var processingUrl: String? // Optional. See "Delayed Processing" section
    public var percentage: Int? // Processing percentage. An integer between 0 and 100.
    
    // This uses the NIP-94 event format but DO NOT need
    // to fill some fields like "id", "pubkey", "created_at" and "sig"
    //
    // This holds the download url ("url"),
    // the ORIGINAL file hash before server transformations ("ox")
    // and, optionally, all file metadata the server wants to make available
    //
    // nip94_event field is absent if unsuccessful upload
    public let nip94Event: Nip94Event
}


public struct Nip94Event: Decodable {
    
    public let tags: [Tag] // Required tags: "url" and "ox", see more info in comment below
    
    public var content: String? // ""
}

/**
// Info for Nip94Event.tags:

// Can be same from /.well-known/nostr/nip96.json's "download_url" field
// (or "api_url" field if "download_url" is absent or empty) with appended
// original file hash.
//
// Note we appended .png file extension to the `x` value
// (it is optional but extremely recommended to add the extension as it will help nostr clients
// with detecting the file type by using regular expression)
//
// Could also be any url to download the file
// (using or not using the /.well-known/nostr/nip96.json's "download_url" prefix),
// for load balancing purposes for example.
["url", "https://your-file-server.example/custom-api-path/719171db19525d9d08dd69cb716a18158a249b7b3b3ec4bbdec5698dca104b7b.png"],
// SHA-256 hash of the ORIGINAL file, before transformations.
// The server MUST store it even though it represents the ORIGINAL file because
// users may try to download the transformed file using this value
[
    "ox",
    "719171db19525d9d08dd69cb716a18158a249b7b3b3ec4bbdec5698dca104b7b",
    // Server hostname where one can find the
    // /.well-known/nostr/nip96.json config resource.
    //
    // This value is an important hint that clients can use
    // to find new NIP-96 compatible file storage servers.
    "https://your-file-server.example"
],
// Optional. SHA-256 hash of the saved file after any server transformations.
// The server can but does not need to store this value.
["x", "543244319525d9d08dd69cb716a18158a249b7b3b3ec4bbde5435543acb34443"],
// Optional. Recommended for helping clients to easily know file type before downloading it.
["m", "image/png"]
// Optional. Recommended for helping clients to reserve an adequate UI space to show the file before downloading it.
["dim", "800x600"]
// ... other optional NIP-94 tags
]
 */
