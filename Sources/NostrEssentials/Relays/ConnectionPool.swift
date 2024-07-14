//
//  File.swift
//  
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation
import Combine
import CoreData

// There should be 1 instance of ConnectionPool in your app
// Relay connections are added to the pool with poolInstance.addConnection(relayConfig)

public typealias CanonicalRelayUrl = String // lowercased, without trailing slash on root domain

public class ConnectionPool: ObservableObject {
    public var queue = DispatchQueue(label: "connection-pool", qos: .utility, attributes: .concurrent)
    private var delegate: RelayConnectionDelegate
    
    // Pubkeys grouped by relay url for finding events (.findEventsRelays) (their write relays)
    // and pubkeys grouped by relay url for publishing to reach them (.reachUserRelays) (their read relays)
    private var preferredRelays: PreferredRelays?
    
    private var maxPreferredRelays: Int = 50
    
    // Normal connections used for our relay set
    public var connections: [CanonicalRelayUrl: RelayConnection] = [:]
    
    // Outbox connections resolved from kind 10002s
    private var outboxConnections: [CanonicalRelayUrl: RelayConnection] = [:]
    
    // For relays that always have zero (re)connected + 3 or more errors (TODO: need to finetune and better guess/retry)
    public var penaltybox: Set<CanonicalRelayUrl> = [] {
        didSet {
            self.reloadPreferredRelays()
        }
    }
    
    // Relays to find posts on relays not in our relay set
    public var findEventsConnections: [CanonicalRelayUrl: RelayConnection] = [:]
    
    // Relays to reach users on relays not in our relay set
    public var reachUsersConnections: [CanonicalRelayUrl: RelayConnection] = [:]
    
    public init(delegate: RelayConnectionDelegate) {
        self.delegate = delegate
    }
    
    private var _pubkeysByRelay: [String: Set<String>] = [:]
    
    public func setPreferredRelays(using kind10002s: [Event], maxPreferredRelays: Int = 50) {
        self.preferredRelays = pubkeysByRelay(kind10002s)
        
        // Set limit because to total relays will be derived from external events and can be abused
        self.maxPreferredRelays = maxPreferredRelays
    }
    
    private var kind10002s: [Event] = [] // cache here for easy reload after updating .penaltybox
    private func reloadPreferredRelays() {
        self.preferredRelays = pubkeysByRelay(self.kind10002s , ignoringRelays: self.penaltybox)
    }

    public func addConnection(_ relayConfig: RelayConfig) -> RelayConnection {
        if let existingConnection = connections[relayConfig.id] {
            return existingConnection
        }
        else {
            let newConnection = RelayConnection(relayConfig, queue: queue, delegate: self.delegate, pool: self)
            connections[relayConfig.id] = newConnection
            return newConnection
        }
    }
    
    public func addOutboxConnection(_ relayConfig: RelayConfig) -> RelayConnection {
        if let existingConnection = outboxConnections[relayConfig.id] {
            if relayConfig.read && !existingConnection.relayConfig.read {
                existingConnection.relayConfig.setRead(true)
            }
            if relayConfig.write && !existingConnection.relayConfig.write {
                existingConnection.relayConfig.setWrite(true)
            }
            return existingConnection
        }
        else {
            let newConnection = RelayConnection(relayConfig, queue: queue, delegate: self.delegate, pool: self)
            outboxConnections[relayConfig.id] = newConnection
            return newConnection
        }
    }
    
    public func connectAll() {
        for (_, connection) in self.connections {
            queue.async {
                guard connection.relayConfig.read || connection.relayConfig.write else { return }
                guard !connection.isSocketConnected else { return }
                connection.connect()
            }
        }
    }
    
    public func connectionByUrl(_ url:String) -> RelayConnection? {
        let relayConnection = connections.filter { relayId, relayConnection in
            relayConnection.url == url.lowercased()
        }.first?.value
        return relayConnection
    }
    
    public func isUrlConnected(_ url:String) -> Bool {
        let url = normalizeRelayUrl(url)
        let relayConnection = connections.filter { relayId, relayConnection in
            relayConnection.url == url
        }.first?.value
        guard relayConnection != nil else {
            return false
        }
        return relayConnection!.isConnected
    }
    
    public func removeConnection(_ relayId: String) {
        if let connection = connections[relayId] {
            connection.disconnect()
            connections.removeValue(forKey: relayId)
        }
    }

    func removeOutboxConnection(_ relayId: String) {
        if let connection = outboxConnections[relayId] {
            connection.disconnect()
            outboxConnections.removeValue(forKey: relayId)
        }
    }
    
    public func disconnectAll() {
        for (_, connection) in connections {
            connection.disconnect()
        }
    }
    
    // TODO: NEED TO CHECK HOW WE HANDLE CLOSE PER CONNECTION WITH THE PREFERRED RELAYS....
    public func closeSubscription(_ subscriptionId:String) {
        let connections = self.connections
        queue.async { [weak self] in
            guard let self else { return }
            for (_, connection) in connections {
                guard connection.isSocketConnected else { continue }
                
                if connection.nreqSubscriptions.contains(subscriptionId) {
                    let closeMessage = ClientMessage(type: .CLOSE, subscriptionId: subscriptionId).json()!
                    connection.sendMessage(closeMessage)
                    self.queue.async(flags: .barrier) {
                        connection.nreqSubscriptions.remove(subscriptionId)
                    }
                }
            }
        }
    }
    
