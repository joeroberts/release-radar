import Foundation
import Security

enum ReleaseRadarBridgeTransport {
    static let wireVersion = 3
    static let commandEnvelopeVersion = 1
    static let maximumEnvelopeBytes = 131_072
    static let maximumLineBytes = 196_608
    static let maximumDeadlineInterval: TimeInterval = 15

    static let appMachService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.app"
    static let toolsMachService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.bridge.tools"
    static let launchAgentPlistName = "com.rekonlabs.ReleaseRadar.BridgeAgent.plist"

    static let appRequirement = validatedRequirement(
        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadar\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
    )
    static let toolsRequirement = validatedRequirement(
        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarAgentTools\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
    )
    static let brokerRequirement = validatedRequirement(
        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarBridgeAgent\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
    )
    static let coordinatorRequirement = validatedRequirement(
        "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarCoordinator\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
    )
    static let appOrCoordinatorRequirement = validatedRequirement(
        "anchor apple generic and (identifier \"com.rekonlabs.ReleaseRadar\" or identifier \"com.rekonlabs.ReleaseRadarCoordinator\") and certificate leaf[subject.OU] = \"2UA854NLX4\""
    )

    // Listener admission pins the actual connection first. This check selects
    // its narrow interface; the connection is then pinned to that identity too.
    static func peerMatches(_ connection: NSXPCConnection, requirement text: String) -> Bool {
        var requirement: SecRequirement?
        var code: SecCode?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let requirement,
              SecCodeCopyGuestWithAttributes(nil,
                [kSecGuestAttributePid as String: NSNumber(value: connection.processIdentifier)] as CFDictionary,
                [], &code) == errSecSuccess, let code else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    static func envelopeVersion(in data: Data) -> Int? {
        guard data.count <= maximumEnvelopeBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = exactJSONInteger(object["version"])
        else { return nil }
        return version
    }

    static func exactJSONInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              var decimal = Decimal(
                string: number.stringValue,
                locale: Locale(identifier: "en_US_POSIX")
              ),
              !NSDecimalIsNotANumber(&decimal)
        else { return nil }

        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 0, .plain)
        guard rounded == decimal else { return nil }

        let int64 = number.int64Value
        guard Decimal(int64) == decimal else { return nil }
        return Int(exactly: int64)
    }

    static func appUnavailableResultData() -> Data {
        resultData(error: ["appUnavailable": [:]])
    }

    static func outcomeUnknownResultData() -> Data {
        resultData(error: ["outcomeUnknown": [:]])
    }

    static func unsupportedVersionResultData(found: Int) -> Data {
        resultData(error: [
            "unsupportedVersion": ["found": found, "supported": commandEnvelopeVersion],
        ])
    }

    private static func validatedRequirement(_ text: String) -> String? {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              requirement != nil
        else { return nil }
        return text
    }

    private static func resultData(error: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: [
            "entityIDs": [],
            "error": error,
        ])) ?? Data()
    }
}

enum BridgeHandshakeStage: String, Codable, Equatable, Sendable { case connection, handshake }
enum BridgeHandshakeEvent: Equatable, Sendable {
    case reply(version: Int), timedOut(stage: BridgeHandshakeStage)
    case transportFailure(stage: BridgeHandshakeStage), invalidProtocolResponse(stage: BridgeHandshakeStage)
}
enum BridgeHandshakeResult: Equatable, Sendable {
    case compatible(wireVersion: Int), incompatible(expectedVersion: Int, observedPeerVersion: Int?)
    case timeout(stage: BridgeHandshakeStage), transportFailure(stage: BridgeHandshakeStage)
    case invalidProtocolResponse(stage: BridgeHandshakeStage)
}

final class BridgeHandshakeSettler: @unchecked Sendable {
    private let lock = NSLock(); private let expectedWireVersion: Int; private var result: BridgeHandshakeResult?
    init(expectedWireVersion: Int) { self.expectedWireVersion = expectedWireVersion }
    func settle(_ event: BridgeHandshakeEvent) -> BridgeHandshakeResult {
        lock.lock(); defer { lock.unlock() }
        if let result { return result }
        let resolved: BridgeHandshakeResult
        switch event {
        case let .reply(version) where version == expectedWireVersion: resolved = .compatible(wireVersion: version)
        case let .reply(version): resolved = .incompatible(expectedVersion: expectedWireVersion, observedPeerVersion: version == 0 ? nil : version)
        case let .timedOut(stage): resolved = .timeout(stage: stage)
        case let .transportFailure(stage): resolved = .transportFailure(stage: stage)
        case let .invalidProtocolResponse(stage): resolved = .invalidProtocolResponse(stage: stage)
        }
        result = resolved; return resolved
    }
}

struct BridgeConnectionHealth: Codable, Equatable, Sendable {
    let wireVersion: Int
    let isRegisteredAppConnection: Bool
    let lastAuthenticatedToolsContact: Date?
}

@objc(ReleaseRadarToolsBrokerXPC)
protocol ReleaseRadarToolsBrokerXPC {
    func handshake(_ version: Int, withReply reply: @escaping (Int) -> Void)
    func forward(
        _ wireVersion: Int,
        envelope: Data,
        admissionDeadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    )
}

@objc(ReleaseRadarAppBrokerXPC)
protocol ReleaseRadarAppBrokerXPC {
    func registerApp(_ wireVersion: Int, withReply reply: @escaping (Int) -> Void)
    func registerContextEndpoint(_ wireVersion: Int, endpoint: NSXPCListenerEndpoint,
                                withReply reply: @escaping (Int) -> Void)
    func connectionHealth(_ wireVersion: Int, withReply reply: @escaping (Data) -> Void)
}

// Coordinator's broker connection cannot register RR or forward commands.
@objc(ReleaseRadarContextDiscoveryXPC)
protocol ReleaseRadarContextDiscoveryXPC {
    func contextEndpoint(_ wireVersion: Int, withReply reply: @escaping (NSXPCListenerEndpoint?) -> Void)
}

@objc(ReleaseRadarAppCallbackXPC)
protocol ReleaseRadarAppCallbackXPC {
    func dispatch(
        _ wireVersion: Int,
        envelope: Data,
        admissionDeadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    )
}
