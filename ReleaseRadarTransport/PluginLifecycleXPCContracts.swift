import Foundation
import ReleaseRadarCore

enum ReleaseRadarPluginLifecycleTransport {
    static let wireVersion = 1
    static let maximumReplyBytes = 65_536
    static let maximumOutputBytes = 1_048_576
    static let operationTimeout: TimeInterval = 15
    static let machService = "2UA854NLX4.com.rekonlabs.ReleaseRadar.plugin-lifecycle"
    static let launchAgentPlistName = "com.rekonlabs.ReleaseRadar.PluginLifecycleHelper.plist"
    static let packagedAgentToolsPath = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools"

    static let helperRequirement = "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadarPluginLifecycleHelper\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
    static let appRequirement = "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadar\" and certificate leaf[subject.OU] = \"2UA854NLX4\""

    static func encode(_ reply: CodexPluginHelperReply) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(reply)
        guard data.count <= maximumReplyBytes else { throw CodexPluginLifecycleError.outputOverflow }
        return data
    }

    static func decode(_ data: Data) throws -> CodexPluginHelperReply {
        guard data.count <= maximumReplyBytes else { throw CodexPluginLifecycleError.outputOverflow }
        let decoder = JSONDecoder()
        let reply = try decoder.decode(CodexPluginHelperReply.self, from: data)
        guard reply.wireVersion == wireVersion else { throw CodexPluginLifecycleError.malformedResult }
        return reply
    }

    static func isRecognizedDirectEntry(_ entry: CodexMCPEntry) -> Bool {
        isRecognized(entry, expectedName: "release_radar")
    }

    static func isRecognizedLegacyEntry(_ entry: CodexMCPEntry) -> Bool {
        isRecognized(entry, expectedName: "release-radar")
    }

    private static func isRecognized(_ entry: CodexMCPEntry, expectedName: String) -> Bool {
        entry.name == expectedName
            && entry.enabled
            && entry.disabledReason == nil
            && entry.command == packagedAgentToolsPath
            && entry.arguments.isEmpty
            && entry.environment.isEmpty
            && entry.workingDirectory == nil
    }

    static func isExactAbsence(
        name: String,
        exitStatus: Int32,
        stdout: Data,
        stderr: Data
    ) -> Bool {
        exitStatus == 1
            && stdout.isEmpty
            && stderr == Data("Error: No MCP server named '\(name)' found.\n".utf8)
    }
}

struct CodexMCPEntry: Equatable, Sendable {
    let name: String
    let enabled: Bool
    let disabledReason: String?
    let command: String
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: String?
}

@objc(ReleaseRadarPluginLifecycleXPC)
protocol ReleaseRadarPluginLifecycleXPC {
    func status(withReply reply: @escaping (Data) -> Void)
    func install(withReply reply: @escaping (Data) -> Void)
    func remove(withReply reply: @escaping (Data) -> Void)
    func reinstall(withReply reply: @escaping (Data) -> Void)
}
