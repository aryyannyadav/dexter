//
//  DexterHubWebSocketServer.swift
//  leanring-buddy
//
//  Lightweight local WebSocket server for Dexter Hub tablets (ws://<mac-ip>:8787/hub).
//

import Foundation
import Network

final class DexterHubWebSocketServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DexterHubWebSocketServer", qos: .utility)
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let connectionsLock = NSLock()
    var inboundPayloadHandler: (([String: Any]) -> Void)?

    var isRunning: Bool { listener != nil }

    func start(port: UInt16 = 8787) {
        queue.async { [weak self] in
            self?.startOnQueue(port: port)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.connectionsLock.lock()
            for (_, connection) in self.connections {
                connection.cancel()
            }
            self.connections.removeAll()
            self.connectionsLock.unlock()
            self.listener?.cancel()
            self.listener = nil
            DexterHubEventBridgeLog.info("WebSocket server stopped")
        }
    }

    func broadcast(data: Data) {
        guard !data.isEmpty else { return }
        queue.async { [weak self] in
            self?.broadcastOnQueue(data: data)
        }
    }

    private func startOnQueue(port: UInt16) {
        guard listener == nil else { return }

        guard let portValue = NWEndpoint.Port(rawValue: port) else {
            DexterHubEventBridgeLog.info("invalid port \(port)")
            return
        }

        let webSocketOptions = NWProtocolWebSocket.Options()
        webSocketOptions.autoReplyPing = true

        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)

        do {
            listener = try NWListener(using: parameters, on: portValue)
        } catch {
            DexterHubEventBridgeLog.info("WebSocket server failed to start: \(error.localizedDescription)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                DexterHubEventBridgeLog.info("WebSocket server started on port \(port)")
            case .failed(let error):
                DexterHubEventBridgeLog.info("WebSocket server failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.accept(connection: connection)
        }

        listener?.start(queue: queue)
    }

    private func accept(connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DexterHubEventBridgeLog.info("Hub connected")
                self?.sendInitialIdle(on: connection)
                self?.receiveNextMessage(on: connection)
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connectionsLock.lock()
        connections[ObjectIdentifier(connection)] = connection
        connectionsLock.unlock()
        connection.start(queue: queue)
    }

    private func removeConnection(_ connection: NWConnection) {
        connectionsLock.lock()
        connections.removeValue(forKey: ObjectIdentifier(connection))
        connectionsLock.unlock()
        DexterHubEventBridgeLog.info("Hub disconnected")
    }

    private func sendInitialIdle(on connection: NWConnection) {
        let payload = DexterHubWireEventBuilder.state(
            hubState: "idle",
            title: "hey, I'm here.",
            subtitle: "your digital companion"
        )
        send(data: payload, on: connection)
    }

    private func broadcastOnQueue(data: Data) {
        connectionsLock.lock()
        let activeConnections = Array(connections.values)
        connectionsLock.unlock()
        for connection in activeConnections {
            send(data: data, on: connection)
        }
    }

    private func send(data: Data, on connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        connection.send(
            content: data,
            contentContext: NWConnection.ContentContext(identifier: "dexter-hub-event", metadata: [metadata]),
            isComplete: true,
            completion: .contentProcessed { _ in }
        )
    }

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, _, error in
            if error != nil {
                connection.cancel()
                return
            }

            if let content, !content.isEmpty {
                self?.handleInboundMessage(data: content)
            }

            if connection.state == .ready {
                self?.receiveNextMessage(on: connection)
            }
        }
    }

    private func handleInboundMessage(data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let inboundPayloadHandler {
            inboundPayloadHandler(object)
            return
        }

        if object["type"] as? String == "teachingStyle",
           let styleIdentifier = object["style"] as? String {
            DexterHubTeachingStylePreferenceStore.applyHubStyleIdentifier(styleIdentifier)
            DexterHubEventBridgeLog.info("teachingStyle=\(styleIdentifier) (applies to next teaching turn)")
            return
        }

        guard object["type"] as? String == "command" else {
            return
        }
        DexterHubEventBridgeLog.info("command received (presentation-only — approve on Mac)")
    }
}
