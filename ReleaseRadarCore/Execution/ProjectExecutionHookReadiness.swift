import Darwin
import Foundation
import OSLog

/// Exact installed 0.154 App Server hook shape; unsupported shapes fail readiness.
public struct ProjectExecutionHookReadiness: Sendable {
    public let key: String
    public let currentHash: String
    public let trustStatus: String

    /// Preserve filesystem spelling for Codex's source identity (including /var).
    public static func canonicalPrimaryRoot(_ primaryRoot: String) throws -> String {
        guard primaryRoot.hasPrefix("/"), !primaryRoot.utf8.contains(0),
              let resolved = realpath(primaryRoot, nil) else { throw ProjectExecutionError.hookNotReady }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    public static func discoveryCheckout(primaryRoot: String, canonicalPrimaryRoot: String, checkout: String) -> String {
        checkout == primaryRoot ? canonicalPrimaryRoot : checkout
    }

    public static func resolve(_ data: Data, checkout: String, primaryRoot: String,
                               command: String, requireTrusted: Bool, inline: Bool = false) throws -> Self {
        let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "ExecutionSetup")
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = result["data"] as? [[String: Any]],
              let entry = entries.first(where: { $0["cwd"] as? String == checkout }),
              let errors = entry["errors"] as? [Any], errors.isEmpty,
              let warnings = entry["warnings"] as? [String], warnings.isEmpty,
              let hooks = entry["hooks"] as? [[String: Any]] else {
            logger.error("Hook readiness failed: response shape, checkout discovery, errors or warnings")
            throw ProjectExecutionError.hookNotReady
        }
        let candidates = hooks.filter {
            $0["source"] as? String == "project" && $0["sourcePath"] as? String == primaryRoot + (inline ? "/.codex/config.toml" : "/.codex/hooks.json")
                && $0["eventName"] as? String == "userPromptSubmit" && $0["command"] as? String == command
                && $0["handlerType"] as? String == "command" && ($0["async"] as? Bool ?? false) == false
        }
        guard candidates.count == 1, let hook = candidates.first else {
            if hooks.isEmpty {
                logger.error("Hook readiness failed: no hooks were discovered")
            } else if candidates.count > 1 {
                logger.error("Hook readiness failed: duplicate full owned hook matches")
            } else {
                let sourceMatches = hooks.filter { $0["source"] as? String == "project" }
                let pathMatches = sourceMatches.filter { $0["sourcePath"] as? String == primaryRoot + (inline ? "/.codex/config.toml" : "/.codex/hooks.json") }
                let eventMatches = pathMatches.filter { $0["eventName"] as? String == "userPromptSubmit" }
                let commandMatches = eventMatches.filter { $0["command"] as? String == command }
                let handlerMatches = commandMatches.filter { $0["handlerType"] as? String == "command" }
                if sourceMatches.isEmpty {
                    logger.error("Hook readiness failed: project source mismatch")
                } else if pathMatches.isEmpty {
                    logger.error("Hook readiness failed: owned sourcePath mismatch")
                } else if eventMatches.isEmpty {
                    logger.error("Hook readiness failed: owned eventName mismatch")
                } else if commandMatches.isEmpty {
                    logger.error("Hook readiness failed: owned command mismatch")
                } else if handlerMatches.isEmpty {
                    logger.error("Hook readiness failed: owned handlerType mismatch")
                } else {
                    logger.error("Hook readiness failed: owned async mismatch")
                }
            }
            throw ProjectExecutionError.hookNotReady
        }
        guard hook["enabled"] as? Bool == true, hook["timeoutSec"] as? Int == 10,
              let key = hook["key"] as? String, !key.isEmpty,
              let hash = hook["currentHash"] as? String, !hash.isEmpty,
              let trust = hook["trustStatus"] as? String else {
            logger.error("Hook readiness failed: owned hook is disabled or its definition is unsupported")
            throw ProjectExecutionError.hookNotReady
        }
        guard ["trusted", "untrusted"].contains(trust), !requireTrusted || trust == "trusted" else {
            logger.error("Hook readiness failed: owned hook trust is not ready")
            throw ProjectExecutionError.hookNotReady
        }
        return .init(key: key, currentHash: hash, trustStatus: trust)
    }

    public var trustEdit: [String: Any] {
        ["keyPath": "hooks.state", "mergeStrategy": "upsert", "value": [key: ["trusted_hash": currentHash]]]
    }

    public func verifyTrustedReadback(_ observed: Self) throws {
        guard observed.key == key, observed.currentHash == currentHash,
              observed.trustStatus == "trusted" else { throw ProjectExecutionError.hookNotReady }
    }
}
