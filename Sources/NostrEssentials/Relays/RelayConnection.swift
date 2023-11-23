//
//  File.swift
//  
//
//  Created by Fabian Lachman on 23/11/2023.
//

import Foundation
import Combine
import CombineWebSocket

// Multiple relay connections (RelayConnection) are added to the connection pool (see ConnectionPool)
// Your app should implement RelayConnectionDelegate to handle responses from the relays.

public protocol RelayConnectionDelegate {
    func didConnect(_ url:String)
    
    func didReceiveMessage(_ url:String, message:String)
    
    func didDisconnect(_ url:String)
    
    func didDisconnectWithError(_ url:String, error:Error)
}

struct SocketMessage {
    let id = UUID()
    let text:String
}

public class RelayConnection: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    
    // for views (viewContext)
    @Published private(set) var isConnected = false { // don't set directly, set isDeviceConnected or isSocketConnected
        didSet {
            pool.objectWillChange.send()
        }
    }
    
    // other (should use queue: "connection-pool"
    public var url:String { relayConfig.id }
    public var nreqSubscriptions:Set<String> = []
    
    public var lastMessageReceivedAt:Date? = nil
    private var exponentialReconnectBackOff = 0
    private var skipped:Int = 0
    
    
    public var relayConfig:RelayConfig
    private var session:URLSession?
    private var queue:DispatchQueue
    private var webSocket:WebSocket?
    private var webSocketSub:AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var outQueue:[SocketMessage] = []
    private var delegate:RelayConnectionDelegate
    private var pool:ConnectionPool
    
    
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
    
    public func connect(andSend:String? = nil, forceConnectionAttempt:Bool = false) {
        queue.async(flags: .barrier) { [weak self] in
            print("\(Date()): 3: on thread \(Thread.current) \(andSend ?? "??")")
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
            
//            self.webSocketSub?.cancel() // .cancel() gives Data race? Maybe not even needed.
            self.webSocketSub = nil
            
            self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            
            if let urlURL = URL(string: relayConfig.url) {
                let urlRequest = URLRequest(url: urlURL)
                self.webSocket = session?.webSocket(with: urlRequest)
            }
            
            guard let webSocket = webSocket else {
                self.isSocketConnecting = false
                return
            }
            
            // Subscribe to the WebSocket. This will connect to the remote server and start listening
            // for messages (URLSessionWebSocketTask.Message).
            // URLSessionWebSocketTask.Message is an enum for either Data or String
            self.webSocketSub = webSocket.publisher
                .receive(on: queue)
                .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.didDisconnect()
                    case .failure(let error):
                        self?.didDisconnectWithError(error)
                    }
                },
                receiveValue: { [weak self] message in
                    switch message {
                    case .data(let data):
                        // Handle Data message
                        self?.didReceiveData(data)
                    case .string(let string):
                        // Handle String message
                        self?.didReceiveMessage(string)
                    @unknown default:
                        _ = ""
                    }
                })
            
            if self.exponentialReconnectBackOff >= 512 {
                self.exponentialReconnectBackOff = 512
            }
            else {
                self.exponentialReconnectBackOff = max(1, self.exponentialReconnectBackOff * 2)
            }
            
            guard !outQueue.isEmpty && self.isConnected else { return }
            for out in outQueue {
                webSocket.send(out.text)
                    .subscribe(Subscribers.Sink(
                        receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.queue.async(flags: .barrier) {
                                    self?.outQueue.removeAll(where: { $0.id == out.id })
                                }
                            case .failure(let error):
                                _ = ""
                            }
                        },
                        receiveValue: { _ in }
                    ))
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
            
            if self.webSocket == nil || !self.isSocketConnected {
                return
            }
            self.webSocket?.send(text)
                .subscribe(Subscribers.Sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            self.queue.async(flags: .barrier) {
                                self.outQueue.removeAll(where: { $0.id == socketMessage.id })
                            }
                        case .failure(let error):
                            _ = ""
                        }
                    },
                    receiveValue: { _ in }
                ))
        }
    }
    
    public func sendMessageAfterPing(_ text:String) {
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                if !self.isDeviceConnected { return }
                guard let webSocket = self.webSocket else { return }
                let socketMessage = SocketMessage(text: text)
                self.outQueue.append(socketMessage)
    
                webSocket.ping()
                    .subscribe(Subscribers.Sink(
                        receiveCompletion: { [weak self] completion in
                            guard let self = self else { return }
                            switch completion {
                            case .failure(let error):
                                // Handle the failure case
                                self.connect(andSend:text)
                            case .finished:
                                // The ping completed successfully
                                webSocket.send(text)
                                    .subscribe(Subscribers.Sink(
                                        receiveCompletion: { [weak self] completion in
                                            switch completion {
                                            case .finished:
                                                self?.queue.async(flags: .barrier) {
                                                    self?.outQueue.removeAll(where: { $0.id == socketMessage.id })
                                                }
                                            case .failure(let error):
                                                _ = ""
                                            }
                                        },
                                        receiveValue: { _ in }
                                    ))
                            }
                        },
                        receiveValue: { _ in }
                    ))
            }
        }
    
    
    public func disconnect() {
        queue.async(flags: .barrier) {
            self.nreqSubscriptions = []
            self.lastMessageReceivedAt = nil
            self.isSocketConnected = false
            self.webSocketSub = nil
        }
    }
    
    public func ping() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let webSocket = self.webSocket else { return }

            webSocket.ping()
                .subscribe(Subscribers.Sink(
                    receiveCompletion: { [weak self] completion in
                        switch completion {
                        case .failure(let error):
                            // Handle the failure case
                            let _url = self?.url ?? ""
                            let _error = error
                            self?.connect()
                        case .finished:
                            // The ping completed successfully
                            let _url = self?.url ?? ""
                            self?.didReceivePong()
                        }
                    },
                    receiveValue: { _ in }
                ))
        }
    }
    
    // -- MARK: URLSessionWebSocketDelegate
    
    func didReceiveData(_ data:Data) {
        if self.isSocketConnecting {
            self.isSocketConnecting = false
        }
        if !self.isSocketConnected {
            self.isSocketConnected = true
        }
        self.lastMessageReceivedAt = .now
    }
    
    // wil call delegate.didReceiveMessage
    func didReceiveMessage(_ text:String) {
        if self.isSocketConnecting {
            self.isSocketConnecting = false
        }
        if !self.isSocketConnected {
            self.isSocketConnected = true
        }
        self.lastMessageReceivedAt = .now
        let url = self.url
        DispatchQueue.main.async {
            self.delegate.didReceiveMessage(url, message: text)
        }
    }
    
    func didReceivePong() {
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
    
    // will call delegate.didConnect
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async(flags: .barrier) {
            self.nreqSubscriptions = []
            self.exponentialReconnectBackOff = 0
            self.skipped = 0
            self.lastMessageReceivedAt = .now
            self.isSocketConnected = true
            let url = self.url

            DispatchQueue.main.async {
                self.delegate.didConnect(url)
            }
            
            guard !self.outQueue.isEmpty else { return }
            for out in self.outQueue {
                self.webSocket?.send(out.text)
                    .subscribe(Subscribers.Sink(
                        receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.queue.async(flags: .barrier) {
                                    self?.outQueue.removeAll(where: { $0.id == out.id })
                                }
                            case .failure(let error):
                                _ = ""
                            }
                        },
                        receiveValue: { _ in }
                    ))
            }
        }
    }
    
    // will call delegate.didDisconnect
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async(flags: .barrier) {
            self.nreqSubscriptions = []
            self.exponentialReconnectBackOff = 0
            self.skipped = 0
            self.lastMessageReceivedAt = .now
            self.isSocketConnected = false
            self.webSocketSub = nil
            let url = self.url
            DispatchQueue.main.async {
                self.delegate.didDisconnect(url)
            }
        }

    }
    
    private func didDisconnect() {
        queue.async(flags: .barrier) {
            self.nreqSubscriptions = []
            self.lastMessageReceivedAt = nil
            self.isSocketConnected = false
            self.webSocketSub = nil
            let url = self.url
            DispatchQueue.main.async {
                self.delegate.didDisconnect(url)
            }
        }
    }
    
    private func didDisconnectWithError(_ error: Error) {
        queue.async(flags: .barrier) {
            self.nreqSubscriptions = []
            self.lastMessageReceivedAt = nil
            if self.exponentialReconnectBackOff >= 512 {
                self.exponentialReconnectBackOff = 512
            }
            else {
                self.exponentialReconnectBackOff = max(1, self.exponentialReconnectBackOff * 2)
            }
            self.isSocketConnected = false
            self.webSocketSub = nil
            let url = self.url
            DispatchQueue.main.async {
                self.delegate.didDisconnectWithError(url, error: error)
            }
        }
    }
}