    public func sendMessage(_ message: ClientMessage, subscriptionId: String? = nil, afterPing: Bool = false) {
        let connections = self.connections
        queue.async { [weak self] in
            guard let self = self else { return }
            for (_, connection) in connections {
                
                guard connection.relayConfig.read || connection.relayConfig.write else {
                    // Skip if relay is not selected for reading or writing events
                    continue
                }
                
                if message.type == .REQ { // REQ FOR ALL READ RELAYS
                    if !connection.relayConfig.read { continue }
                    
                    if (!connection.isSocketConnected) {
                        if (!connection.isSocketConnecting) {
                            connection.connect()
                        }
                    }
                    // skip if we already have an active subcription
                    if subscriptionId != nil && connection.nreqSubscriptions.contains(subscriptionId!) { continue }
                    if (subscriptionId != nil) {
                        self.queue.async(flags: .barrier) { [weak connection] in
                            connection?.nreqSubscriptions.insert(subscriptionId!)
                        }
                    }
                    connection.sendMessage(message.json()!)
                }
                else if message.type == .CLOSE { // CLOSE FOR ALL RELAYS
                    if (!connection.relayConfig.read) { continue }
                    if (!connection.isSocketConnected) && (!connection.isSocketConnecting) {
                        // Already closed? no need to connect and send CLOSE message
                        continue
                    }
                    connection.sendMessage(message.json()!)
                }
                else if message.type == .EVENT {
                    if  !connection.relayConfig.write { continue }
                    if (!connection.isSocketConnected) && (!connection.isSocketConnecting) {
                        connection.connect()
                    }
                    connection.sendMessage(message.json()!)
                }
            }
        }
        
        guard let preferredRelays = self.preferredRelays else { return }
        
        // SEND REQ TO WHERE OTHERS WRITE (TO FIND THEIR POSTS, SO WE CAN READ)
        if message.type == .REQ && !preferredRelays.findEventsRelays.isEmpty {
            self.sendToOthersPreferredWriteRelays(message, subscriptionId: subscriptionId)
        }
        
        // SEND EVENT TO WHERE OTHERS READ (TO SEND REPLIES ETC SO THEY CAN READ IT)
        else if message.type == .EVENT && !preferredRelays.reachUserRelays.isEmpty {
            // don't send to p's if it is an event kind where p's have a different purpose than notification (eg kind:3)
            guard (message.event?.kind ?? 1) != 3 else { return } // TODO: Which kinds more?
            
            let pTags: Set<String> = Set( message.event?.tags.filter { $0.type == "p" }.compactMap { $0.pubkey } ?? [] )
            self.sendToOthersPreferredReadRelays(message, pubkeys: pTags)
        }
    }
    
    // SEND REQ TO WHERE OTHERS WRITE (TO FIND THEIR POSTS, SO WE CAN READ)
    private func sendToOthersPreferredWriteRelays(_ message: ClientMessage, subscriptionId: String? = nil) {
        guard let preferredRelays = self.preferredRelays else { return }
        
        let ourReadRelays: Set<String> = Set(connections.filter { $0.value.relayConfig.read }.map { $0.key })
        
        // Take pubkeys from first filter. Could be more and different but that wouldn't make sense for an outbox request.
        guard let filters = message.filters else { return }
        guard let pubkeys = filters.first?.authors else { return }
        
        let plan: RequestPlan = createRequestPlan(pubkeys: pubkeys, reqFilters: filters, ourReadRelays: ourReadRelays, preferredRelays: preferredRelays)
        
        for req in plan.findEventsRequests
            .filter({ (relay: String, findEventsRequest: FindEventsRequest) in
                // Only requests that have .authors > 0
                // Requests can have multiple filters, we can count the authors on just the first one, all others should be the same (for THIS relay)
                findEventsRequest.pubkeys.count > 0
                
            })
            .sorted(by: {
                $0.value.pubkeys.count > $1.value.pubkeys.count
            })
            .prefix(self.maxPreferredRelays) // SANITY
        {
//            print("🟩 SENDING REQ -- \(req.value.pubkeys.count): \(req.key) - \(req.value.filters.description)")
            let connection = self.addOutboxConnection(RelayConfig(url: req.key, read: true, write: false))
            if !connection.isConnected {
                connection.connect()
            }
            guard let message = ClientMessage(
                type: .REQ,
                subscriptionId: subscriptionId,
                filters: req.value.filters
            ).json()
            else { return }
            
            connection.sendMessage(message)
        }
    }
    
    // SEND EVENT TO WHERE OTHERS READ (TO SEND REPLIES ETC SO THEY CAN READ IT)
    private func sendToOthersPreferredReadRelays(_ message: ClientMessage, pubkeys: Set<String>) {
        guard let preferredRelays = self.preferredRelays else { return }
        
        let ourWriteRelays: Set<String> = Set(connections.filter { $0.value.relayConfig.write }.map { $0.key })
        
        let plan: WritePlan = createWritePlan(pubkeys: pubkeys, ourWriteRelays: ourWriteRelays, preferredRelays: preferredRelays)
        
        for (relay, _) in plan.relays
            .filter({ (relay: String, pubkeys: Set<String>) in
                // Only relays that have .authors > 0
                pubkeys.count > 0
                
            })
            .sorted(by: {
                $0.value.count > $1.value.count
            }) {
            
//            print("🟩 SENDING EVENT -- \(relay): \(pubkeys.joined(separator: ","))")
            let connection = self.addOutboxConnection(RelayConfig(url: relay, read: false, write: true))
            if !connection.isConnected {
                connection.connect()
            }
            guard let messageString = message.json() else { return }
            connection.sendMessage(messageString)
        }
    }
    
}
