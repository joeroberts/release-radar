import Foundation

/// Own one exact group; all surrounding configuration stays owner-controlled.
public enum ProjectExecutionHookRegistration {
    public static let event = "UserPromptSubmit"
    public static let label = "Release Radar assignment admission"

    private static func definition(_ command: String) -> [String: Any] {
        ["matcher": "", "hooks": [["type": "command", "command": command, "timeout": 10]]]
    }

    private static func decode(_ data: Data?) throws -> [String: Any] {
        guard let data else { return ["hooks": [String: Any]()] }
        guard data.count <= 1_048_576,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["hooks"] == nil || object["hooks"] is [String: Any] else {
            throw ProjectExecutionError.conflict
        }
        return object
    }

    private static func matches(_ group: [String: Any], _ command: String) -> Bool {
        NSDictionary(dictionary: group).isEqual(to: definition(command))
    }

    public static func merge(_ data: Data?, command: String, previousCommand: String?) throws -> Data {
        guard !command.isEmpty, !command.utf8.contains(0), !command.contains("\n") else { throw ProjectExecutionError.invalidAssignment }
        var object = try decode(data)
        var hooks = object["hooks"] as? [String: Any] ?? [:]
        guard hooks[event] == nil || hooks[event] is [[String: Any]] else { throw ProjectExecutionError.conflict }
        var groups = hooks[event] as? [[String: Any]] ?? []
        if let previousCommand {
            let owned = groups.indices.filter { matches(groups[$0], previousCommand) }
            guard owned.count == 1 else { throw ProjectExecutionError.conflict }
            groups[owned[0]] = definition(command)
        } else {
            // Do not adopt a lookalike left by an unknown registration.
            let existingCommands = groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
            guard !existingCommands.contains(where: { ($0["command"] as? String) == command }) else { throw ProjectExecutionError.conflict }
            groups.append(definition(command))
        }
        hooks[event] = groups; object["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
    }

    public static func remove(_ data: Data, previousCommand: String) throws -> Data {
        var object = try decode(data)
        var hooks = object["hooks"] as? [String: Any] ?? [:]
        guard var groups = hooks[event] as? [[String: Any]] else { throw ProjectExecutionError.conflict }
        let owned = groups.indices.filter { matches(groups[$0], previousCommand) }
        guard owned.count == 1 else { throw ProjectExecutionError.conflict }
        groups.remove(at: owned[0]); hooks[event] = groups; object["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
    }

    public static func removeIfPresent(_ data: Data?, previousCommand: String) throws -> Data? {
        guard let data else { return nil }
        let object = try decode(data)
        let hooks = object["hooks"] as? [String: Any] ?? [:]
        guard hooks[event] == nil || hooks[event] is [[String: Any]] else { throw ProjectExecutionError.conflict }
        let groups = hooks[event] as? [[String: Any]] ?? []
        let commands = groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
        // An owner-removed definition remains absent. A modified lookalike using
        // our command is a conflict, never permission to delete that owner's edit.
        if !commands.contains(where: { $0["command"] as? String == previousCommand }) { return data }
        return try remove(data, previousCommand: previousCommand)
    }
}
