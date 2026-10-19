import Darwin
import Foundation
import Security

/// The same fixed installed OpenAI identity used by RR's plugin lifecycle.
/// This verifies an executable; it does not grant filesystem or launch authority.
public enum CodexExecutionIdentity {
    private static let applicationPath = "/Applications/ChatGPT.app"
    public static let executable = candidateExecutable(applicationPath: applicationPath)

    static func resolveExecutable(
        applicationPath: String,
        codeVerifier: (_ path: String, _ identifier: String) throws -> Void
    ) throws -> String {
        let application = URL(fileURLWithPath: applicationPath)
        guard application.path == applicationPath,
              application.standardizedFileURL.path == applicationPath else {
            throw ProjectExecutionError.unavailable
        }
        let candidate = candidateExecutable(applicationPath: applicationPath)
        let parent = application.deletingLastPathComponent().path
        let contents = application.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let nested = resources.appendingPathComponent(
            "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            isDirectory: false
        ).path
        var components = [parent, applicationPath, contents.path, resources.path]
        if candidate == nested {
            components += [
                resources.appendingPathComponent("codex-cli", isDirectory: true).path,
                resources.appendingPathComponent("codex-cli/CodexCLI.app", isDirectory: true).path,
                resources.appendingPathComponent("codex-cli/CodexCLI.app/Contents", isDirectory: true).path,
                resources.appendingPathComponent("codex-cli/CodexCLI.app/Contents/MacOS", isDirectory: true).path,
            ]
        }
        for path in components {
            var metadata = stat()
            guard lstat(path, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFDIR,
                  metadata.st_mode & S_IFMT != S_IFLNK,
                  metadata.st_mode & 0o022 == 0 else {
                throw ProjectExecutionError.unavailable
            }
        }
        var metadata = stat()
        guard lstat(candidate, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_mode & S_IFMT != S_IFLNK,
              metadata.st_mode & 0o022 == 0,
              access(candidate, X_OK) == 0 else {
            throw ProjectExecutionError.unavailable
        }
        try codeVerifier(applicationPath, "com.openai.codex")
        try codeVerifier(candidate, "codex")
        return candidate
    }

    public static func verify() throws {
        guard try resolveExecutable(
            applicationPath: applicationPath,
            codeVerifier: verifyCode
        ) == executable else {
            throw ProjectExecutionError.unavailable
        }
    }

    private static func candidateExecutable(applicationPath: String) -> String {
        let resources = URL(fileURLWithPath: applicationPath)
            .appendingPathComponent("Contents/Resources", isDirectory: true)
        let nested = resources.appendingPathComponent(
            "codex-cli/CodexCLI.app/Contents/MacOS/codex",
            isDirectory: false
        ).path
        var metadata = stat()
        if lstat(nested, &metadata) == 0 { return nested }
        return resources.appendingPathComponent("codex", isDirectory: false).path
    }

    private static func verifyCode(_ path: String, identifier: String) throws {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        var information: CFDictionary?
        let identity = "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"2DC432GLL2\""
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess,
              SecRequirementCreateWithString(identity as CFString, [], &requirement) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)), &information) == errSecSuccess,
              let values = information as? [String: Any], let flags = values[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & 0x0001_0000 != 0 else { throw ProjectExecutionError.unavailable }
    }
}
