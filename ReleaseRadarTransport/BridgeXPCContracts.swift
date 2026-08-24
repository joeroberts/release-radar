import Foundation
import Security

enum ReleaseRadarBridgeTransport {
    static let wireVersion = 2
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
