//
//  File.swift
//  
//
//  Created by Fabian Lachman on 05/01/2024.
//

import XCTest
@testable import NostrEssentials

final class OutboxTests: XCTestCase {

    func testKind10002s() throws {
        let ourRelays: Set<String> = ["wss://relay.damus.io", "wss://nos.lol", "wss://nostr.wine"]
        let kind10002s = KIND10002NOTES.compactMap { Event.fromJson($0) }
        let pubkeys = Set(kind10002s.map { $0.pubkey })

        let preferredRelays: PreferredRelays = pubkeysByRelay(kind10002s, ignoringRelays: SPECIAL_PURPOSE_RELAYS)
        
        let plan: RequestPlan = createRequestPlan(pubkeys: pubkeys, reqFilters: [Filters(kinds: [1])], ourReadRelays: ourRelays, preferredRelays: preferredRelays)
        
    
        for req in plan.findEventsRequests
            .filter({ (relay: String, findEventsRequest: FindEventsRequest) in
                // Only requests that have .authors > 0
                // Requests can have multiple filters, we can count the authors on just the first one, all others should be the same (for THIS relay)
                findEventsRequest.pubkeys.count > 0
                
            })
            .sorted(by: {
                $0.value.pubkeys.count > $1.value.pubkeys.count
            }) {
            print("\(req.value.pubkeys.count): \(req.key) - \(req.value.filters.description)")
        }
            
        XCTAssertEqual(kind10002s.count, 72)
        XCTAssertEqual(pubkeys.count, 72)
        
        
        XCTAssertEqual(plan.findEventsRequests.count, 11)
    }
    
