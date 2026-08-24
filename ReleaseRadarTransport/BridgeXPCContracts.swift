import Foundation
import Security

enum ReleaseRadarBridgeTransport {
    static let version = 1
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

    static func envelopeVersion(in data: Data) -> Int? {
        guard data.count <= maximumEnvelopeBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = object["version"] as? NSNumber
        else { return nil }
        return number.intValue
    }

    static func appUnavailableResultData() -> Data {
        resultData(error: ["appUnavailable": [:]])
    }

    static func unsupportedVersionResultData(found: Int) -> Data {
        resultData(error: [
            "unsupportedVersion": ["found": found, "supported": version],
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

@objc(ReleaseRadarToolsBrokerXPC)
protocol ReleaseRadarToolsBrokerXPC {
    func handshake(_ version: Int, withReply reply: @escaping (Int) -> Void)
    func forward(
        _ version: Int,
        envelope: Data,
        deadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    )
}

@objc(ReleaseRadarAppBrokerXPC)
protocol ReleaseRadarAppBrokerXPC {
    func registerApp(_ version: Int, withReply reply: @escaping (Int) -> Void)
}

@objc(ReleaseRadarAppCallbackXPC)
protocol ReleaseRadarAppCallbackXPC {
    func dispatch(
        _ version: Int,
        envelope: Data,
        deadline: TimeInterval,
        withReply reply: @escaping (Data) -> Void
    )
}
