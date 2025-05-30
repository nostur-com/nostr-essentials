# NostrEssentials

This package provides the essentials for building a nostr client.

As of August 15th 2023, this project has just started, it will eventually:
- Contain cleaned up, rewritten code from lessons learned while building Nostur (https://github.com/nostur-com/nostur-ios-public)
- Make it easy to use for others in their nostr projects

## Features
- Generate and convert nostr keys
- Generate nostr events
- Sign nostr events
- Generate client relay messages (REQ, EVENT, CLOSE) 
- Encode/Decode Shareable Identifiers (NIP-19)
- Encrypt/Decrypt messages (NIP-04)
- Encrypt/Decrypt messages (NIP-44)
- Common nostr related regexes 
- Content Parsing
- Media uploading to NIP-96 compatible servers (NIP-96)
- Media uploading using Blossom: (PUT /media and PUT /mirror)
- HTTP Auth (NIP-98)
- Connecting to relays, sending/receiving
- Parse relay messages
- Lookup nostr address (NIP-05)

## Install in Xcode
- Open your project or create a new project
- Add a new package to your Package Depencies
- Paste 'https://github.com/nostur-com/nostr-essentials' as Package URL and Add Package

## Usage

### Generating and converting nostr keys
```swift
import NostrEssentials

// Generate keys
guard let keys = try? Keys.newKeys() else { return }
keys.privateKeyHex // private key as a hex string
keys.publicKeyHex // public key as a hex string

// Or import private key
guard let keys = try? Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e") else { return }

// keys as npub/nsec bech32 format 
keys.nsec() // "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc"
keys.npub() // "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"


// Key conversion:

// public key hex to npub
Keys.npub(hex: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448") // "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"

// private key hex to nsec
Keys.nsec(hex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e") // "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc"

// npub to public key hex
guard let pubkey = Keys.hex(npub: "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7") 
else { print("invalid key"); return }
print(pubkey) // "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448"

// nsec to private key hex
guard let privkey = Keys.hex(nsec: "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc") 
else { print("invalid key"); return }
print(privkey) // "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e"

```
### Generate nostr events (NIP-01)
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

### Sign nostr events
```swift
import NostrEssentials

let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

var unsignedEvent = Event(
    pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
    content: "Hello World", kind: 1, created_at: 1676784320
)

let signedEvent = try unsignedEvent.sign(keys)

signedEvent.id // "f3eb5bc07a397bc275dd2ea3e5774a5cc308ec94856d04894d1328d414942dcc"
signedEvent.sig // <generated signature>
try signedEvent.verified() // true

// The .id above is computed during signing, to precompute before signing use:
let unsignedEventWithId = unsignedEvent.withId()
unsignedEventWithId.id // "f3eb5bc07a397bc275dd2ea3e5774a5cc308ec94856d04894d1328d414942dcc"

// If you are signing an event where the .pubkey does not match the given signing keys
// you can override the .pubkey using replaceAuthor:
let signedEvent = try unsignedEvent.sign(keys, replaceAuthor:true)
```

### Generate client relay messages (REQ, EVENT, CLOSE) (NIP-01)
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

### Shareable Identifiers (NIP-19) - Encoding
```swift
import NostrEssentials

// Encode naddr (a nostr parameterized replaceable event coordinate)
let naddr = try ShareableIdentifier(
    "naddr",
    kind: 30023,
    pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e",
    dTag: "nostur-mission"
)
        
naddr.identifier // "naddr1qq8xummnw36hyttdd9ehx6t0dcpzpxlqhc8xf5u29x5uajd9erh4mpeu90a9xc4yk4vd5hlkn0puhwq7qvzqqqr4guxh67ae"

// Encode nevent (a nostr event)
let nevent = try ShareableIdentifier(
    "nevent",
    id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7",
    kind: 1,
    pubkey: "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e",
    relays: ["wss://relayable.org", "wss://relay.damus.io", "wss://nos.lol", "wss://filter.nostr.wine"]
)
        
nevent.identifier // "nevent1qqs9ug9weddnm5c5nyqcmrc48hecah0z8faajhfakp7ajawhw26ya3czyzd7p0swvnfc52dfemy6tj80tkrnc2l62d32fd2cmf0ldx7rewupuqcyqqqqqqgpzdmhxue69uhhyetvv9ukzcnvv5hx7un8qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hszrthwden5te0dehhxtnvdakqz9mhwden5te0ve5kcar9wghxummnw3ezuamfdejsjauntt"

// Encode npub (a public key)
let npub = try ShareableIdentifier(
    "npub",
    pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448"
)

npub.identifier // "npub1r05fn49ng7d950l0t764hu7z6l664wlcrax383fr47nkq33v63yqg63cu7"

// Encode nsec (a private key)
let nsec = try ShareableIdentifier(
    "nsec",
    pubkey: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e"
)
nsec.identifier // "nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc"
    
// Encode note (an event identifier)
let note = try ShareableIdentifier(
    "note",
    id: "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"
)
note.identifier // "note1tcs2aj6m8hf3fxgp3k83200n3mw7ywnmm9wnmvram96awu45fmrshq2hcy"
```

### Shareable Identifiers (NIP-19) - Decoding
```swift
import NostrEssentials

// Decode naddr (a nostr parameterized replaceable event coordinate)
let naddr = try ShareableIdentifier("naddr1qq8xummnw36hyttdd9ehx6t0dcpzpxlqhc8xf5u29x5uajd9erh4mpeu90a9xc4yk4vd5hlkn0puhwq7qvzqqqr4guqs6amnwvaz7tmwdaejumr0dsmq008z")
        
naddr.pubkey //"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"        
naddr.dTag // "nostur-mission"
naddr.kind // 30023
naddr.relays // ["wss://nos.lol"]
naddr.aTag // "30023:9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e:nostur-mission"

// Decode nevent (a nostr event)
let nevent = try ShareableIdentifier("nevent1qqs9ug9weddnm5c5nyqcmrc48hecah0z8faajhfakp7ajawhw26ya3czyzd7p0swvnfc52dfemy6tj80tkrnc2l62d32fd2cmf0ldx7rewupuqcyqqqqqqgpzdmhxue69uhhyetvv9ukzcnvv5hx7un8qy28wumn8ghj7un9d3shjtnyv9kh2uewd9hszrthwden5te0dehhxtnvdakqz9mhwden5te0ve5kcar9wghxummnw3ezuamfdejsjauntt")
        
nevent.id // "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7")    
nevent.pubkey // "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e")
nevent.relays // ["wss://relayable.org", "wss://relay.damus.io", "wss://nos.lol", "wss://filter.nostr.wine"]
nevent.kind // 1

// Decode npub (a public key)
let npub = try ShareableIdentifier("npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe")
        
npub.pubkey // "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"

// Decode nsec (a private key)
let nsec = try ShareableIdentifier("nsec1vq5nxhd4fqje4wt7lf0ma6s0ug2fjqgxg735xm5rep8lp99qvu8qv0d7hc")
        
nsec.privkey // "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e"
    
// Decode note (an event identifier)
let note = try ShareableIdentifier("note1tcs2aj6m8hf3fxgp3k83200n3mw7ywnmm9wnmvram96awu45fmrshq2hcy")
note.id // "5e20aecb5b3dd31499018d8f153df38edde23a7bd95d3db07dd975d772b44ec7"
```

## Encrypt/Decrypt messages (NIP-04)
Note: NIP-04 will become obsolete. It is included here for backwards compatibility
```swift
import NostrEssentials

// setup keys
let aliceKeys = try Keys(privateKeyHex: "5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a")
let bobKeys = try Keys(privateKeyHex: "4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d")

let clearMessage = "hello" // the message to encrypt
        
// Encrypt a message
let encryptedMessage = Keys.encryptDirectMessageContent(withPrivatekey: aliceKeys.privateKeyHex, pubkey: bobKeys.publicKeyHex(), content: clearMessage)! // <cipher text>
                
// Decrypt a message
let decryptedMessage = Keys.decryptDirectMessageContent(withPrivateKey: bobKeys.privateKeyHex, pubkey: aliceKeys.publicKeyHex(), content: encryptedMessage) // "hello"
```

## Encrypt/Decrypt messages (NIP-44)
```swift
import NostrEssentials

// setup keys
let aliceKeys = try Keys(privateKeyHex: "5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a")
let bobKeys = try Keys(privateKeyHex: "4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d")

let clearMessage = "hello" // the message to encrypt
        
// Encrypt a message
let encryptedMessage = Keys.encryptDirectMessageContent44(withPrivatekey: aliceKeys.privateKeyHex, pubkey: bobKeys.publicKeyHex, content: clearMessage)! // <cipher text> 
                
// Decrypt a message
let decryptedMessage = Keys.decryptDirectMessageContent44(withPrivateKey: bobKeys.privateKeyHex, pubkey: aliceKeys.publicKeyHex, content: encryptedMessage) // "hello"
```

## Nostr regexes
```swift
import NostrEssentials

let r = NostrRegexes.default // create and cache NSRegularExpression instances ahead of time for reuse (performance)
        
let exampleContent = "Hello npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe! Is this your hex pubkey? 9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e?"

let matches = r.matchingStrings(exampleContent, regex: r.cache[.npub]!)
matches[0].first // "npub1n0sturny6w9zn2wwexju3m6asu7zh7jnv2jt2kx6tlmfhs7thq0qnflahe"

let matches2 = r.matchingStrings(exampleContent, regex: r.cache[.hexId]!)
matches2[0].first // "9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"
```

## Content Parsing
```swift
import NostrEssentials

let r = NostrRegexes.default
let parser = ContentParser()
        
// Define handlers to detect and replace 
parser.embedHandlers[r.cache[.nostrUri]!] = // <Your handler here>
parser.inlineHandlers[r.cache[.indexedTag]!] = // <Your handler here>
parser.inlineHandlers[r.cache[.npub]!] = // <Your handler here>
parser.dataSources["tags"] = // Your data source
parser.dataSources["names"] = // Your data source

// Example content
let exampleContent = "Hello #[0]! Did you create #[1]? Is this your profile? nostr:nprofile1qqsfhc97pejd8z3f488vnfwgaawcw0ptlffk9f94trd9la5mc09ms8spzemhxue69uhhyetvv9ujumn0wd68ytnzv9hxgpvhe4f\nDo you know npub1lrnvvs6z78s9yjqxxr38uyqkmn34lsaxznnqgd877j4z2qej3j5s09qnw5?"

let contentItems = try parser.parse(exampleContent)

contentItems // Array of ContentItem for use in views, example:

var body: some View {
    ForEach(elements) { element in
        switch element {
        case ContentItem.text(let text):
            Text(text)
        case ContentItem.nprofile1(let nprofile):
            Text(nprofile.identifier)
        default:
            Text("Unknown element")
        }   
    }
}
// See ContentParsingTests for a full working example, with example handlers and mock data sources

```

## HTTP Authentication (NIP-98)
```swift
import NostrEssentials

let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

// Sign a 27235 event with url and method in tags      
var unsignedEvent = Event(
    pubkey: "1be899d4b3479a5a3fef5fb55bf3c2d7f5aabbf81f4d13c523afa760462cd448",
    content: "",
    kind: 27235,
    tags: [
        Tag(["u", "https://some.server.address/auth"]),
        Tag(["method", "GET"])
    ]

guard let signedEvent = try? unsignedEvent.sign(keys) else { return }

// Convert to base64 and put it in the Authorization header, prefix with "Nostr "
guard let base64 = signedEvent.base64() else { return }
let authorization = "Nostr \(base64)"

var request = URLRequest(url: "https://some.server.address/auth")
request.setValue(authorization, forHTTPHeaderField: "Authorization")

// Continue other regular URLRequest stuff
```

## Media uploading (Blossom)
```swift
import NostrEssentials
import Combine

var subscriptions: Set<AnyCancellable> = []
let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png")
let imageData = try Data(contentsOf: filepath!)
let authHeader = try getBlossomAuthorizationHeader(keys, sha256hex: imageData.sha256().hexEncodedString())
let uploadItem = BlossomUploadItem(data: imageData, contentType: "image/png", authorizationHeader: authHeader)
let uploader = BlossomUploader(URL(string: "http://localhost:3000")!)
uploader.queued = [uploadItem]

uploader.uploadingPublisher(for: uploadItem)
    .sink(
        receiveCompletion: { _ in 
        }, 
        receiveValue: { mediaRequestBag in
            uploader.processResponse(uploadItem: uploadItem)
        }
    )
    .store(in: &subscriptions)

// Multiple simultaneous uploads, delete and mirroring is also supported, see Tests for examples.
```

## Media uploading (NIP-96)
```swift
import NostrEssentials
import Combine

var subscriptions: Set<AnyCancellable> = []
let keys = try Keys(privateKeyHex: "6029335db548259ab97efa5fbeea0fe21499010647a3436e83c84ff094a0670e")

let filepath = Bundle.module.url(forResource: "upload-test", withExtension: "png")
let imageData = try Data(contentsOf: filepath!)
let mediaRequestBag = MediaRequestBag(apiUrl: URL(string: "https://nip96.server.url.here")!, mediaData: imageData)

let uploader = Nip96Uploader()

uploader.uploadingPublisher(for: mediaRequestBag, keys: keys)
    .sink(
        receiveCompletion: { _ in 
        }, 
        receiveValue: { mediaRequestBag in
            uploader.processResponse(mediaRequestBag: mediaRequestBag)
            if (uploader.finished) {
                print("Uploaded image url is: \(mediaRequestBags.downloadUrl ?? "")")
            }
        }
    )
    .store(in: &subscriptions)

// Multiple simultaneous uploads is also supported, see Tests for examples.
```

## Connecting to relays, sending/receiving

```swift
import NostrEssentials

// Set up connection pool, myApp should implement RelayConnectionDelegate
let pool = ConnectionPool(delegate: myApp)

// Configure a relay to connect to
let myRelayConfig = RelayConfig(url: "wss://nos.lol/", read: true, write: true)

// Add the relay to the connection pool
let myRelayConnection = pool.addConnection(myFirstRelay)

// Connect to the relay
myRelayConnection.connect()

// create a nostr request
let lastMessageFromPubkey = ClientMessage(type: .REQ, filters: [Filters(authors: Set(["9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"]), limit: 1)])

 // send request to the pool (which sends it to all "read" relays)
pool.sendMessage(lastMessageFromPubkey) // .connect() might not be completed here yet, but message will be queued and sent after connect.

// Receiving the response should be handled in myApp (RelayConnectionDelegate)
// See Tests/NostrEssentialsTests for a full working example.

```

## Parse relay messages

```swift
import NostrEssentials

// Example response as returned in RelayConnectionDelegate.didReceiveMessage(_ url: String, message: String) { }
let message = ###"["EVENT","SUBID-1",{"pubkey":"9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e","content":"Just ignore labels outside WoT and increase significance of labels from direct follows.","id":"c948ad1d37abfafd887d74194f5649cce3c94711aa5eeed7e8a4ee5e4fd1dbe1","created_at":1700163275,"sig":"ed93a1dcba18e47bb9b0ed2fa98316db6cde787f51aa13ba8f08fd2f8c0775749122042bc3c6242c203e1840b1948f3b590d56fe3668cf2807ef556bdf29285e","kind":1,"tags":[["e","9e0f6c6e2a257a4b1a888dbadc150fa219ca269447f0da0d14081493f2005dc2","","root"],["e","31a21327b74818221f1b79d09e0e4552eeeb954be4e818cb9e0283524cf92f30","","reply"],["p","8a981f1ae3fab3300b548c4f20654cb0f1d350498c4b66849b73e8546001dca0"],["p","9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e"],["client","Nostur"]]}]"###
let url = "wss://nos.lol" // relay url the response came from

if let parsedEvent = try? parseRelayMessage(text: message, relay: url),
    let event = parsedEvent.event,
    let subId = parsedEvent.subscriptionId {
    print(subId) // "SUBID-1"
    print(event.id) // "c948ad1d37abfafd887d74194f5649cce3c94711aa5eeed7e8a4ee5e4fd1dbe1"
}
```

## Look up nostr address (NIP-05)

```swift
import NostrEssentials

let pubkey = try await lookupNip05("fabian@nostur.com")
print(pubkey) // 9be0be0e64d38a29a9cec9a5c8ef5d873c2bfa5362a4b558da5ff69bc3cbb81e
```

See /Tests/NostrEssentialsTests for more examples
