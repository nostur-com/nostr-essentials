//
//  GiftWrapHelpers.swift
//  NostrEssentials
//
//  Created by Fabian Lachman on 27/11/2025.
//
// GIFTWRAP METADATA = RECEIVER
// SEAL METADATA = SENDER, NO RECEIVER
// RUMOR METADATA = ANY, SENDER, BUT NO SIGNATURE

import Foundation

// Create Rumor
//
// NIP-59:
// - A rumor is a regular nostr event, but is not signed. This means that if it is leaked, it cannot be verified.
// - A rumor is serialized to JSON, encrypted, and placed in the content field of a seal. The seal is then signed by the author of the note. The only information publicly available on a seal is who signed it, but not what was said.
// This function makes sure the event has an ID and removes the signature.
func createRumor(_ event: Event) -> Event {
    var rumor = event
    rumor.sig = ""
    return rumor.withId()
}

// Create a seal
//
// NIP-59: A seal is a kind:13 event that wraps a rumor with the sender's regular key. The seal is always encrypted to a receiver's pubkey but there is no p tag pointing to the receiver. There is no way to know who the rumor is for without the receiver's or the sender's private key. The only public information in this event is who is signing it.

func createSignedSeal(_ rumor: Event, ourKeys: Keys, receiverPubkey: String) -> Event? {
    // make sure inner rumor event has id and no sig
    var actualRumor = createRumor(rumor)
    guard let rumorJson = actualRumor.json() else { return nil }
    
    // encrypt rumor
    guard let encrypedRumor = Keys.encryptDirectMessageContent44(withPrivatekey: ourKeys.privateKeyHex, pubkey: receiverPubkey, content: rumorJson) else { return nil }
    
    // seal the rumor
    var seal = Event(
        pubkey: ourKeys.publicKeyHex,
        content: encrypedRumor, // MUST BE rumor UNSIGNED
        kind: 13,
        created_at: nip59CreatedAt(),
        tags: [] // TAGS MUST BE EMPTY
    )
    
    // return the seal signed
    return try? seal.sign(ourKeys)
}


// Create a fuzzy timestamp in the past
// NIP-59: The canonical created_at time belongs to the rumor. All other timestamps SHOULD be tweaked to thwart time-analysis attacks. Note that some relays don't serve events dated in the future, so all timestamps SHOULD be in the past.

func nip59CreatedAt() -> Int {
    let now = Int(Date().timeIntervalSince1970)
    let tenHoursAgo = now - 10 * 60 * 60  // 10 hours in seconds
    
    // Generate random timestamp between tenHoursAgo and now (inclusive)
    let randomTimestamp = Int.random(in: tenHoursAgo...now)
    
    return randomTimestamp
}
