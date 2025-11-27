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

