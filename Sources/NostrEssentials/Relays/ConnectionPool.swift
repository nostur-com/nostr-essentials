//
//  File.swift
//  
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation
import Combine
import CombineWebSocket
import CoreData

// There should be 1 instance of ConnectionPool in your app
// Relay connections are added to the pool with poolInstance.addConnection(relayConfig)

public typealias CanonicalRelayUrl = String // lowercased, without trailing slash on root domain

public class ConnectionPool: ObservableObject {
    public var queue = DispatchQueue(label: "connection-pool", qos: .utility, attributes: .concurrent)
    private var delegate: RelayConnectionDelegate
    
    public var connections:[CanonicalRelayUrl: RelayConnection] = [:]
    
    public init(delegate: RelayConnectionDelegate) {
        self.delegate = delegate
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
    
    public func disconnectAll() {
        for (_, connection) in connections {
            connection.disconnect()
        }
    }
    
    public func closeSubscription(_ subscriptionId:String) {
        let connections = self.connections
        queue.async {
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
    
    public func sendMessage(_ message:ClientMessage, subscriptionId:String? = nil, afterPing:Bool = false) {
        let connections = self.connections
        queue.async {
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
                        self.queue.async(flags: .barrier) {
                            connection.nreqSubscriptions.insert(subscriptionId!)
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
        
        if message.type == .REQ && !preferredRelays.findEventsRelays.isEmpty {
            self.sendToUsersPreferredReadRelays(message, subscriptionId: subscriptionId)
        }
        else if message.type == .EVENT && !preferredRelays.reachUserRelays.isEmpty {
            self.sendToUsersPreferredReadRelays(message, subscriptionId: subscriptionId)
        }
    }
    
    private func sendToUsersPreferredReadRelays(_ message: ClientMessage, subscriptionId: String? = nil) {
        guard let preferredRelays = self.preferredRelays else { return }
        
        let ourRelays: Set<String> = Set(connections.keys)
        
        // Take pubkeys from first filter. Could be more and different but that wouldn't make sense for an outbox request.
        guard let filters = message.filters else { return }
        guard let pubkeys = filters.first?.authors else { return }
        
        let plan: RequestPlan = createRequestPlan(pubkeys: pubkeys, reqFilters: filters, ourRelays: ourRelays, preferredRelays: preferredRelays)
        
        for req in plan.findEventsRequests
            .filter({ (relay: String, findEventsRequest: FindEventsRequest) in
                // Only requests that have .authors > 0
                // Requests can have multiple filters, we can count the authors on just the first one, all others should be the same (for THIS relay)
                findEventsRequest.pubkeys.count > 0
                
            })
            .sorted(by: {
                $0.value.pubkeys.count > $1.value.pubkeys.count
            }) {
            
            print("🟩 SENDING-- \(req.value.pubkeys.count): \(req.key) - \(req.value.filters.description)")
        }
    }
    
}