    // Same as testConnection() in RelayConnectionTests, but now using the Outbox model
    // Should read from relays where the pubkeys we are following are writing to
    func testOutboxModelReading() throws {
        // This test configures a ConnectionPool instance
        // It sets it up with an example delegate MyTestApp which handles the relay responses, in this case to pass the tests
        
        let expectation = self.expectation(description: "testOutboxModelReading")
        
        // Implement RelayConnectionDelegate somewhere in your app to handle responses from relays
        // This is an example app that just logs to console and changes some test vars on connect/receive:
        class MyTestApp: RelayConnectionDelegate {
            
            // These are test case related:
            
            private var expectation: XCTestExpectation
            public var testDidConnect = false
            public var testDidReceiveMessage = false {
                didSet {
                    if oldValue != testDidReceiveMessage {
                        expectation.fulfill()
                    }
                }
            }
            
            init(_ expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            
            // These are the delegate methods you need to implement in your app:
            
            func didConnect(_ url: String) {
                print("connected to: \(url)")
                self.testDidConnect = true
            }
            
            func didDisconnect(_ url: String) {
                print("disconnected from: \(url)")
            }
            
            func didReceiveMessage(_ url: String, message: String) {
                print("message received from \(url): \(message)")
                self.testDidReceiveMessage = true
            }
            
            func didDisconnectWithError(_ url: String, error: Error) {
                print("disconnected from: \(url), with error: \(error.localizedDescription)")
            }
        }
        
        // Instantiate example app
        let myApp = MyTestApp(expectation)
        
        // Define our relays, these are what we normally use without the outbox model
        let ownRelaySet = [
            RelayConfig(url: "wss://nos.lol", read: true, write: true),
            RelayConfig(url: "wss://relay.damus.io", read: true, write: true),
//            RelayConfig(url: "wss://nostr.wine", read: true, write: true)
        ]
        
        // Set up the connection pool
        let pool = ConnectionPool(delegate: myApp)
        
        
        // Add our own relay set to the connection pool
        for relay in ownRelaySet {
            let connection = pool.addConnection(relay)
            
            // Connect to each relay
            connection.connect()
        }
        
        // The pool needs to know which pubkeys can be found in which relays
        // These are published in kind:10002 events, we add them here
        pool.setPreferredRelays(using: KIND10002NOTES.compactMap { Event.fromJson($0) }, maxPreferredRelays: 50) // set a limit to prevent abuse
        
        // Connect to all preferred relays for finding events
        for (key: _, value: findEventsConnection) in pool.findEventsConnections {
            findEventsConnection.connect()
        }
        
        // create a nostr request (find kind:1 posts from 4 pubkeys)
        let followingPubkeys: Set<String> = ["c37b6a82a98de368c104bbc6da365571ec5a263b07057d0a3977b4c05afa7e63",
                                             "3d842afecd5e293f28b6627933704a3fb8ce153aa91d790ab11f6a752d44a42d",
                                             "79c2cae114ea28a981e7559b4fe7854a473521a8d22a66bbab9fa248eb820ff6",
                                             "d49a9023a21dba1b3c8306ca369bf3243d8b44b8f0b6d1196607f7b0990fa8df"]
        
        let postsOfFollows = ClientMessage(type: .REQ, subscriptionId: "FOLLOWING", filters: [Filters(authors: followingPubkeys, kinds: [1])])
        
        // send request to the pool, the pool will figure out using the Outbox model which relays to use for which pubkeys.
        // in addition to using our own relay set, the pool will try to use an additional relay that is not in our relay set for each pubkey
        pool.sendMessage(postsOfFollows)
        
        waitForExpectations(timeout: 10)
        XCTAssertEqual(myApp.testDidConnect, true)
        XCTAssertEqual(myApp.testDidReceiveMessage, true)
    }

    // Should write to the read-relays of the pubkeys we are replying to
    // (Note: New (root) posts should just use own relay set / blastr). But replying or posts with p-tags should write to the read relays of p's)
    func testOutboxModelWriting() throws {
        // This test configures a ConnectionPool instance
        // It sets it up with an example delegate MyTestApp which handles the relay responses, in this case to pass the tests
        
        let expectation = self.expectation(description: "testOutboxModelWriting")
        
        // Implement RelayConnectionDelegate somewhere in your app to handle responses from relays
        // This is an example app that just logs to console and changes some test vars on connect/receive:
        class MyTestApp: RelayConnectionDelegate {
            
            // These are test case related:
            
            private var expectation: XCTestExpectation
            public var testDidConnect = false
            public var testDidReceiveMessage = false {
                didSet {
                    if oldValue != testDidReceiveMessage {
                        expectation.fulfill()
                    }
                }
            }
            
            init(_ expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            
            // These are the delegate methods you need to implement in your app:
            
            func didConnect(_ url: String) {
                print("connected to: \(url)")
                self.testDidConnect = true
            }
            
            func didDisconnect(_ url: String) {
                print("disconnected from: \(url)")
            }
            
            func didReceiveMessage(_ url: String, message: String) {
                print("message received from \(url): \(message)")
                self.testDidReceiveMessage = true
            }
            
            func didDisconnectWithError(_ url: String, error: Error) {
                print("disconnected from: \(url), with error: \(error.localizedDescription)")
            }
        }
        
        // Instantiate example app
        let myApp = MyTestApp(expectation)
        
        // Define our relays, these are what we normally use without the outbox model
        let ownRelaySet = [
            RelayConfig(url: "wss://nos.lol", read: true, write: true),
            RelayConfig(url: "wss://relay.damus.io", read: true, write: true),
//            RelayConfig(url: "wss://nostr.wine", read: true, write: true)
        ]
        
        // Set up the connection pool
        let pool = ConnectionPool(delegate: myApp)
        
        
        // Add our own relay set to the connection pool
        for relay in ownRelaySet {
            let connection = pool.addConnection(relay)
            
            // Connect to each relay
            connection.connect()
        }
        
        // The pool needs to know which pubkeys can be found in which relays
        // These are published in kind:10002 events, we add them here
        pool.setPreferredRelays(using: KIND10002NOTES.compactMap { Event.fromJson($0) }, maxPreferredRelays: 50) // set a limit to prevent abuse
        
        // Connect to all preferred relays for finding events
        for (key: _, value: findEventsConnection) in pool.findEventsConnections {
            findEventsConnection.connect()
        }
        
        // create a nostr request (find kind:1 posts from 4 pubkeys)
        let followingPubkeys: Set<String> = ["c37b6a82a98de368c104bbc6da365571ec5a263b07057d0a3977b4c05afa7e63",
                                             "3d842afecd5e293f28b6627933704a3fb8ce153aa91d790ab11f6a752d44a42d",
                                             "79c2cae114ea28a981e7559b4fe7854a473521a8d22a66bbab9fa248eb820ff6",
                                             "d49a9023a21dba1b3c8306ca369bf3243d8b44b8f0b6d1196607f7b0990fa8df"]
        
        let postsOfFollows = ClientMessage(type: .REQ, subscriptionId: "FOLLOWING", filters: [Filters(authors: followingPubkeys, kinds: [1])])
        
        // send request to the pool, the pool will figure out using the Outbox model which relays to use for which pubkeys.
        // in addition to using our own relay set, the pool will try to use an additional relay that is not in our relay set for each pubkey
        pool.sendMessage(postsOfFollows)
        
        waitForExpectations(timeout: 10)
        XCTAssertEqual(myApp.testDidConnect, true)
        XCTAssertEqual(myApp.testDidReceiveMessage, true)
    }
}

let KIND10002NOTES: [String] = [
    ###"{"id":"ed312cbd4d24567770120e964b15226332adafd6ea3c9c535d5445f3bf190487","pubkey":"b17c59874dc05d7f6ec975bce04770c8b7fa9d37f3ad0096fdb76c9385d68928","created_at":1704449334,"kind":10002,"tags":[["r","wss://nostr.mom"],["r","wss://nos.lol"],["r","wss://relay.taxi"],["r","wss://free.nostr.lc"],["r","wss://relay.damus.io"],["r","wss://relay.nostr.bg"],["r","wss://relay.current.fyi"],["r","wss://relay.nostr.band","read"],["r","wss://search.nos.today","read"],["r","wss://nostr21.com"],["r","wss://relay.nostrgraph.net"],["r","wss://relayable.org"],["r","wss://nostr.semisol.dev","read"],["r","wss://relay.mostr.pub"],["r","wss://nostr.bostonbtc.com"],["r","wss://nostr.mutinywallet.com"],["r","wss://offchain.pub"],["r","wss://nostr.w3ird.tech"],["r","wss://rsslay.nostr.moe","read"],["r","wss://relay.snort.social","read"],["r","wss://purplepag.es","read"],["r","wss://relay.plebstr.com"],["r","wss://e.nos.lol"],["r","wss://nostrue.com"],["r","wss://nostr1.current.fyi"],["r","wss://relay.shitforce.one"],["r","wss://nostr.coinfundit.com"],["r","wss://bostr.yonle.lecturify.net"],["r","wss://relay.nos.social","read"],["r","wss://feeds.nostr.band/popular","read"],["r","wss://agora.nostr1.com"],["r","wss://relay.primal.net"],["r","wss://nostr.oxtr.dev"],["r","wss://pyramid.fiatjaf.com","read"],["r","wss://relay.noswhere.com"],["r","wss://strfry.chatbett.de"],["r","wss://relay.roadrunner.lat"],["r","wss://annal.purplerelay.com"],["r","wss://nostr-relay.app"],["r","wss://rnostr.onrender.com"]],"content":"","sig":"d13969a447c212503a8a0c9786ad9582f9bcb1d392bab34e5c939c8f47efe9baf17f4d9114492b63769d499938f809146547b3d8be57b6f58316de140d3e0992"}"###,
    ###"{"id":"188b6a7d762c3e5fd05fb5abe1f606131a7b815f4a89fcbd9f5eaf1de5a87c14","pubkey":"fa984bd7dbb282f07e16e7ae87b26a2a7b9b90b7246a44771f0cf5ae58018f52","created_at":1704240917,"kind":10002,"tags":[["r","wss://140.f7z.io/"],["r","wss://nos.lol/"],["r","wss://offchain.pub/","read"],["r","wss://purplepag.es/"],["r","wss://pyramid.fiatjaf.com/"],["r","wss://relay.damus.io/"],["r","wss://relay.f7z.io/","write"],["r","wss://relay.nostr.band/"],["r","wss://relay.primal.net/"],["r","wss://relay.sovereignengineering.io/","read"]],"content":"","sig":"59bf77b7ed1852349d026965c588f5e48fd404bc12f7307ae2e03d0c96e6b9ba031021ef9abe7b2fc8253267d839bc4480a143f07ac653bcec23fc19e286e888"}"###,
    ###"{"id":"9f7295f64653094aa4c88ed8752582e0db02052295e9311eaf0ace6997fd5497","pubkey":"ee6ea13ab9fe5c4a68eaf9b1a34fe014a66b40117c50ee2a614f4cda959b6e74","created_at":1704126846,"kind":10002,"tags":[["r","wss://nostr.wine/"],["r","wss://relay.nostr.com.au/"],["r","wss://paid.spore.ws/"],["r","wss://nostr.plebchain.org/"],["r","wss://relay.orangepill.dev/"],["r","wss://nostr.inosta.cc/"],["r","wss://relay.damus.io/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://relay.nostrati.com/"],["r","wss://lightningrelay.com/"],["r","wss://relay.current.fyi/"],["r","wss://eden.nostr.land/"],["r","wss://140.f7z.io/"],["r","wss://nostr.bitcoiner.social/"]],"content":"","sig":"f2317535fe289fea0c65f5528037eebdd3f24bdeef592fbb360aab2a73cb38838de2bf22043c6e94d167e975dd8beab495cd13782d0f60663841bbdce7c8dea3"}"###,
    ###"{"id":"79cc33eba2d9777de302755ceb577b15a7f8796a8ab03fcfa2711933a36aed7f","pubkey":"7fa56f5d6962ab1e3cd424e758c3002b8665f7b0d8dcee9fe9e288d7751ac194","created_at":1704111616,"kind":10002,"tags":[["r","wss://filter.nostr.wine"],["r","wss://nos.lol"],["r","wss://verbiricha.nostr1.com","write"],["r","wss://frens.nostr1.com"]],"content":"","sig":"3edd1a1b7cb1db376a2109d220459522ef437477d9048f67a04be7805038e12e9e5357e796029d605bb11680763b4400bcad5e4ad6b15ef1d2c7a8eb20c8e71f"}"###,
    ###"{"id":"d99fe57f13fe6c2e6d69d8227e0a9c3512ac3d64fe89525b1781e7f0ca9d425f","pubkey":"c37b6a82a98de368c104bbc6da365571ec5a263b07057d0a3977b4c05afa7e63","created_at":1704089990,"kind":10002,"tags":[["r","wss://nos.lol/","write"],["r","wss://relay.snort.social/","write"],["r","wss://relay.current.fyi/","write"]],"content":"","sig":"fc250a9bc4fe8d21886b53e0586f72dfebed0e817f5ffd39a4228f17961db9faa3ba430564d75c4430aca923f4df85868fb18119de5317e6afad59a0b04d3b2a"}"###,
    ###"{"id":"eff1c24583081c56ed00ca27853a17882b18c92bebe262afa06603b233915dd7","pubkey":"63fe6318dc58583cfe16810f86dd09e18bfd76aabc24a0081ce2856f330504ed","created_at":1704030512,"kind":10002,"tags":[["r","wss://pyramid.fiatjaf.com/"],["r","wss://nos.lol/","read"],["r","wss://relay.snort.social/"],["r","wss://nostr.wine/"],["r","wss://mnl.v0l.io/","read"],["r","wss://r.v0l.io/","read"],["r","wss://relay.nostr.band/","read"]],"content":"","sig":"0b8e5156e276ceb2507e70bb5ee09fd67ee883a6735972712a110c6763f5588d8510cf1d4cf0f5b0a19debbd0b426a42c03485fe76de11c96bd928cb0b708a9e"}"###,
    ###"{"id":"51773dadf1415eab15e9f5d56668b758463036daff156f02b5d77e04195ff72e","pubkey":"3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d","created_at":1704028412,"kind":10002,"tags":[["r","wss://pyramid.fiatjaf.com/"],["r","wss://nostr.mom/","read"],["r","wss://nostr.wine/","read"],["r","wss://relay.nostrati.com/","read"],["r","wss://atlas.nostr.land/","read"],["r","wss://relay.snort.social/","read"]],"content":"","sig":"63f19bed47f2c80d257362a54779bedfe5639bffe2b93b554cf08781ba193191d0f2befafc36792ca871a4563258066548f080eee4175f1c5110eb6cddb2a22d"}"###,
    ###"{"id":"c2e3b3dfb33b1a58467d35e83c20eb0c479f76ff64eeed63719f55b0793581c3","pubkey":"3d842afecd5e293f28b6627933704a3fb8ce153aa91d790ab11f6a752d44a42d","created_at":1703998536,"kind":10002,"tags":[["r","wss://creatr.nostr.wine"],["r","wss://inbox.nostr.wine","read"],["r","wss://cellar.nostr.wine","write"],["r","wss://nostr.wine"]],"content":"","sig":"b868e809c8a1628742b8b0029feb79f1b62a337dd204512a30608d4f452b205c4076d3591fff06cfd45d319894fddccb093021c044a33c8e14d818a1e91e95cb"}"###,
    ###"{"id":"8c4fa1578cf41a1c93391dda9bb44733dd4da35061f45f985c523813e724e355","pubkey":"3f770d65d3a764a9c5cb503ae123e62ec7598ad035d836e2a810f3877a745b24","created_at":1703799443,"kind":10002,"tags":[["r","wss://nostr.wine/"],["r","wss://nos.lol/"],["r","wss://relay.nostr.band/","read"],["r","wss://relay.damus.io/"],["r","wss://purplerelay.com/"],["r","wss://relay.nostrplebs.com/"],["r","wss://relayable.org/"],["r","wss://nostr-relay.derekross.me/"],["r","wss://purplepag.es/","read"],["r","wss://relay.noswhere.com/","read"],["r","wss://relay.snort.social/"],["r","wss://rsslay.nostr.moe/","read"],["r","wss://welcome.nostr.wine/","read"],["r","wss://nostr.orangepill.dev/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://offchain.pub/"]],"content":"","sig":"f71cc377cbd32c7b9d308f064a2653f4dc626074fbe86919b5bbcf423616859062ec6e89c84aa321fdab64a8c9263a82ebd849f4deb433e6c83aaf330360c908"}"###,
    ###"{"id":"34349df6083fad44df08693f362a14e3422e2a9ebd976e19dc042fd697cbf42e","pubkey":"79c2cae114ea28a981e7559b4fe7854a473521a8d22a66bbab9fa248eb820ff6","created_at":1703784896,"kind":10002,"tags":[["r","wss://relay.mostr.pub"],["r","wss://relay.shitforce.one"],["r","wss://nostr.wine"],["proxy","https://gleasonator.com/users/alex","activitypub"]],"content":"","sig":"bb4b33a70bd7b9f445b5532799dafd73c0cabc515412387922a57c7446678e74b685cdd6ef330ea37b063ab8422c8cadaca787e48d119151f3d93f3571672510"}"###,
    ###"{"id":"2c3d99aeaca0d7ef514725c5781444580801582cd0093e10253ca33d59d56530","pubkey":"604e96e099936a104883958b040b47672e0f048c98ac793f37ffe4c720279eb2","created_at":1703175814,"kind":10002,"tags":[["r","wss://nostr.wine/"],["r","wss://relay.nostr.band/"],["r","wss://purplepag.es/"],["r","wss://relay.snort.social/"],["r","wss://nostr.mutinywallet.com/","write"],["r","wss://relay.damus.io/"],["r","wss://nos.lol/"]],"content":"","sig":"40ce179fa73b8ad190bb4f4e4454c7aeecab7a5eca7a264c9506c393f5aae052c72bef5b53fabc4d305439bdbe8039b638a771aac75646c23bba46817c731034"}"###,
    ###"{"id":"b892cf2a4773bee2ff677341b0c4911b0da47841801fe0ba42f2497b036bd830","pubkey":"aa746c026c3b37de2c9a721fbf8e110235ffbb35f99620002d9ff60edebe9986","created_at":1703109269,"kind":10002,"tags":[["r","wss://nostr.bitcoiner.social"],["r","wss://relay.damus.io"],["r","wss://relay.nostr.band"]],"content":"","sig":"99f54b7c3f403025bf4ad341a99c82dd74b5da85ec9bf67a8352072c3f6c424d10cdb5bbe0195d278cce1bbcbb92ecebf159f43dbcc67889dbac0fcf7b1c722e"}"###,
    ###"{"id":"0850497b5a1858f892ab22c472bafca867d133c6eb47ba8cc03723b30983244e","pubkey":"97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322","created_at":1703002220,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://relayable.org/"],["r","wss://purplepag.es/","read"],["r","wss://christpill.nostr1.com/","read"],["r","wss://offchain.pub/"],["r","wss://relay.snort.social/","read"],["r","wss://relay.mostr.pub/","read"],["r","wss://bucket.coracle.social/"],["r","wss://nos.lol/"],["r","wss://a.nos.lol/"],["r","wss://hodlbod.nostr1.com/"]],"content":"","sig":"df35720bb1923e692a3d727e9017405d6f2b324909bbcb0913764492f96c532d2fdeec56670c3b75999233671ad4947cc87acf89fe573aa91a0df5727e801b3f"}"###,
    ###"{"id":"f7d0423ba8843eb0b52c35f554f98dd4e8d9d6839ac1958ee05f4002834ee712","pubkey":"1bc70a0148b3f316da33fe3c89f23e3e71ac4ff998027ec712b905cd24f6a411","created_at":1702960184,"kind":10002,"tags":[["r","wss://eden.nostr.land/"],["r","wss://nos.lol/"],["r","wss://nostr.wine/"],["r","wss://relay.damus.io/"],["r","wss://relay.mostr.pub/"],["r","wss://relay.nostr.band/"],["r","wss://relay.primal.net/"],["r","wss://relay.snort.social/"]],"content":"","sig":"90807af43d56be33da4ec9684872bcbd027c4b986b12c3d55c96b99fed6d25c28c93e72ca74f15ca9b9019ca0eb76aeff083ba59d3b30eb93a169e94c6e4e23d"}"###,
    ###"{"id":"0ff302ea6175db2b13838421258da1cb6cfd48cd9375ffd557e406135a050f87","pubkey":"4523be58d395b1b196a9b8c82b038b6895cb02b683d0c253a955068dba1facd0","created_at":1702833960,"kind":10002,"tags":[["r","wss://nostr.wine/","read"],["r","wss://eden.nostr.land/","read"],["r","wss://relay.damus.io/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://nos.lol/"],["r","wss://soloco.nl/"],["r","wss://offchain.pub/"]],"content":"","sig":"e71632e0ae033969ae63b71283533c604273478e13d44af398a8822f15c79338cc54ccb4ff8b8b63083ae91988920edca7a435e3d6f4a30d4c471cb64994289f"}"###,
    ###"{"id":"ef17bd9510f6a4d37c3d94434ac98e4f807f2edaabf27bc973c32e724dd62e58","pubkey":"32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245","created_at":1702499070,"kind":10002,"tags":[["r","ws://monad.jb55.com:8080"],["r","wss://nostr.wine"],["r","wss://relay.mostr.pub"],["r","wss://welcome.nostr.wine/"],["r","wss://nos.lol"],["r","wss://eden.nostr.land"],["r","wss://relay.damus.io"],["r","wss://nostr.fmt.wiz.biz"],["r","wss://relay.nostr.band"]],"content":"","sig":"3e740c0755323a7ec61acfe5353140c274484887d6ce2f7e670aee319ca5e59d4dc3a875282d2a51a2da19e78e52effa73cba09317e0b145b37d20aebd6fbeba"}"###,
    ###"{"id":"19c65e12cbcfeef659c4cea7ba3e65b1cc94cf7b1ab5c9a60608705e0edf0877","pubkey":"52b4a076bcbbbdc3a1aefa3735816cf74993b1b8db202b01c883c58be7fad8bd","created_at":1702228811,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://eden.nostr.land/"],["r","wss://relay.nostrplebs.com/"],["r","wss://nos.lol/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://relay.noswhere.com/","read"]],"content":"","sig":"7c96f1e01e35d5510303eb05c64f75923c58da97f695e59a0093386c14fa2fb934806d599145de996f56258da02d568b6cd0ab033ca3510c430fb94758385527"}"###,
    ###"{"id":"6f2c3c583e1c4109f71d9129ca612104faaacc6a89d9072fae487c982b989217","pubkey":"facdaf1ce758bdf04cdf1a1fa32a3564a608d4abc2481a286ffc178f86953ef0","created_at":1702197764,"kind":10002,"tags":[["r","wss://nostr.mutinywallet.com/"]],"content":"","sig":"6dec7bddb8e629b1a5d10a4bbd89f89abcaad952792dcb028b207cfe78308e368f948da82573b459a58f655024432fb753a37a2f7a2a5b5b20eb1bd92bcc5ee2"}"###,
    ###"{"id":"6ae887cfcf74339ab08fd27d6afe0af9ecc12df27e0df4ea8bad6d9719e4c85c","pubkey":"50d94fc2d8580c682b071a542f8b1e31a200b0508bab95a33bef0855df281d63","created_at":1701873034,"kind":10002,"tags":[["r","wss://nostr-pub.wellorder.net/"],["r","wss://relay.nostr.band/","read"],["r","wss://relay.damus.io/"],["r","wss://nos.lol/"],["r","wss://nostr.mom/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://nostr.oxtr.dev/"],["r","wss://nostr.mutinywallet.com/"]],"content":"","sig":"e71550cbae3b00e05a0d2865537e14bcfa1766ccb514c2e4269026ed4e5e777f404c86ce936c95b2fb288231bb23179a00653b8357a6e2542c5a2b6a0643604f"}"###,
    ###"{"id":"2094df9ed40b2af741fdf02045b96f9aa6824d04773ace7557acfa726a3275e3","pubkey":"de7ecd1e2976a6adb2ffa5f4db81a7d812c8bb6698aa00dcf1e76adb55efd645","created_at":1701764293,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr-01.bolt.observer/"],["r","wss://nos.lol/"],["r","wss://relay.mostr.pub/"],["r","wss://offchain.pub/"],["r","wss://relay.nostr.band/"],["r","wss://nostr.rocks/"],["r","wss://nostr2.kleofash.eu/"],["r","wss://relay.primal.net/"]],"content":"","sig":"4fdb95f1c198e4ddd1c804fb8f3551e7ad1d82b695c48bec6977ecbf94cbb70143b214555b5d3a25281229f4a6ea11e150581ef796aa3d3ca819a13cc1cd16cf"}"###,
    ###"{"id":"3ec5c6d56b978f9da9db75e72f17660bf27553191c3715e73a56f78864e1a1a5","pubkey":"5be6446aa8a31c11b3b453bf8dafc9b346ff328d1fa11a0fa02a1e6461f6a9b1","created_at":1701629387,"kind":10002,"tags":[["r","wss://nostr.bitcoiner.social"],["r","wss://nostr-pub.wellorder.net"],["r","wss://filter.nostr.wine/npub1t0nyg64g5vwprva52wlcmt7fkdr07v5dr7s35raq9g0xgc0k4xcsedjgqv?broadcast=true"],["r","wss://relay.nostr.band"],["r","wss://nostr.wine"],["r","wss://relay.damus.io"],["r","wss://lightningrelay.com"],["r","wss://nostr.mutinywallet.com","write"],["r","wss://relay.snort.social"]],"content":"","sig":"4fd7b29ea8c4216a300de8bb6691a02ebb98fa9cd3a9e6c3267b97afa26d71ebe79cff6a83a4dd739535e2bbbe3583b16d0adca1c790fd1a599819e266d664a1"}"###,
    ###"{"id":"7677ee6891d39ff322170ce5022afbbcaaf8e05512161a8925b37000ca692da3","pubkey":"126103bfddc8df256b6e0abfd7f3797c80dcc4ea88f7c2f87dd4104220b4d65f","created_at":1701565220,"kind":10002,"tags":[["r","wss://relay.snort.social/"],["r","wss://relay.damus.io/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nos.lol/"],["r","wss://relay.nostr.band/","read"],["r","wss://nostr.mutinywallet.com/","write"]],"content":"","sig":"0f1dba15e16dd3b945f02c5d9ee7b6bf42f3cbda89884339492a5ac012e9f76a69fd8dc6e10d954cff7c4e677692a2961c8781432aab153161564fb89bfe1112"}"###,
    ###"{"id":"c62d86e3bbeab304515483d0ef09a73bae17319187509e4160523933b7b968e1","pubkey":"1739d937dc8c0c7370aa27585938c119e25c41f6c441a5d34c6d38503e3136ef","created_at":1701364890,"kind":10002,"tags":[["r","wss://eden.nostr.land/"],["r","ws://100.79.124.142:4848/"],["r","wss://relay.snort.social/"],["r","wss://relay.damus.io/"],["r","wss://nos.lol/"],["r","wss://filter.nostr.wine/npub1zuuajd7u3sx8xu92yav9jwxpr839cs0kc3q6t56vd5u9q033xmhsk6c2uc?broadcast=true"],["r","wss://purplepag.es/"],["r","wss://relay.nostr.band/"],["r","wss://canalone.local:4848/"],["r","wss://relay.primal.net"]],"content":"","sig":"6a750018e417ef3fd5ad7855e4e4db912eb83dc64fe441261364fd03276242be10667b7c21cf31ed63e05d5b19940f26ee94a807f3c55a89a7b99387afb79416"}"###,
    ###"{"id":"7b7046134c0c6a901277fa0072a7fca67c92e72a1fdd893976651911206f2605","pubkey":"922945779f93fd0b3759f1157e3d9fa20f3fd24c4b8f2bcf520cacf649af776d","created_at":1701317256,"kind":10002,"tags":[["r","wss://eden.nostr.land/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://offchain.pub/"],["r","wss://nos.lol/"],["r","wss://relay.snort.social/"],["r","wss://relay.current.fyi/"],["r","wss://soloco.nl/"],["r","wss://atlas.nostr.land/"],["r","wss://bicoiner.social/"],["r","wss://damus.io/"],["r","wss://relay.primal.net/"],["r","wss://snort.social/"],["r","wss://bevo.nostr1.com/"],["r","wss://bitcoiner.social/"],["r","wss://blastr.relay.nostr/"]],"content":"","sig":"19693bf3acab494d053d9a818d1dc84e2bfbdfbc1c73b5e131e2dc18ff50928095d65c78aef39484e15fde3045a99b90ef03e806af3e70c42720c0f5fff5c935"}"###,
    ###"{"id":"3d45e7401e9a78a89fc5236169a1b883d077330706a8acd8fecb08221f4fb356","pubkey":"d0debf9fb12def81f43d7c69429bb784812ac1e4d2d53a202db6aac7ea4b466c","created_at":1701273820,"kind":10002,"tags":[["r","wss://filter.nostr.wine/npub16r0tl8a39hhcrapa03559xahsjqj4s0y6t2n5gpdk64v06jtgekqdkz5pl?broadcast=true"],["r","wss://nostr.wine"],["r","wss://relay.nostr.band/npub16r0tl8a39hhcrapa03559xahsjqj4s0y6t2n5gpdk64v06jtgekqdkz5pl"],["r","wss://nostr.sethforprivacy.com"],["r","wss://xmr.usenostr.org"],["r","wss://nostr.mutinywallet.com"],["r","wss://nostr.portemonero.com"],["r","wss://nostr.xmr.rocks"],["r","wss://eden.nostr.land"]],"content":"","sig":"a45a43d47378d01662f5748b404adc16cf34cca7dc61aac9fec49230683a7f308776e32a0d82743fb299dc1d47d3953e0595d2c4fd93796b4e313d4486d1ddb8"}"###,
    ###"{"id":"9bb2b41635451f48f98a0a07490f1d7f084263dcf6a9bbaaefae3c2182cee0cc","pubkey":"8c430bdaadc1a202e4dd11c86c82546bb108d755e374b7918181f533b94e312e","created_at":1701022162,"kind":10002,"tags":[["r","wss://purplepag.es/"],["r","wss://relay.nostr.band/"],["r","wss://relay.nostrplebs.com/"],["r","wss://rsslay.nostr.moe/"],["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nos.lol/"],["r","wss://relay.noswhere.com/"],["r","wss://nostr.wine/"],["r","wss://ca.relayable.org/"],["r","wss://nostr.fmt.wiz.biz/"]],"content":"","sig":"a4a43e6c6689103cd227990ef602f0400b5aa387465c63189a8de59d2f95aed4e9111123185e8b7efecf9a4dcd734862988ff23c42e8072ec686383270657539"}"###,
    ###"{"id":"3aa80e7006091e9e4061f526f0d7b8ee2dc0f8de016981ee14519b45ee5f0816","pubkey":"7b3f7803750746f455413a221f80965eecb69ef308f2ead1da89cc2c8912e968","created_at":1700786097,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nos.lol/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://relay.nostr.bg/"],["r","wss://nostr.mom/"],["r","wss://nostr-pub.semisol.dev/"],["r","wss://nostr.oxtr.dev/"],["r","wss://bitcoiner.social/"],["r","wss://zephaniah:4848/"]],"content":"","sig":"860fcf01bc623226be502de509cfd5e1f0eb6aedb13085de20b8762cb344f47f0e47f77661650425e50abf30ad54049f55f9110be3eb002be4cb109e52afb64d"}"###,
    ###"{"id":"46823523c62a368eab64bcfe97a44ef96c47da781b1ce811fa8260986623b9dc","pubkey":"9be0be0fc079548233231614e4e1efc9f28b0db398011efeecf05fe570e5dd33","created_at":1700700904,"kind":10002,"tags":[["r","wss://nostr.wine"],["r","wss://relay.damus.io"],["r","wss://nos.lol"]],"content":"","sig":"180da9eeaa82f9173982ff34a9ca583e5d26d1047b985611198491a01ce6a01e0e3fe1dbfd2d26997f9294b5b1a353e6b3390569857a8566d12bb3293624a55d"}"###,
    ###"{"id":"60069c82374491a2d12f2700f3e39f87266554bff4857e0cf569bde56ff0f399","pubkey":"05933d8782d155d10cf8a06f37962f329855188063903d332714fbd881bac46e","created_at":1700682593,"kind":10002,"tags":[["r","wss://relay.current.fyi/"],["r","wss://relay.damus.io/"],["r","wss://nos.lol/"],["r","wss://offchain.pub/"]],"content":"","sig":"51771191b6cdabb0e4e0a2ed63829a1775c6bcb5f197fc3bd3d9a609b92b6b47a4098844aa03e56ba470d4dea30a37ec85e1307308338919adb3803220428fe0"}"###,
    ###"{"id":"85203dd9bfe909c3421ac4254e5fb6f56e7ca284d16d98e6bfea460292f93dd6","pubkey":"3356de61b39647931ce8b2140b2bab837e0810c0ef515bbe92de0248040b8bdd","created_at":1700215091,"kind":10002,"tags":[["r","wss://relay.snort.social/"],["r","wss://nostr.wine/","read"],["r","wss://nos.lol/"],["r","wss://relay.nostr.band/"],["r","wss://relay.damus.io/"],["r","wss://purplepag.es/","read"],["r","wss://eden.nostr.land/","read"],["r","wss://welcome.nostr.wine/","read"],["r","wss://offchain.pub/"],["r","wss://relay.shitforce.one/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://relay.current.fyi/"],["r","wss://nostr.mutinywallet.com/","write"]],"content":"","sig":"868335b5fe352db06e25bd1bd6e4fa93ab61588fabc988f70bd5628fe232bf0c082359dd97faf73befb43d944d9859ddd3180e905a0ab5df0eddda968503d1e8"}"###,
    ###"{"id":"c2f52539c4d49cd0947c2e640b6582eb2318d4b159bc790ca9129ee2ac3244e5","pubkey":"b9ceaeeb4178a549e8b0570f348b2caa4bef8933fe3323d45e3875c01919a2c2","created_at":1699922191,"kind":10002,"tags":[["r","wss://nostr.wine/","read"],["r","wss://nos.lol/"],["r","wss://relay.snort.social/","read"]],"content":"","sig":"479c44824c256c7f670a650af3fd999c04ab8c3e1767dd6908c80c32f60f67644cd0d13c32bb7fa19ffce46232592465f6f611fd3d69d91568e8d031c323ac81"}"###,
    ###"{"id":"370aeea25c626138c929c8e7035e74e45b8fdcd26bde763e97244671bb3df957","pubkey":"9c163c7351f8832b08b56cbb2e095960d1c5060dd6b0e461e813f0f07459119e","created_at":1699720101,"kind":10002,"tags":[["r","wss://nostr-pub.semisol.dev"],["r","wss://puravida.nostr.land"],["r","wss://relay.damus.io"],["r","wss://nostr.sandwich.farm"],["r","wss://nostr-pub.wellorder.net"],["r","wss://offchain.pub"],["r","wss://nostr.walletofsatoshi.com"],["r","wss://eden.nostr.land"],["r","wss://nostr.bitcoiner.social"],["r","wss://nostr.terminus.money"],["r","wss://nostr.wine"],["r","wss://relay.current.fyi"],["r","wss://nostr.milou.lol"],["r","wss://nos.lol"],["r","wss://relay.snort.social"],["r","wss://nostr.semisol.dev"],["r","wss://rsslay.fiatjaf.com"]],"content":"","sig":"0bf22e4bb3434fcc23baabe50b5b13eb38026716b14edd7f6f9d058a8c1f9a05df14004842f01b4aa10efeb721201493fb6d94388663ba601fd2c23a19b56401"}"###,
    ###"{"id":"0d29f054848a3cdfd94abb4c04431e929059278c77fd6241e632a407f1a9052a","pubkey":"bdb96ad31ac6af123c7683c55775ee2138da0f8f011e3994d56a27270e692575","created_at":1699443002,"kind":10002,"tags":[["r","wss://relay.snort.social/"],["r","wss://nostr.wine/"],["r","wss://nos.lol/"],["r","wss://relay.damus.io/"],["r","wss://eden.nostr.land/"]],"content":"","sig":"db8f68693b62bf2a9162ab81ae85e2cc1080ba98931c3b29fa6c8852bc416e425a950cc2bfe7e230166c5f6b9a24a88e373891bd2e40f96a451b40041d2cc45f"}"###,
    ###"{"id":"a0cd6819859cc338286874b078f3b9cce2b18fa425be936420b2780671f8258e","pubkey":"7bdef7be22dd8e59f4600e044aa53a1cf975a9dc7d27df5833bc77db784a5805","created_at":1699012507,"kind":10002,"tags":[["r","wss://bitcoiner.social/"],["r","wss://eden.nostr.land/"],["r","wss://filter.nostr.wine/"],["r","wss://nos.lol/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://nostr.milou.lol/"],["r","wss://nostr.wine/"],["r","wss://purplepag.es/"],["r","wss://pyramid.fiatjaf.com/"],["r","wss://relay.damus.io/"],["r","wss://relay.nostr.band/"],["r","wss://relay.nostr.bg/"],["r","wss://relay.nostr.info/"],["r","wss://relay.snort.social/"]],"content":"","sig":"d4bff16882f77130b6309feac20637d76503776ea1bc8bb174bd909ef58c6feb5bae1fd207faf2b1abaddc73ad1a227efd093bd3e7fb9b2a665ba860c72e5067"}"###,
    ###"{"id":"23c870ee7e401c54fd620efc3a18608cc1da800a8127b75ac777cedd78bd726b","pubkey":"e417ee3d910253993ae0ce6b41d4a24609970f132958d75b2d9b634d60a3cc08","created_at":1698058486,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://relay.nostrcheck.me/"],["r","wss://nos.lol/"],["r","wss://relay.current.fyi/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://relay.nostr.band/"],["r","wss://relay.primal.net/"],["r","wss://relay.mostr.pub/"],["r","wss://nostr.wine/","read"],["r","wss://eden.nostr.land/","read"],["r","wss://nostr.orangepill.dev/","read"],["r","wss://relay.snort.social/","read"]],"content":"","sig":"0844b707f1a20c1cc055f0b205838b704dc81a76d5719a175da08f99927e0947e087a38dc0ff68895ff1c9c44b8eb000de7be628f58e1144504be66a06b080c9"}"###,
    ###"{"id":"7ddf7c2fe2ccb0c10a878a511863b798b7ed286a76abaa0aeff65140c5809ca2","pubkey":"0962a7d6342862955d6b9bacb068bd7eb4a0aa88c052c7e7050a496c1d5ca915","created_at":1697823882,"kind":10002,"tags":[["r","wss://nos.lol/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.mom/"],["r","wss://offchain.pub/"],["r","wss://relay.current.fyi/"],["r","wss://relay.damus.io/"],["r","wss://relay.nostr.band/","read"],["r","wss://relay.shitforce.one/"],["r","wss://relayable.org/"]],"content":"","sig":"31392ef9451f82d02e8077ad3aacdb075186bd2873a2777043412a3e26ecdf86d91d1528743604bdf16233cf0051b957e1679b42fc508b102c92a2f8f040a17c"}"###,
    ###"{"id":"9137ee77b117ff25e70656508656dd3688e0b60e0c21a38e82d32938a2bf2f90","pubkey":"7f5c2b4e48a0e9feca63a46b13cdb82489f4020398d60a2070a968caa818d75d","created_at":1697815005,"kind":10002,"tags":[["r","wss://cellar.nostr.wine/"],["r","wss://relay.orangepill.dev/"],["r","wss://relay.nostr.band/"],["r","wss://nostr.wine/"],["r","wss://eden.nostr.land/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://relay.nostrati.com/"],["r","wss://nos.lol/"],["r","wss://relay.damus.io/"],["r","wss://relay.snort.social/"],["r","wss://filter.nostr.wine/npub10awzknjg5r5lajnr53438ndcyjylgqsrnrtq5grs495v42qc6awsj45ys7?broadcast=true"],["r","ws://umbrel.local:4848/"],["r","wss://relay.noswhere.com/"],["r","wss://relayable.org/"],["r","wss://21ideas.nostr1.com/"],["r","wss://purplepag.es/"]],"content":"","sig":"53936f9bb39297b33471c9324ee3178fee1b71f87c87b8064ce181cc43873e3ee92b91fae3482744f54b3b8464ed526e4d57d500dd35cf41bea9365e828a7131"}"###,
    ###"{"id":"f72c69503faecdebb1f630b1b01445fefacd61bfc924b7bae4daeab463cb413a","pubkey":"9989500413fb756d8437912cc32be0730dbe1bfc6b5d2eef759e1456c239f905","created_at":1697601860,"kind":10002,"tags":[["r","wss://relay.snort.social/"],["r","wss://lightningrelay.com/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://relay.damus.io/"],["r","wss://nos.lol/"],["r","wss://relay.nostr.band/"],["r","wss://relay.current.fyi/"],["r","wss://offchain.pub/"],["r","wss://welcome.nostr.wine/"],["r","wss://relay.nostriches.org/"],["r","wss://nostr.wine/"],["r","wss://relay.orangepill.dev/"],["r","wss://relay.nostrview.com/"],["r","wss://relay.mostr.pub/"],["r","wss://eden.nostr.land/"]],"content":"","sig":"e751bf651e7592a784e33e5ae354802facd002e7586a1b0118b762ed5e5834fb95c45e4bce0f311b014b0d3ccae0ad51546984cbbc8ebaa66ef36aa6cf3ebc3c"}"###,
    ###"{"id":"bcd62ac0cfdcf82a1168b81c7407201cde639498a550723d210581c1afbdd30d","pubkey":"d49a9023a21dba1b3c8306ca369bf3243d8b44b8f0b6d1196607f7b0990fa8df","created_at":1697101350,"kind":10002,"tags":[["r","wss://relay.0xchat.com"],["r","wss://relay.damus.io"],["r","wss://relay.nostr.band"],["r","wss://nostr.coinfundit.com"],["r","wss://relayable.org"],["r","wss://nos.lol"],["r","wss://relay.plebstr.com"],["r","wss://nostr.mom"],["r","wss://relay.mostr.pub"],["r","wss://offchain.pub"]],"content":"","sig":"d353eaa9a22973e54f6990fad6bf817cc332d4fecf11d6a634662c5ee3ff020ca45644f8ef853cfd09d1e76431ba961c3c16d18fae019249447f8225c850d566"}"###,
    ###"{"id":"bc1d97fc30a92e3041b0432cc9becbff241bba738bd1465939820d7d03d16b2c","pubkey":"3e294d2fd339bb16a5403a86e3664947dd408c4d87a0066524f8a573ae53ca8e","created_at":1696494226,"kind":10002,"tags":[["r","wss://relay.plebstr.com"],["r","wss://relay.damus.io"],["r","wss://nos.lol"],["r","wss://offchain.pub"],["r","wss://relay.nostr.band"],["r","wss://eden.nostr.land"],["r","wss://nostr-pub.wellorder.net"],["r","wss://e.nos.lol"],["r","wss://relay.wellorder.net"],["r","wss://relay.primal.net"]],"content":"","sig":"d3d53df43ec4b40599c60a1b4e2509b3c8cc86f17d727bfebdf8a1477e00f45e9f0d90bacf63902934034a650abe205436b83c044681597cbf1b805db37ba59f"}"###,
    ###"{"id":"3dc7176ad64af40005ee24163a0b0cad46cfb9698c37bccb579b750df0ea3157","pubkey":"85a8679df872002a2701d93f908d9fa41d82c68a42a253ddb5b69c3881ad3f10","created_at":1696348978,"kind":10002,"tags":[["r","wss://nos.lol"],["r","wss://nostr.wine"],["r","wss://atlas.nostr.land"],["r","wss://relay.orangepill.dev"],["r","wss://relay.damus.io"],["r","wss://relay.nostrplebs.com"],["r","wss://blastr.f7z.xyz"],["r","wss://nostr-pub.wellorder.net"],["r","wss://relayable.org"],["r","wss://purplepag.es"]],"content":"","sig":"ef003051e13de2bf4e81ebb893490ad3854a3d59b33e9c44c4c0564ca9f0b8db550ea627b3b33e256e85bb6919ef7c4bf5a0cc49bb4f484d0da5066970b63a97"}"###,
    ###"{"id":"03e49ff9f33136e3d636825af4c4ff6793e4e8a50687abf934c7ce8e626f25e9","pubkey":"ee11a5dff40c19a555f41fe42b48f00e618c91225622ae37b6c2bb67b76c4e49","created_at":1695781141,"kind":10002,"tags":[["r","wss://at.nostrworks.com/","write"],["r","wss://nos.lol/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.mikedilger.com/","write"],["r","wss://nostr.wine/","write"],["r","wss://offchain.pub/"]],"content":"","sig":"c93e01496f464b7184f0f0c5a9d58e2d8e939def6bc97884d693ed917116cacbf2a4263e8c2f72b97b28973721ae46404fd108eb5a512169424592b1065d70fb"}"###,
    ###"{"id":"a64c00434440e5cc86cd8c8fc1e45eb96ef82f3f47f8384b50493e0bffa089e5","pubkey":"00000000827ffaa94bfea288c3dfce4422c794fbb96625b6b31e9049f729d700","created_at":1695235513,"kind":10002,"tags":[["r","wss://relayable.org"],["r","wss://relay.damus.io"],["r","wss://nos.lol"],["r","wss://relay.noswhere.com"],["r","wss://nostr.thank.eu"],["r","wss://public.relaying.io"],["r","wss://nostr.wine"],["r","wss://offchain.pub"],["r","wss://eden.nostr.land"],["r","wss://relay.plebstr.com"],["r","wss://nostr.thesamecat.io"],["r","wss://purplepag.es"],["client","coracle"]],"content":"","sig":"f5ca2547aec8beda984eee05d59ee7a6f997c8e8d9a6ce5f00626a5e08d8a5b6e8c47e8970a73d11d96fff340bbde83cc5b43c3a1b6e56a456556fba602596ee"}"###,
    ###"{"id":"db8bd4d75ea8c99d460dc51118fa71545d1ca25f8023c32db499f94ffbea123c","pubkey":"bfc058c9abb250a2f4f0f240210ae750221b614f19b9872ea8cdf59a69d68914","created_at":1695157178,"kind":10002,"tags":[["r","wss://eden.nostr.land/"],["r","wss://filter.nostr.wine/"],["r","wss://nos.lol/"],["r","wss://nostr.orangepill.dev/"],["r","wss://nostr.wine/","read"],["r","wss://purplepag.es/","write"],["r","wss://relay.current.fyi/"],["r","wss://relay.damus.io/"],["r","wss://relay.snort.social/"]],"content":"","sig":"0df7c2e978b18e2e6d1fa26c469e7bf303bff80a7ad6af8cd5a1caa87c29b26dc353cc416cc3a8999632e2043cc963d4f455ea3dbf57396f2c6d9bb20dea4595"}"###,
    ###"{"id":"28a409adbac03812253098a79c55792c840a4bdcf0aa5e339c32e1ba5d991d94","pubkey":"330fb1431ff9d8c250706bbcdc016d5495a3f744e047a408173e92ae7ee42dac","created_at":1694166866,"kind":10002,"tags":[["r","wss://relay.primal.net"],["r","wss://relay.current.fyi"],["r","wss://nostr.wine"],["r","wss://nostr.mutinywallet.com"],["r","wss://relay.damus.io"]],"content":"","sig":"635894edd512103bcc6473c7f05125554a68516c2efd86ad14ae152a6e74a10a8d8798e95d2a49fe8173f49a21d760f6d21fe4505190f1b09fa545b45fea4f4b"}"###,
    ###"{"id":"a3e8b79468e00d8852f538b0fee76b4de4b75e8c35cee7b5f9712c2ce4a76904","pubkey":"91c9a5e1a9744114c6fe2d61ae4de82629eaaa0fb52f48288093c7e7e036f832","created_at":1694111356,"kind":10002,"tags":[["r","wss://nostr.wine"],["r","wss://nos.lol"],["r","wss://nostr.mutinywallet.com"],["r","wss://relay.damus.io"],["r","wss://eden.nostr.land"],["r","wss://brb.io"],["r","wss://relay.snort.social"],["r","wss://nostr.zbd.gg"]],"content":"","sig":"078ec369d59b20598595298ecc02d1c7603b3eae54f93cd6e61be884bfd5dd18a93183f26bbcaa1c0fcfac380bfb40b3cb92c32b3182dcdf34ccce5ff03214f6"}"###,
    ###"{"id":"a433444773038c29e23965a0a9923711b343d27051cf9ee2d7a73788ee7b7042","pubkey":"1c52ebc82654e443f92501b7d0ca659e78b75fddcb9c5a65f168ec945698c92a","created_at":1693852140,"kind":10002,"tags":[["r","wss://nos.lol"],["r","wss://relay.primal.net"],["r","wss://relay.nostr.band"],["r","wss://relay.damus.io"],["r","wss://relayable.org"],["r","wss://saltivka.org"],["r","wss://nostr.wine"],["r","wss://christpill.nostr1.com"],["r","wss://nostr.mutinywallet.com"],["r","wss://relay.snort.social"],["r","wss://eden.nostr.land"],["r","wss://relay.nostrplebs.com"]],"content":"","sig":"2b1fd19f155e3d3923307eb6d791ab21e31b23f2ee76096d2fe13d049f7ee4cce86e8bf6fc8d9b94df89e1d041b43b490a5b91538dd43828334c8ae059566ad2"}"###,
    ###"{"id":"b163a924423d700fd16a7d4200d000272ba8df8e57545951bc124c0bcad5c107","pubkey":"9fec72d579baaa772af9e71e638b529215721ace6e0f8320725ecbf9f77f85b1","created_at":1693579931,"kind":10002,"tags":[["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.wine/"],["r","wss://a.nos.lol/"],["r","wss://nos.lol/"],["r","wss://e.nos.lol/"],["r","wss://nostr.mom/"],["r","wss://relay.damus.io/"],["r","wss://relay.nostr.bg/"],["r","wss://offchain.pub/"],["r","wss://relay.snort.social/"],["r","wss://nostr.fmt.wiz.biz/"]],"content":"","sig":"87b6139eac127b7cdf8d5ee0569ae726e30c11197b273738df6662f557869f1ad747e18c611381f2bbe467c5aa3b174a58fa8ed30e319e239e21245523d0b6a9"}"###,
    ###"{"id":"6cc3fb87ce2d8089e9c91f04fd6db9297ee081b59a9e7b399d32a556551ab65d","pubkey":"d2704392769c20d67a153fa77a8557ab071ef27aafc29cf6b46faf582e0595f2","created_at":1689801395,"kind":10002,"tags":[["r","wss://relayable.org/"],["r","wss://relay.nostr.band/","read"],["r","wss://pleb.cloud/"],["r","wss://la.relayable.org/"]],"content":"","sig":"1f26f1f38e0b28cb068f086bacb45f9215193f7c5079b2eb26ae57d2dc3f108ad1de6f5bd84e0fb7277dcd5175c954b240582cb013ec1e26e827f39c77715121"}"###,
    ###"{"id":"8f800af126f8c99611c275f32d4a38278d198d8a7406507c6820c0e744477690","pubkey":"d26f78e5954117b5c6538a2d6c88a2296c65c038770399d7069a97826eb06a95","created_at":1688245978,"kind":10002,"tags":[["r","wss://nos.lol/"],["r","wss://relay.damus.io/"],["r","wss://nostr.orangepill.dev/"],["r","wss://brb.io/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://relay.current.fyi/"],["r","wss://nostr.oxtr.dev/"],["r","wss://eden.nostr.land/"],["r","wss://relay.snort.social/"],["r","wss://nostr.milou.lol/"],["r","ws://umbrel:4848/"],["r","wss://nostr.mutinywallet.com/","read"],["r","wss://relay.nostr.band/","write"]],"content":"","sig":"728d127b7d3060236dc53b10ca534f98a4bd6e071e2f48a76f973c0acfbdc0fad599127fb58ae9bc1fa346b82563ddd7b93b441b1678aefc1c838a42d7cc4424"}"###,
    ###"{"id":"674c09e91c8be4db77b5eb26758c9178dccea252f36a23d58aa4365ea035b5b4","pubkey":"218238431393959d6c8617a3bd899303a96609b44a644e973891038a7de8622d","created_at":1687403345,"kind":10002,"tags":[["r","wss://nos.lol/"],["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.wine/","read"],["r","wss://relayable.org"],["r","wss://ca.relayable.org"]],"content":"","sig":"c23f3d1d15c612d285e8a7d18418b4424546f27c3a5881eb3efcc6150832e9aefdc9919e044fe78cf0b5bcccc513af506a3c5fb42d206739534acc0137eec2ad"}"###,
    ###"{"id":"615b49cb56fb407f995ca8175e14fc6ff90ebc6b479cae3b21522a5917f1e8fa","pubkey":"1b11ed41e815234599a52050a6a40c79bdd3bfa3d65e5d4a2c8d626698835d6d","created_at":1687102959,"kind":10002,"tags":[["r","wss://eden.nostr.land"],["r","wss://nos.lol"],["r","wss://nostr.wine"],["r","wss://relay.damus.io"],["r","wss://nostr.zbd.gg"]],"content":"","sig":"3598323365df98246bdd3e4970354bb3c3aa347a432c181df33a4626abaf2589958c96650ab0aac1920adb68db647b803b26dfac2fe994fcb6f47d9ab1e9025d"}"###,
    ###"{"id":"bbc40286d2b402042d95a3b1ff361fadd864d44b407faa6a8bee9e041753a501","pubkey":"4ea843d54a8fdab39aa45f61f19f3ff79cc19385370f6a272dda81fade0a052b","created_at":1686890555,"kind":10002,"tags":[["r","wss://relay.snort.social"],["r","wss://nostr.wine","read"],["r","wss://nos.lol"],["r","wss://purplepag.es"],["r","wss://relay.damus.io"],["client","agora"]],"content":"","sig":"df32e30b039bab6491e721b1343491d45442ab2a77fe8be83c3eac0f5316b5cfc4a1795bda09814c0739de9de5c0943f460486a6e0712ea35ca952b712634023"}"###,
    ###"{"id":"f18fe54fac6e73c4341ed90e7a3de7d0272b33459ac4f56559da0ebff1c44a6d","pubkey":"72f9755501e1a4464f7277d86120f67e7f7ec3a84ef6813cc7606bf5e0870ff3","created_at":1685539290,"kind":10002,"tags":[["r","wss://relay.nostr.band/"],["r","wss://relay.plebstr.com/"],["r","wss://nostr.wine/"],["r","wss://filter.nostr.wine/npub1wtuh24gpuxjyvnmjwlvxzg8k0elhasagfmmgz0x8vp4ltcy8ples54e7js?broadcast=true"],["r","wss://nostr-dev.wellorder.net/"],["r","wss://nostr-01.bolt.observer/"],["r","wss://nostr.thesamecat.io/"],["r","wss://relay.nostrcheck.me/"],["r","wss://bitcoiner.social/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://relay.current.fyi/"],["r","wss://nostr.zebedee.cloud/"],["r","wss://purplepag.es/"],["r","wss://relay.taxi"],["r","wss://nostr.foundrydigital.com"]],"content":"","sig":"94bd398713d4b969a341f7a9da7521bf9be1eaf0d7dcef374373c1b0f3e116020832c9c934a74e85a40565d4a52171bad3e3c13c9bb5e06e308fc4979baaefb3"}"###,
    ###"{"id":"6c4b328c54e8450886a78d4a42515e87833fdace4e606b4bb7dbaf03922b6031","pubkey":"2183e94758481d0f124fbd93c56ccaa45e7e545ceeb8d52848f98253f497b975","created_at":1685233339,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://nostr.zaprite.io/"],["r","wss://relay.nostr.info/"],["r","wss://relay.futohq.com/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://nostr-relay.wlvs.space/"],["r","wss://expensive-relay.fiatjaf.com/","read"],["r","wss://rsslay.fiatjaf.com/","read"],["r","wss://nostr.zebedee.cloud/"]],"content":"","sig":"de0db062280a4ac1c5d90b415b05a77b275167d5f259bb0b92f6fbffec9ec49722681d0dc37272f14911135b0e5d2c535a17df63c2c34782c7781ae4341633d2"}"###,
    ###"{"id":"f0b8454081ffe53cd79a048ec3125de771a18b6cf172801a4ccdfde8b48a990e","pubkey":"b9a537523bba2fcdae857d90d8a760de4f2139c9f90d986f747ce7d0ec0d173d","created_at":1685131632,"kind":10002,"tags":[["r","wss://eden.nostr.land/"],["r","wss://nostr.fmt.wiz.biz/"],["r","wss://relay.damus.io/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://offchain.pub/"],["r","wss://nos.lol/"],["r","wss://relay.snort.social/"],["r","wss://relay.current.fyi/"],["r","wss://relay.nostr.band/"],["r","wss://relay.nostr.scot/"],["r","wss://relayer.fiatjaf.com/"],["r","wss://nostr.mutinywallet.com/"],["r","wss://nostr.wine/"],["r","wss://filter.nostr.wine/npub1hxjnw53mhghumt590kgd3fmqme8jzwwflyxesmm50nnapmqdzu7swqagw3?broadcast=true"]],"content":"","sig":"b1d081d43840e6b4584a17fd3e8bdf9536d570627443b2479649a9ef5af6c67454f182bfdf7b76d3d47d1ed60bdfafd8213a2b2b2f91adc9d781ae4b79d47695"}"###,
    ###"{"id":"c44ca8f43d43eb24316ee5034ac0e14ce605b192f4c4ea36b0e0baa9d2b25c7a","pubkey":"9a39bf837c868d61ed8cce6a4c7a0eb96f5e5bcc082ad6afdd5496cb614a23fb","created_at":1683713727,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nos.lol/"],["r","wss://nostr-pub.wellorder.net/"],["r","wss://relay.nostr.band/"],["r","wss://nostr.bitcoiner.social/"],["r","wss://nostr.walletofsatoshi.com/"],["r","wss://nostr.wine/"],["r","wss://eden.nostr.land/"],["r","wss://nostr.zebedee.cloud/"],["r","wss://puravida.nostr.land/"],["r","wss://filter.nostr.wine/npub1ngumlqmus6xkrmvvee4yc7swh9h4uk7vpq4ddt7a2jtvkc22y0asrse3pv?broadcast=true"]],"content":"","sig":"09f63b150eb05bc6a54140102ea2290b6491e96a2507a72f1a0cfb6a6a243b275a66f01c14ea1f59cc472fcf70dd255f7263a837bd08fbc234eb5c2f45f42474"}"###,
    ###"{"id":"45cbda5b9eab93142bc072b7a48b66d528f89fe4b2bc166d1995b1734fdb2141","pubkey":"8eee8f5a002e533e9f9ffef14c713da449c23f56f4415e7995552075a02d1d37","created_at":1683663492,"kind":10002,"tags":[["r","wss://nostr.wine/"],["r","wss://nos.lol/"],["r","wss://relay.damus.io/"],["r","wss://eden.nostr.land/"]],"content":"","sig":"56c83d102120853213273e2d7d66faca5bcd3fb0ad8f5bc89d7ab24f634a10b5e42b603b7c41427b832c46444d550d942281dc8d87178275a14aff8718ed2b5d"}"###,
    ###"{"id":"6a483b85ac46ca25277271085948267fc0cf9ec3d014d4bee5de40e2aa8ff56c","pubkey":"89e14be49ed0073da83b678279cd29ba5ad86cf000b6a3d1a4c3dc4aa4fdd02c","created_at":1682418673,"kind":10002,"tags":[["r","wss://nos.lol"],["r","wss://relay.damus.io"],["r","wss://relay.orangepill.dev"],["r","wss://relay.nostrplebs.com"],["r","wss://relay.punkhub.me"],["r","wss://relay.current.fyi"],["r","wss://eden.nostr.land"],["r","wss://relay.nostrcheck.me"],["r","wss://relay.plebstr.com"],["r","wss://relay.nostr.band"],["r","wss://purplepag.es"],["r","wss://welcome.nostr.wine"],["r","wss://relay.nostrgraph.net"],["client","coracle"]],"content":"","sig":"44051143a26061fe1fd575ed946c47f703be29d38230dbbb5eedcb2b27072d8eb81143920ad9a00252bfe205bf7bf3e3bcbaf4f250e86d52213f1d5246216597"}"###,
    ###"{"id":"f87dcdfcb0a0437725917e2cb00972fe874f1da478912ddd17aa826e33149c49","pubkey":"35d26e4690cbe1a898af61cc3515661eb5fa763b57bd0b42e45099c8b32fd50f","created_at":1682035607,"kind":10002,"tags":[["r","wss://nostr-pub.wellorder.net"],["r","wss://nostr.wine"],["r","wss://relay.nostr.band"],["r","wss://nos.lol"],["client","coracle"]],"content":"","sig":"908bc19a10d223cd144de01a015739ecc2eb76ab84f2693167014939799736e5a4e3814283965007d38bc5a19343da635c8eaea6a754c21149a879e4f56a787c"}"###,
    ###"{"id":"374b1c68d64ade86f73e342347999d92ce22e4324c457e11c61a967cb03aba32","pubkey":"f9a352db4aa115ec5d330540dda37b71e2460cc0f65e3318fa3b244945dc8eb8","created_at":1680933705,"kind":10002,"tags":[["r","wss://atlas.nostr.land",""],["r","wss://brb.io",""],["r","wss://damus.io",""],["r","wss://nostr-pub.semisol.dev",""],["r","wss://nostr-pub.wellorder.net",""],["r","wss://nostr.developer.li",""],["r","wss://nostr.einundzwanzig.space/",""],["r","wss://nostr.mnethome.de",""],["r","wss://nostr.mom/",""],["r","wss://nostr.ono.re",""],["r","wss://nostr.onsats.org",""],["r","wss://nostr.openchain.fr",""],["r","wss://nostr.oxtr.dev",""],["r","wss://nostr.swiss-enigma.ch",""],["r","wss://nostrplebs.com",""],["r","wss://purplepag.es",""],["r","wss://relay.damus.io",""],["r","wss://relay.grunch.dev",""],["r","wss://relay.nostr.band",""],["r","wss://relay.nostr.info",""],["r","wss://relay.tnano.duckdns.org",""]],"content":"","sig":"861ba6b5c7fe32fac5b6fb25d1510d808c7a2103015d0520d5f302b7c3042cffcd78ab5162684cf7044acaaf28180ec9443a8ad706141f479aeae5bec34d9e51"}"###,
    ###"{"id":"0a4aa550ef7932e44ec3d25b0a3b20fae783ca7f7b2dc3f2df67743828051276","pubkey":"883fea4c071fda4406d2b66be21cb1edaf45a3e058050d6201ecf1d3596bbc39","created_at":1680116479,"kind":10002,"tags":[["r","wss://eden.nostr.land"],["r","wss://nostr.fmt.wiz.biz"],["r","wss://relay.damus.io"],["r","wss://nostr-pub.wellorder.net"],["r","wss://relay.nostr.info"],["r","wss://offchain.pub"],["r","wss://nos.lol"],["r","wss://brb.io"],["r","wss://relay.snort.social"],["r","wss://relay.current.fyi"],["r","wss://relay.mostr.pub"],["r","ws://willem.currycash.net:4848"],["r","wss://nostr.mom"],["r","wss://nostr.oxtr.dev"],["r","wss://puravida.nostr.land"],["r","wss://nostr.wine"],["r","wss://nostr.bitcoiner.social"],["r","wss://relay.nostr.bg"],["r","wss://nostr-relay.wlvs.space"],["r","wss://nostr.walletofsatoshi.com"],["r","wss://atlas.nostr.land"],["r","wss://relay.nostriches.org"],["r","wss://no.str.cr"],["r","wss://filter.nostr.wine/npub1sjjz60h6fqqcuxrsyl3thhgpx2z6ylv047tslqar26ga0chp5vgq7404nu?broadcast=true"],["r","wss://relay.nostr.band"],["r","wss://nostr.milou.lol"],["r","wss://bitcoiner.social"],["r","wss://relay.damus.io/"]],"content":"","sig":"e5839dbdb086937945334ff9a143db8169a36f08fe1aaaee8a2877e7950c922e4ce1dfbcde501f4aecca0db454b39938ef60d289794d7c3a8ffadf71ba0d81fc"}"###,
    ###"{"id":"e130e90c95545e1ef8d188df8447ecf2cf819dea07ec3ef545d514427d5e2e02","pubkey":"c8df6ae886c711b0e87adf24da0181f5081f2b653a61a23b1055a36022293a06","created_at":1679686978,"kind":10002,"tags":[["r","wss://relay.damus.io"],["r","wss://eden.nostr.land"],["r","wss://relay.nostriches.org"],["r","wss://bitcoiner.social"],["r","wss://rjj6ejkihilniytxs56qrgtttgcfnnjvbii6vaas6jzppcmekd63ugad.local/"]],"content":"","sig":"0fb94e55c6d26e3978824e4994704992c0c4ab1b9d09627673d2fe0da5c2b4cf1397baf58777c59ea1358aa77ac35374e41917da453b13190fbee3499e61107f"}"###,
    ###"{"id":"437d64879b069ad32b7999684f80a9971962518ecde4acffa6d2dd976a0228ae","pubkey":"76c71aae3a491f1d9eec47cba17e229cda4113a0bbb6e6ae1776d7643e29cafa","created_at":1679331515,"kind":10002,"tags":[["r","wss://relay.damus.io"],["r","wss://relay.snort.social"],["r","wss://nos.lol"],["r","wss://brb.io"],["r","wss://relay.current.fyi"],["r","wss://nostr-pub.wellorder.net"],["r","wss://nostr.oxtr.dev"],["r","wss://relay.nostr.bg"],["r","wss://nostr.mom"],["r","wss://nostr.fmt.wiz.biz"],["r","wss://nostr-pub.semisol.dev"],["r","wss://nostr.zebedee.cloud"],["r","wss://nostr.pleb.network"],["r","wss://relay.nostr.band"],["r","wss://nostr.21sats.net"],["r","wss://nostr.h4x0r.host"],["r","wss://relay.nostrich.de"],["r","wss://nostr.1729.cloud"],["r","wss://lightningrelay.com"]],"content":"","sig":"419171e941374edab95403ed66cb5c7de0840364b9813421779be98b39cd811a98bce436b1292e3b0c7c5974984815d0360fed6dd475e9b880caa0fb482e20ed"}"###,
    ###"{"id":"6a927f1cb3db4c5a9b9b874f9ae0c17adc38bcbb97dada8b5bafd6899c41bf5d","pubkey":"e88a691e98d9987c964521dff60025f60700378a4879180dcbbb4a5027850411","created_at":1678565220,"kind":10002,"tags":[["r","wss://relay.damus.io/"],["r","wss://nostr.mutinywallet.com/","write"],["r","wss://eden.nostr.land/"]],"content":"","sig":"269291e68a7f0deba4a535acdaa39453ed66e2f1b7ae719338bdddc4c7bd587ad93b89cb259bf5322412035a7552236eb870382e21c1925e3a15f44a4cc0fb69"}"###,
    ###"{"id":"2fd6e3b0508c95c94cb0b7ceeb41ee16c197785ed865edebdc46771c2e0a6862","pubkey":"d7f0e3917c466f1e2233e9624fbd6d4bd1392dbcfcaf3574f457569d496cb731","created_at":1677672048,"kind":10002,"tags":[["r","wss://relay.damus.io"],["r","wss://relay.snort.social"],["r","wss://relay.plebstr.com/"]],"content":"","sig":"d898d1e7b908cc70b3003fe77e188b0f217de0bdf57bd5d9eaffa7d0a65d8df99d7ab86da30350fa3356e80db6e9424beeea0ec6c3590d82a1c4f281ac25032d"}"###,
    ###"{"id":"1f6be3fbc0b9285b8277bc510330824ab6928069f4942697cb01f1e313a1f8ca","pubkey":"d91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075","created_at":1677506238,"kind":10002,"tags":[["r","wss://filter.nostr.wine/npub1mygerccwqpzyh9pvp6pv44rskv40zutkfs38t0hqhkvnwlhagp6s3psn5p?broadcast=true","read"],["r","wss://nostr.wine","read"]],"content":"","sig":"6fafd43fc266e52c968594f3bb5b62067b26a8d76f8364f0ba9034bb5416e56fdd509ad2d525d5e38785c90a248b5d796ae1f92ee6251c230cef18a4a53d3948"}"###,
    ###"{"id":"84a258c0d31fc8788c24dd9e5e7869c35bac1f805a97be21d2ac7fcb94d0fecd","pubkey":"b4cfa7ba658d88764e62dd0d40b6df3cc39d8a71fe1bd448a26b9253916e69cb","created_at":1677430759,"kind":10002,"tags":[["r","wss://nostr-pub.wellorder.net"],["r","wss://nostr.bitcoiner.social"],["r","wss://relay.damus.io"],["r","wss://nostr.zebedee.cloud","read"],["r","wss://relay.nostr.info","read"],["r","wss://relayer.fiatjaf.com","read"]],"content":"","sig":"c374679b335aa81a2832f795e07ee1388b2a50c1062872e5d413a0d4d74fb6f26e8f2a3f9189e68ea82868730701c4d74fd4a414f72c1636087a4a0612e68960"}"###,
    ###"{"id":"e7f9a9695ba5a58956c6d058fab1d9c71f45e89abc8bcce1536cd997fcafcc17","pubkey":"82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2","created_at":1677080118,"kind":10002,"tags":[["r","wss://nostr.oxtr.dev"],["r","wss://eden.nostr.land"],["r","wss://relay.snort.social"],["r","wss://nostr.milou.lol","read"],["r","wss://relay.damus.io"]],"content":"","sig":"7a60f23eda5ed8cc02aa6ab0e5538323d5e45a458a36e99bbbd7947fcc31d99d6c35d1c94035e208238212b10cb3598aa0bb1d7cc7be4991c3750d3bed908bc3"}"###,
    ###"{"id":"dbc767e91043e2fe890462a2985878c9122026ddfc73a258718beef3d76d49fa","pubkey":"1989034e56b8f606c724f45a12ce84a11841621aaf7182a1f6564380b9c4276b","created_at":1676850882,"kind":10002,"tags":[["r","ws://ng4jk6yiqgfczo4wyxszuj7w6jok3fptehu533o3mlzs3vph3dvjfdid.onion"],["r","wss://relay.damus.io"],["r","ws://100.94.8.112:4848"],["r","wss://relay.nostr.bg"],["r","wss://nostr.zebedee.cloud"],["r","wss://relay.nostr.info"],["r","wss://relay.snort.social"],["r","wss://nostr.bitcoiner.social"],["r","wss://nostr.wine/"]],"content":"","sig":"1ead29501d6d4aa2ebef2443707ceeb9836633c5190fb22dbccd08cd9a2e96f870ee134f1ba4d3dfe30bb49042819ee0efeb1af2256fb2ade6168b8c7b6d7dca"}"###,
    ###"{"id":"94dab28abbacd42f4c2cb4ee345b7a8dd06f0118072966ed799d66d5d8aa20ec","pubkey":"134743ca8ad0203b3657c20a6869e64f160ce48ae6388dc1f5ca67f346019ee7","created_at":1676479665,"kind":10002,"tags":[["r","wss://nostr-relay.wlvs.space"],["r","wss://nostr-pub.semisol.dev","read"],["r","wss://relay.snort.social"],["r","wss://nostr.bitcoiner.social"],["r","wss://relay.damus.io"],["r","wss://nos.lol"],["r","wss://relay.current.fyi"],["r","wss://nostr.onsats.org"],["r","wss://nostr.orangepill.dev"],["r","wss://brb.io"],["r","wss://relay.nostr.info"],["r","wss://nostr.walletofsatoshi.com","read"],["r","wss://nostr.zebedee.cloud","read"],["r","wss://eden.nostr.land"],["r","wss://nostr-pub.wellorder.net"],["r","wss://relay.nostrcheck.me/"]],"content":"","sig":"9addb9b4bdd3a2a99f22d36f22aa79cf02c04e46b93c826fcedb930380e8d16bf3a5adf6316c091c99ac50271eb37a38732f8961a67bc4a849ea8a02c791b40f"}"###,
    ###"{"id":"52cc734dc2dce12c254183c02f7762ff623e07584bd6d113e222effb934801c3","pubkey":"021d7ef7aafc034a8fefba4de07622d78fd369df1e5f9dd7d41dc2cffa74ae02","created_at":1676294462,"kind":10002,"tags":[["r","wss://nostr.fmt.wiz.biz"],["r","wss://relay.snort.social"],["r","ws://nostr.foundrydigital.com:80"],["r","wss://nostr.bitcoiner.social"],["r","wss://relay.damus.io"],["r","wss://nos.lol"],["r","wss://relay.nostr.bg"],["r","wss://nostr.oxtr.dev"],["r","wss://relay.current.fyi"],["r","wss://nostr.orangepill.dev"],["r","wss://relay.nostr.info"],["r","wss://nostr.foundrydigital.com"],["r","wss://nostr.zebedee.cloud"],["r","wss://brb.io"],["r","ws://nostr.foundrydigital.com:7777"],["r","wss://relay.nostr.ch"],["r","wss://eden.nostr.land"]],"content":"","sig":"be68fce27f1cfcfe8b777a0be22d12c0644f480f5a2c258b515ae7ce3ede50932a0980b6c027d79a070c4623509d14dfe3af3c0fe756475be13446e9dd1c8648"}"###,
]

let SPECIAL_PURPOSE_RELAYS: Set<String> = [
    "wss://nostr.mutinywallet.com",
    "wss://filter.nostr.wine",
    "wss://purplepag.es"
]


