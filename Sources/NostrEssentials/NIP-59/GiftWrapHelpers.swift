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
public func createRumor(_ event: Event) -> Event {
    var rumor = event
    rumor.sig = ""
    return rumor.withId()
}

// Create a seal
//
// NIP-59: A seal is a kind:13 event that wraps a rumor with the sender's regular key. The seal is always encrypted to a receiver's pubkey but there is no p tag pointing to the receiver. There is no way to know who the rumor is for without the receiver's or the sender's private key. The only public information in this event is who is signing it.
public func createSignedSeal(_ rumor: Event, ourKeys: Keys, receiverPubkey: String) throws -> Event {
    // make sure inner rumor event has id and no sig
    let actualRumor = createRumor(rumor)
    guard let rumorJson = actualRumor.json() else { throw GiftWrapError.EncodeRumorError }
    
    // encrypt rumor
    guard let encrypedRumor = Keys.encryptDirectMessageContent44(withPrivatekey: ourKeys.privateKeyHex, pubkey: receiverPubkey, content: rumorJson) else { throw GiftWrapError.EncryptRumorError }
    
    // seal the rumor
    var seal = Event(
        pubkey: ourKeys.publicKeyHex,
        content: encrypedRumor, // MUST BE rumor UNSIGNED
        kind: 13,
        created_at: nip59CreatedAt(),
        tags: [] // TAGS MUST BE EMPTY
    )
    
    // return the seal signed
    return try seal.sign(ourKeys)
}


public enum GiftWrapError: Error {
    
    // Recieving/Unwrapping
    
    case NotKind1059Event
    case WrongRecipient
    
    case DecryptSealError
    case DecodeSealError
    case InvalidSealError
    
    case DecryptRumorError
    case DecodeRumorError
    case InvalidRumorError
    case PossibleImpersonationError
    
    
    // Sending/Wrapping
    
    case OneOffKeyGenerationError
    case SignSealError
    case EncodeSealError
    case EncryptSealError

    case EncodeRumorError
    case EncryptRumorError
}

// Create a Gift Wrap
// NIP-59: A gift wrap event is a kind:1059 event that wraps a seal (kind: 13), which in turn wraps a rumor (any kind). tags SHOULD include any information needed to route the event to its intended recipient, including the recipient's p tag or NIP-13 proof of work.
public func createGiftWrap(_ rumor: Event, receiverPubkey: String, keys: Keys) throws -> Event {
    // One-time use key
    guard let oneTimeUseKeys = try? Keys.newKeys() else { throw GiftWrapError.OneOffKeyGenerationError }
    
    guard let seal = try? createSignedSeal(rumor, ourKeys: keys, receiverPubkey: receiverPubkey) else { throw GiftWrapError.SignSealError }
    guard let sealJson = seal.json() else { throw GiftWrapError.EncodeSealError }
    
    // encrypt seal
    guard let sealJsonEncrypted = Keys.encryptDirectMessageContent44(withPrivatekey: oneTimeUseKeys.privateKeyHex, pubkey: receiverPubkey, content: sealJson) else { throw GiftWrapError.EncryptSealError }
    
    // wrap the event
    var giftWrap = Event(
        pubkey: oneTimeUseKeys.publicKeyHex,
        content: sealJsonEncrypted,
        kind: 1059,
        created_at: nip59CreatedAt(),
        tags: [
            Tag(["p", receiverPubkey]) // The receiver
        ]
    )
    
    // return the Gift Wrap signed
    return try giftWrap.sign(oneTimeUseKeys)
}

// Create a fuzzy timestamp in the past
// NIP-59: The canonical created_at time belongs to the rumor. All other timestamps SHOULD be tweaked to thwart time-analysis attacks. Note that some relays don't serve events dated in the future, so all timestamps SHOULD be in the past.

public func nip59CreatedAt() -> Int {
    let now = Int(Date().timeIntervalSince1970)
    let tenHoursAgo = now - 10 * 60 * 60  // 10 hours in seconds
    
    // Generate random timestamp between tenHoursAgo and now (inclusive)
    let randomTimestamp = Int.random(in: tenHoursAgo...now)
    
    return randomTimestamp
}


public func unwrapGift(_ giftWrapEvent: Event, ourKeys: Keys) throws -> (rumor: Event, seal: Event) {
    guard giftWrapEvent.kind == 1059 else { throw GiftWrapError.NotKind1059Event }
    guard giftWrapEvent.tags.contains(where: { $0.type == "p" && $0.pubkey == ourKeys.publicKeyHex }) else { throw GiftWrapError.WrongRecipient }
    
    // Decrypt seal
    guard let sealJsonDecrypted = Keys.decryptDirectMessageContent44(withPrivateKey: ourKeys.privateKeyHex, pubkey: giftWrapEvent.pubkey, content: giftWrapEvent.content)
    else { throw GiftWrapError.DecryptSealError }
    
    guard let seal = Event.fromJson(sealJsonDecrypted) else {
        throw GiftWrapError.DecodeSealError
    }
    
    // NIP-59: Tags MUST always be empty in a kind:13. The inner event MUST always be unsigned.
    guard seal.tags.isEmpty, seal.kind == 13 else { throw GiftWrapError.InvalidSealError }
    
    // Decrypt rumor
    guard let rumJsonDecrypted = Keys.decryptDirectMessageContent44(withPrivateKey: ourKeys.privateKeyHex, pubkey: seal.pubkey, content: seal.content)
    else { throw GiftWrapError.DecryptRumorError }
    
    guard let rumor = Event.fromJson(rumJsonDecrypted) else {
        throw GiftWrapError.DecodeRumorError
    }
        
    return (rumor: rumor, seal: seal)
}
