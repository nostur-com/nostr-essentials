# NostrEssentials

This package provides the essentials for building a nostr client.

As of August 15th 2023, this project has just started, it will eventually:
- Contain cleaned up, rewritten code from lessons learned while building Nostur (https://github.com/nostur-com/nostur-ios-public)
- Make it easy to use for others in their nostr projects

## Current features

- Generate nostr keys
```swift
import NostrEssentials

guard let keys = try? Keys.newKeys() else { return }
keys.privateKeyHex() // private key as a hex string
keys.publicKeyHex() // public key as a hex string
```
- Generate nostr events
```swift
import NostrEssentials

let event = Event(
    pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e", 
    content: "I’ve been working on a nostr client and will be opening it up for public beta soon at nostur.com", 
    kind: 1, 
    created_at: 1676784320, 
    id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7", 
    tags: [], 
    sig: "207b6d3eba8f4bc0ddf70bf98795f338b0a5ee04fecb86e83ed529647f4cbb2a892fc7fe7323dd5824790de77ffb959e0d10431d115dbd4dd70d040940e1543a")
    
event.json() // <json string of the event> or nil
```
- Generate client relay messages (REQ, EVENT, CLOSE)
```swift
import NostrEssentials

// REQ (with a kinds/limit filter)
let filter = Filters(kinds: [1], limit: 10)
let requestMessage = ClientMessage(type: .REQ, subscriptionId: "example", filters: [filter])
requestMessage.json() // ["REQ","example",{"kinds":[1],"limit":10}] or nil

// REQ (with a #p filter)
let pFilter = Filters(tagFilter: TagFilter(tag: "p", values: ["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]))
let requestMessage = ClientMessage(type: .REQ, subscriptionId: "example2", filters: [pFilter])
requestMessage.json() // ["REQ","example2",{"#p":["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33"]}] or nil


// EVENT (for publishing an event)
let event = Event(...) // see event code above
let eventMessage = ClientMessage(type: .EVENT, event: event)
eventMessage.json() // ["EVENT", <event json string here>] or nil
 
// CLOSE (to close a subscription)
let closeMessage = ClientMessage(type: .CLOSE, subscriptionId: "subId-1")
closeMessage.json() // ["CLOSE","subId-1"] or nil
```

See /Tests/NostrEssentialsTests for more examples
