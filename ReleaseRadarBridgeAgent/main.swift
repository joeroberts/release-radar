import Darwin
import Foundation

private final class BridgeBrokerState: @unchecked Sendable {
    private let lock = NSLock()
    private var appConnection: NSXPCConnection?

    func registerApp(_ connection: NSXPCConnection) {
        lock.lock()
        appConnection = connection
        lock.unlock()
    }

    func removeApp(_ connection: NSXPCConnection) {
        lock.lock()
        if appConnection === connection {
            appConnection = nil
        }
        lock.unlock()
    }

    func forward(
        version: Int,
        envelope: Data,
        deadline: TimeInterval,
        reply: @escaping (Data) -> Void
    ) {
        guard version == ReleaseRadarBridgeTransport.version,
              envelope.count <= ReleaseRadarBridgeTransport.maximumEnvelopeBytes,
              deadline > Date().timeIntervalSince1970,
              deadline - Date().timeIntervalSince1970 <= ReleaseRadarBridgeTransport.maximumDeadlineInterval
        else {
            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
            return
        }
        guard let envelopeVersion = ReleaseRadarBridgeTransport.envelopeVersion(in: envelope) else {
            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
            return
        }
        guard envelopeVersion == ReleaseRadarBridgeTransport.version else {
            reply(ReleaseRadarBridgeTransport.unsupportedVersionResultData(found: envelopeVersion))
            return
        }

        lock.lock()
        let connection = appConnection
        lock.unlock()
        guard let connection else {
            reply(ReleaseRadarBridgeTransport.appUnavailableResultData())
            return
        }

        let once = BridgeReplyOnce(reply)
        let delay = max(0, deadline - Date().timeIntervalSince1970)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
        }
        guard let callback = connection.remoteObjectProxyWithErrorHandler({ _ in
            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
        }) as? ReleaseRadarAppCallbackXPC else {
            once.send(ReleaseRadarBridgeTransport.appUnavailableResultData())
            return
        }
        callback.dispatch(version, envelope: envelope, deadline: deadline) { data in
            once.send(data)
        }
    }
}

private final class ToolsEndpoint: NSObject, ReleaseRadarToolsBrokerXPC, @unchecked Sendable {
    private let state: BridgeBrokerState

    init(state: BridgeBrokerState) {
        self.state = state
    }

    func handshake(_ version: Int, withReply reply: @escaping (Int) -> Void) {
        reply(version == ReleaseRadarBridgeTransport.version ? ReleaseRadarBridgeTransport.version : 0)
    }

    func forward(
        _ version: Int,
        envelope: Data,
        deadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    ) {
        state.forward(version: version, envelope: envelope, deadline: deadline, reply: reply)
    }
}

private final class AppEndpoint: NSObject, ReleaseRadarAppBrokerXPC, @unchecked Sendable {
    private let state: BridgeBrokerState
    private let connection: NSXPCConnection

    init(state: BridgeBrokerState, connection: NSXPCConnection) {
        self.state = state
        self.connection = connection
    }

    func registerApp(_ version: Int, withReply reply: @escaping (Int) -> Void) {
        guard version == ReleaseRadarBridgeTransport.version else {
            reply(0)
            return
        }
        state.registerApp(connection)
        reply(ReleaseRadarBridgeTransport.version)
    }
}

private final class ToolsListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let state: BridgeBrokerState

    init(state: BridgeBrokerState) {
        self.state = state
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid(),
              let requirement = ReleaseRadarBridgeTransport.toolsRequirement
        else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarToolsBrokerXPC.self)
        connection.exportedObject = ToolsEndpoint(state: state)
        connection.resume()
        return true
    }
}

private final class AppListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let state: BridgeBrokerState

    init(state: BridgeBrokerState) {
        self.state = state
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == getuid(),
              let requirement = ReleaseRadarBridgeTransport.appRequirement
        else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: ReleaseRadarAppCallbackXPC.self)
        connection.exportedInterface = NSXPCInterface(with: ReleaseRadarAppBrokerXPC.self)
        connection.exportedObject = AppEndpoint(state: state, connection: connection)
        connection.invalidationHandler = { [state, weak connection] in
            guard let connection else { return }
            state.removeApp(connection)
        }
        connection.resume()
        return true
    }
}

private final class BridgeReplyOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var reply: ((Data) -> Void)?

    init(_ reply: @escaping (Data) -> Void) {
        self.reply = reply
    }

    func send(_ data: Data) {
        lock.lock()
        let callback = reply
        reply = nil
        lock.unlock()
        callback?(data)
    }
}

private let brokerState = BridgeBrokerState()
private let toolsDelegate = ToolsListenerDelegate(state: brokerState)
private let appDelegate = AppListenerDelegate(state: brokerState)
private let toolsListener = NSXPCListener(machServiceName: ReleaseRadarBridgeTransport.toolsMachService)
private let appListener = NSXPCListener(machServiceName: ReleaseRadarBridgeTransport.appMachService)
toolsListener.delegate = toolsDelegate
appListener.delegate = appDelegate
toolsListener.resume()
appListener.resume()
RunLoop.current.run()
