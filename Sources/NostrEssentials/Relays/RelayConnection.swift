//
//  File.swift
//  
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation
import Combine

// Multiple relay connections (RelayConnection) are added to the connection pool (see ConnectionPool)
// Your app should implement RelayConnectionDelegate to handle responses from the relays.

public protocol RelayConnectionDelegate {
    func didConnect(_ url: String)
    
    func didReceiveMessage(_ url: String, message: String)
    
    func didDisconnect(_ url: String)
    
    func didDisconnectWithError(_ url: String, error: Error)
}

struct SocketMessage {
    let id = UUID()
    let text: String
}

public class RelayConnection: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    
    // for views (viewContext)
    @Published private(set) var isConnected = false { // don't set directly, set isDeviceConnected or isSocketConnected
        didSet {
            pool.objectWillChange.send()
        }
    }
    
    // other (should use queue: "connection-pool"
    public var url: String { relayConfig.id }
    public var nreqSubscriptions: Set<String> = []
    
    public var lastMessageReceivedAt: Date? = nil
    private var exponentialReconnectBackOff = 0
    private var skipped: Int = 0
    
    
    public var relayConfig: RelayConfig
    private var session: URLSession?
    private var queue: DispatchQueue
    private var webSocketTask: URLSessionWebSocketTask?
    private var subscriptions = Set<AnyCancellable>()
    private var outQueue: [SocketMessage] = []
    private var delegate: RelayConnectionDelegate
    private var pool: ConnectionPool
    
    
    private var isDeviceConnected = false {
        didSet {
            if !isDeviceConnected {
                isSocketConnecting = false
                isSocketConnected = false
                Task { @MainActor in
                    self.objectWillChange.send()
                    self.isConnected = false
                }
            }
        }
    }
    
    public var isSocketConnecting = false
    
    public var isSocketConnected = false {
        didSet {
            isSocketConnecting = false
            let isSocketConnected = isSocketConnected
            Task { @MainActor in
                self.objectWillChange.send()
                self.isConnected = isSocketConnected
            }
        }
    }
    
    init(_ relayConfig: RelayConfig, queue: DispatchQueue, delegate: RelayConnectionDelegate, pool: ConnectionPool) {
        self.relayConfig = relayConfig
        self.queue = queue
        self.delegate = delegate
        self.pool = pool
        self.isDeviceConnected = NetworkMonitor.shared.isConnected
        super.init()
        
        NetworkMonitor.shared.isConnectedSubject
            .receive(on: self.queue)
            .sink { isNowConnected in
                let fromDisconnectedToConnected = !self.isDeviceConnected && isNowConnected
                let fromConnectedToDisconnected = self.isDeviceConnected && !isNowConnected
                if self.isDeviceConnected != isNowConnected {
                    self.queue.async(flags: .barrier) {
                        self.isDeviceConnected = isNowConnected
                    }
                }
                if (fromDisconnectedToConnected) {
                    if self.relayConfig.write || self.relayConfig.read {
                        self.connect(forceConnectionAttempt: true)
                    }
                }
                else if fromConnectedToDisconnected {
                    if self.relayConfig.write || self.relayConfig.read {
                        self.disconnect()
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    public func connect(andSend: String? = nil, forceConnectionAttempt: Bool = false) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            guard self.isDeviceConnected else { return }
            guard !self.isSocketConnecting else { return }
            self.nreqSubscriptions = []
            self.isSocketConnecting = true
            
            guard self.exponentialReconnectBackOff > 512 || self.exponentialReconnectBackOff == 1 || forceConnectionAttempt || self.skipped == self.exponentialReconnectBackOff else { // Should be 0 == 0 to continue, or 2 == 2 etc..
                self.skipped = self.skipped + 1
                self.isSocketConnecting = false
                return
            }
            self.skipped = 0

            if let andSend = andSend {
                self.outQueue.append(SocketMessage(text: andSend))
            }
            
            self.session?.invalidateAndCancel()
            self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            
            if let url = URL(string: relayConfig.url) {
                let urlRequest = URLRequest(url: url)
                self.webSocketTask = self.session?.webSocketTask(with: urlRequest)
                self.webSocketTask?.delegate = self
            }
            
            self.webSocketTask?.resume()
            
            if self.exponentialReconnectBackOff >= 512 {
                self.exponentialReconnectBackOff = 512
            }
            else {
                self.exponentialReconnectBackOff = max(1, self.exponentialReconnectBackOff * 2)
            }
            
            guard let webSocketTask = self.webSocketTask, !outQueue.isEmpty else { return }
            
            for out in outQueue {
                webSocketTask.send(.string(out.text)) { error in
                    if let error {
                        self.didReceiveError(error)
                    }
                }
                self.outQueue.removeAll(where: { $0.id == out.id })
            }
        }
    }
    
    public func sendMessage(_ text:String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if !self.isDeviceConnected {
                return
            }
            
            let socketMessage = SocketMessage(text: text)
            self.outQueue.append(socketMessage)
            
            guard let webSocketTask = self.webSocketTask, !outQueue.isEmpty else { return }
            
            for out in outQueue {
                webSocketTask.send(.string(out.text)) { error in
                    if let error {
                        self.didReceiveError(error)
                    }
                }
                self.outQueue.removeAll(where: { $0.id == out.id })
            }
        }
    }
       
    public func disconnect() {
        queue.async(flags: .barrier) { [weak self] in
            self?.nreqSubscriptions = []
            self?.lastMessageReceivedAt = nil
            self?.isSocketConnected = false
            self?.exponentialReconnectBackOff = 0
            self?.skipped = 0
            self?.webSocketTask?.cancel()
            self?.session?.invalidateAndCancel()
        }
    }
    
    public func ping() {
        queue.async { [weak self] in
            if self?.webSocketTask == nil { return }
            self?.webSocketTask?.sendPing(pongReceiveHandler: { error in
                if error != nil { }
                else {
                    self?.didReceivePong()
                }
            })
        }
    }
    
    // -- MARK: URLSessionWebSocketDelegate
    
    func didReceiveData(_ data: Data) {
        if self.isSocketConnecting {
            self.isSocketConnecting = false
        }
        if !self.isSocketConnected {
            self.isSocketConnected = true
        }
        self.lastMessageReceivedAt = .now
    }
    
    // wil call delegate.didReceiveMessage
    func didReceiveMessage(string: String) {
        if self.isSocketConnecting {
            self.isSocketConnecting = false
        }
        if !self.isSocketConnected {
            self.isSocketConnected = true
        }
        self.lastMessageReceivedAt = .now
        let url = self.url
        DispatchQueue.main.async {
            self.delegate.didReceiveMessage(url, message: string)
        }
    }
    
    public func didReceiveMessage(data: Data) {
        // Respond to a WebSocket connection receiving a binary `Data` message
        if self.isSocketConnecting {
            self.isSocketConnecting = false
        }
        if !self.isSocketConnected {
            self.isSocketConnected = true
        }
        self.lastMessageReceivedAt = .now
    }
    
    public func didReceivePong() {
        queue.sync(flags: .barrier) {
            if self.isSocketConnecting {
                self.isSocketConnecting = false
            }
            if !self.isSocketConnected {
                self.isSocketConnected = true
            }
            self.lastMessageReceivedAt = .now
        }
    }
    
    public func didReceiveError(_ error: Error) {
        // Respond to a WebSocket error event
        queue.async(flags: .barrier) { [weak self] in
            self?.webSocketTask?.cancel()
            self?.session?.invalidateAndCancel()
            self?.nreqSubscriptions = []
            self?.lastMessageReceivedAt = nil
            if (self?.exponentialReconnectBackOff ?? 0) >= 512 {
                self?.exponentialReconnectBackOff = 512
            }
            else {
                self?.exponentialReconnectBackOff = max(1, (self?.exponentialReconnectBackOff ?? 0) * 2)
            }
            self?.isSocketConnected = false
            if let url = self?.url {
                DispatchQueue.main.async {
                    self?.delegate.didDisconnectWithError(url, error: error)
                }
            }
        }
    }
    
    // will call delegate.didConnect
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.startReceiving()
            self.nreqSubscriptions = []
            self.exponentialReconnectBackOff = 0
            self.skipped = 0
            self.lastMessageReceivedAt = .now
            self.isSocketConnected = true
            let url = self.url
            DispatchQueue.main.async {
                self.delegate.didConnect(url)
            }

            guard let webSocketTask = self.webSocketTask, !outQueue.isEmpty else { return }
            
            for out in outQueue {
                webSocketTask.send(.string(out.text)) { error in
                    
                }
                self.outQueue.removeAll(where: { $0.id == out.id })
            }
        }
    }
    
    // will call delegate.didDisconnect
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        
        queue.async(flags: .barrier) { [weak self] in
            self?.session?.invalidateAndCancel()
            self?.nreqSubscriptions = []
            self?.exponentialReconnectBackOff = 0
            self?.skipped = 0
            self?.lastMessageReceivedAt = .now
            self?.isSocketConnected = false
            if let url = self?.url {
                DispatchQueue.main.async {
                    self?.delegate.didDisconnect(url)
                }
            }
        }
    }
    
    private func startReceiving() {
        self.webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
                case .success(let message):
                    switch message {
                        case .data(let data):
                            self.didReceiveMessage(data: data)
                        case .string(let text):
                            self.didReceiveMessage(string: text)
                        @unknown default:
                            break
                    }
                    self.startReceiving()
                case .failure(let error):
                    self.didReceiveError(error)
                }
        }
    }
    
}

