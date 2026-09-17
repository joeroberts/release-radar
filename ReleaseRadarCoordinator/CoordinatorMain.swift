import Foundation
import ReleaseRadarCore

@main enum CoordinatorMain {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments == ["--hook"] { try hook(); return }
            guard arguments == ["--mcp"] else { throw ProjectExecutionError.invalidAssignment }
            let service = CoordinatorMCP()
            await withTaskGroup(of: Void.self) { group in
                while let line = readLine() {
                    guard line.utf8.count <= 1_048_576, let data = line.data(using: .utf8),
                          let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let payload = try? RPCObject(message) else {
                        writeError("Invalid JSON request."); continue
                    }
                    if message["id"] == nil { continue }
                    group.addTask { await service.respond(payload) }
                }
                await group.waitForAll()
            }
            try await service.disconnect()
        } catch {
            FileHandle.standardError.write(Data(("Release Radar execution unavailable: " + error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }

    private static func hook() throws {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        guard input.count <= 1_048_576,
              let event = try JSONSerialization.jsonObject(with: input) as? [String: Any],
              event["hook_event_name"] as? String == "UserPromptSubmit",
              let cwd = event["cwd"] as? String, let session = event["session_id"] as? String,
              cwd.hasPrefix("/"), !session.isEmpty else { throw ProjectExecutionError.invalidAssignment }
        let checkout = URL(fileURLWithPath: cwd)
        guard checkout.standardizedFileURL.path == cwd, checkout.resolvingSymlinksInPath().path == cwd else { throw ProjectExecutionError.identityMismatch }
        let root = try ProjectExecutionFileStore.applicationRoot()
        guard cwd.hasPrefix(root.appendingPathComponent("Worktrees").path + "/") else { return }
        do {
            let store = try ProjectExecutionFileStore(root: root, create: false)
            _ = try ProjectExecutionHookAdmission.resolve(store: store, checkout: checkout, sessionID: session)
            // Eligibility and runtime identity only. Never read or classify the prompt/transcript.
        } catch {
            let output: [String: Any] = ["decision": "block", "reason": error.localizedDescription]
            let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
            FileHandle.standardOutput.write(data + Data([10]))
        }
    }
    private static func writeError(_ message: String) {
        if let data = try? JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": NSNull(), "error": ["code": -32700, "message": message]]) {
            FileHandle.standardOutput.write(data + Data([10]))
        }
    }
}
