import Darwin
import Foundation
import Security

/// The same fixed installed OpenAI identity used by RR's plugin lifecycle.
/// This verifies an executable; it does not grant filesystem or launch authority.
public enum CodexExecutionIdentity {
    public static let executable = "/Applications/ChatGPT.app/Contents/Resources/codex"

    public static func verify() throws {
        for path in ["/Applications", "/Applications/ChatGPT.app", "/Applications/ChatGPT.app/Contents", "/Applications/ChatGPT.app/Contents/Resources", executable] {
            var metadata = stat()
            guard lstat(path, &metadata) == 0, metadata.st_mode & S_IFMT != S_IFLNK else {
                throw ProjectExecutionError.unavailable
            }
        }
        var metadata = stat()
        guard lstat(executable, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_mode & 0o022 == 0, access(executable, X_OK) == 0 else {
            throw ProjectExecutionError.unavailable
        }
        try verifyCode("/Applications/ChatGPT.app", identifier: "com.openai.codex")
        try verifyCode(executable, identifier: "codex")
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
