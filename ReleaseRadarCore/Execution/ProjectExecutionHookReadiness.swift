import Foundation

/// Exact installed 0.154 App Server hook shape; unsupported shapes fail readiness.
public struct ProjectExecutionHookReadiness: Sendable {
    public let key: String
    public let currentHash: String
    public let trustStatus: String

    public static func resolve(_ data: Data, checkout: String, primaryRoot: String,
                               command: String, requireTrusted: Bool, inline: Bool = false) throws -> Self {
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = result["data"] as? [[String: Any]],
              let entry = entries.first(where: { $0["cwd"] as? String == checkout }),
              let errors = entry["errors"] as? [Any], errors.isEmpty,
              let warnings = entry["warnings"] as? [String], warnings.isEmpty,
              let hooks = entry["hooks"] as? [[String: Any]] else { throw ProjectExecutionError.hookNotReady }
        let candidates = hooks.filter {
            $0["source"] as? String == "project" && $0["sourcePath"] as? String == primaryRoot + (inline ? "/.codex/config.toml" : "/.codex/hooks.json")
                && $0["eventName"] as? String == "userPromptSubmit" && $0["command"] as? String == command
                && $0["handlerType"] as? String == "command" && ($0["async"] as? Bool ?? false) == false
        }
        guard candidates.count == 1, let hook = candidates.first,
              hook["enabled"] as? Bool == true, hook["timeoutSec"] as? Int == 10,
              let key = hook["key"] as? String, !key.isEmpty,
              let hash = hook["currentHash"] as? String, !hash.isEmpty,
              let trust = hook["trustStatus"] as? String,
              ["trusted", "untrusted"].contains(trust), !requireTrusted || trust == "trusted"
        else { throw ProjectExecutionError.hookNotReady }
        return .init(key: key, currentHash: hash, trustStatus: trust)
    }

    public var trustEdit: [String: Any] {
        ["keyPath": "hooks.state", "mergeStrategy": "upsert", "value": [key: ["trusted_hash": currentHash]]]
    }
}
