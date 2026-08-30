import CryptoKit
import Darwin
import Foundation
import OSLog
import Security

private let lifecycleLogger = Logger(
    subsystem: "com.rekonlabs.ReleaseRadarPluginLifecycleHelper",
    category: "lifecycle"
)

private func currentExecutableURL() -> URL {
    var size: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    let result = buffer.withUnsafeMutableBufferPointer { pointer in
        _NSGetExecutablePath(pointer.baseAddress, &size)
    }
    guard result == 0 else {
        return URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    }
    return URL(fileURLWithPath: String(cString: buffer)).standardizedFileURL
}

private enum LifecycleError: String, Codable, Error {
    case codexUnavailable, codexUntrusted, unauthorizedPeer, marketplaceConflict
    case malformedResult, outputOverflow, timeout, integrityInvalid, integrityUnknown
    case postconditionFailed, partialReinstall
}

private enum ObservedState: Codable, Equatable {
    case absent
    case clean(version: String, digest: String)
    case modified(version: String?, observedDigest: String?)
    case needsRepair(LifecycleError)
}

private struct HelperReply: Codable {
    let wireVersion: Int
    let observedState: ObservedState?
    let error: LifecycleError?

    static func state(_ value: ObservedState) -> HelperReply {
        .init(wireVersion: 1, observedState: value, error: nil)
    }

    static func failure(_ error: LifecycleError) -> HelperReply {
        .init(wireVersion: 1, observedState: nil, error: error)
    }
}

@objc(ReleaseRadarPluginLifecycleXPC)
private protocol PluginLifecycleXPC {
    func status(withReply reply: @escaping (Data) -> Void)
    func install(withReply reply: @escaping (Data) -> Void)
    func remove(withReply reply: @escaping (Data) -> Void)
    func reinstall(withReply reply: @escaping (Data) -> Void)
}

private enum Operation { case status, install, remove, reinstall }

private final class ReplySink: @unchecked Sendable {
    private let reply: (Data) -> Void

    init(_ reply: @escaping (Data) -> Void) {
        self.reply = reply
    }

    func send(_ data: Data) {
        reply(data)
    }
}

private final class Endpoint: NSObject, PluginLifecycleXPC, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.rekonlabs.ReleaseRadar.plugin-lifecycle.operations")
    private let lifecycle = Lifecycle()

    func status(withReply reply: @escaping (Data) -> Void) { perform(.status, reply: reply) }
    func install(withReply reply: @escaping (Data) -> Void) { perform(.install, reply: reply) }
    func remove(withReply reply: @escaping (Data) -> Void) { perform(.remove, reply: reply) }
    func reinstall(withReply reply: @escaping (Data) -> Void) { perform(.reinstall, reply: reply) }

    func cancelActiveOperation() {
        lifecycle.cancelActiveOperation()
    }

    private func perform(_ operation: Operation, reply: @escaping (Data) -> Void) {
        let replySink = ReplySink(reply)
        queue.async { [lifecycle, replySink] in
            let result: HelperReply
            do {
                result = switch operation {
                case .status: try lifecycle.status()
                case .install: try lifecycle.install()
                case .remove: try lifecycle.remove()
                case .reinstall: try lifecycle.reinstall()
                }
            } catch let error as LifecycleError {
                lifecycleLogger.error("Operation failed: \(error.rawValue, privacy: .public)")
                result = .failure(error)
            } catch {
                lifecycleLogger.error("Operation failed: unexpected error")
                result = .failure(.malformedResult)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(result), data.count <= 65_536 else {
                let fallback = try! encoder.encode(HelperReply.failure(.outputOverflow))
                replySink.send(fallback)
                return
            }
            replySink.send(data)
        }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let endpoint = Endpoint()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }
        connection.setCodeSigningRequirement(
            "anchor apple generic and identifier \"com.rekonlabs.ReleaseRadar\" and certificate leaf[subject.OU] = \"2UA854NLX4\""
        )
        connection.interruptionHandler = { [weak endpoint] in endpoint?.cancelActiveOperation() }
        connection.invalidationHandler = { [weak endpoint] in endpoint?.cancelActiveOperation() }
        connection.exportedInterface = NSXPCInterface(with: PluginLifecycleXPC.self)
        connection.exportedObject = endpoint
        connection.resume()
        return true
    }
}

private final class Lifecycle: @unchecked Sendable {
    private let cli = URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex")
    private let agentTools = "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools"
    private let marketplaceRoot: URL
    private let shippedVersion: String
    private let shippedDigest: String
    private let processLock = NSLock()
    private var activeProcessGroup: pid_t?
    private var activeCancellationRequested = false
    private var operationDeadline: Date?

    init() {
        let executable = currentExecutableURL()
        let appRoot = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        marketplaceRoot = appRoot.appendingPathComponent("Contents/Resources/CodexPluginMarketplace", isDirectory: true)
        let package = (try? PluginDigester.marketplacePackage(at: marketplaceRoot))
        shippedVersion = package?.version ?? ""
        shippedDigest = package?.digest ?? ""
    }

    func status() throws -> HelperReply {
        try withOperationDeadline {
            try verifyCodexExecutable()
            guard !shippedVersion.isEmpty, !shippedDigest.isEmpty else { throw LifecycleError.integrityInvalid }
            return .state(try observeInstalled())
        }
    }

    func install() throws -> HelperReply {
        try withOperationDeadline {
            try verifyCodexExecutable()
            let before = try observeInstalled()
            if case .clean = before {
                try addMarketplaceAndPlugin()
                return try verifiedShippedState()
            }
            if case .modified = before {
                lifecycleLogger.error("Install refused a modified plugin")
                throw LifecycleError.marketplaceConflict
            }
            if case .needsRepair = before {
                lifecycleLogger.error("Install refused a plugin needing repair")
                throw LifecycleError.marketplaceConflict
            }

            let direct = try mcpState(name: "release_radar")
            let legacy = try mcpState(name: "release-radar")
            guard direct != .conflict, legacy != .conflict else {
                lifecycleLogger.error("Install refused a conflicting MCP entry")
                throw LifecycleError.marketplaceConflict
            }
            var issuedDirectRemoval = false
            var issuedLegacyRemoval = false
            var introducedMarketplace = false
            do {
                if direct == .exact {
                    guard try mcpState(name: "release_radar") == .exact else {
                        lifecycleLogger.error("Direct MCP entry changed during install")
                        throw LifecycleError.marketplaceConflict
                    }
                    issuedDirectRemoval = true
                    _ = try run(["mcp", "remove", "release_radar"])
                    guard try mcpState(name: "release_radar") == .absent else { throw LifecycleError.postconditionFailed }
                }
                introducedMarketplace = try marketplacePath() == nil
                try addMarketplaceAndPlugin()
                _ = try verifiedShippedState()
                if legacy == .exact {
                    guard try mcpState(name: "release-radar") == .exact else {
                        lifecycleLogger.error("Legacy MCP entry changed during install")
                        throw LifecycleError.marketplaceConflict
                    }
                    issuedLegacyRemoval = true
                    _ = try run(["mcp", "remove", "release-radar"])
                    guard try mcpState(name: "release-radar") == .absent else { throw LifecycleError.postconditionFailed }
                }
                return try verifiedShippedState()
            } catch {
                let operationError = error
                do {
                    try rollback(
                        introducedMarketplace: introducedMarketplace,
                        restoreDirect: issuedDirectRemoval,
                        restoreLegacy: issuedLegacyRemoval
                    )
                } catch {
                    throw LifecycleError.postconditionFailed
                }
                throw operationError
            }
        }
    }

    func remove() throws -> HelperReply {
        try withOperationDeadline {
            try verifyCodexExecutable()
            if try marketplacePath() != nil {
                let observation = try pluginObservation()
                if observation.version != nil {
                    _ = try run(["plugin", "remove", "release-radar@release-radar", "--json"])
                }
            }
            guard try observeInstalled() == .absent else { throw LifecycleError.postconditionFailed }
            return .state(.absent)
        }
    }

    func reinstall() throws -> HelperReply {
        try withOperationDeadline {
            try verifyCodexExecutable()
            if try marketplacePath() != nil, try pluginObservation().version != nil {
                _ = try run(["plugin", "remove", "release-radar@release-radar", "--json"])
            }
            do {
                try addMarketplaceAndPlugin()
                return try verifiedShippedState()
            } catch {
                throw LifecycleError.partialReinstall
            }
        }
    }

    func cancelActiveOperation() {
        processLock.withLock {
            guard let processGroup = activeProcessGroup,
                  getpgid(processGroup) == processGroup else { return }
            activeCancellationRequested = true
            _ = kill(-processGroup, SIGTERM)
        }
    }

    private func withOperationDeadline<T>(_ body: () throws -> T) throws -> T {
        operationDeadline = Date().addingTimeInterval(15)
        defer { operationDeadline = nil }
        return try body()
    }

    private func addMarketplaceAndPlugin() throws {
        if let existing = try marketplacePath() {
            guard existing == marketplaceRoot.path else {
                lifecycleLogger.error("Install refused a conflicting marketplace root")
                throw LifecycleError.marketplaceConflict
            }
        } else {
            _ = try run(["plugin", "marketplace", "add", marketplaceRoot.path, "--json"])
        }
        guard try marketplacePath() == marketplaceRoot.path else { throw LifecycleError.marketplaceConflict }
        _ = try run(["plugin", "add", "release-radar@release-radar", "--json"])
    }

    private func verifiedShippedState() throws -> HelperReply {
        let observed = try observeInstalled()
        guard observed == .clean(version: shippedVersion, digest: shippedDigest) else {
            throw LifecycleError.postconditionFailed
        }
        let initialMCPState = try mcpState(name: "release_radar")
        if initialMCPState == .exact {
            return .state(observed)
        }
        guard initialMCPState == .absent else {
            throw LifecycleError.postconditionFailed
        }
        usleep(250_000)
        guard try mcpState(name: "release_radar") == .exact else {
            throw LifecycleError.postconditionFailed
        }
        return .state(observed)
    }

    private func observeInstalled() throws -> ObservedState {
        guard let registeredRoot = try marketplacePath() else { return .absent }
        guard registeredRoot == marketplaceRoot.path else {
            lifecycleLogger.error("Observed a conflicting marketplace root")
            throw LifecycleError.marketplaceConflict
        }
        let observation = try pluginObservation()
        guard let version = observation.version else { return .absent }
        do {
            let home = try effectiveHome()
            let installed = try PluginDigester.installedPackage(home: home, version: version)
            return .clean(version: version, digest: installed.digest)
        } catch LifecycleError.integrityInvalid {
            return .needsRepair(.integrityInvalid)
        } catch {
            throw LifecycleError.integrityUnknown
        }
    }

    private struct PluginObservation { let version: String? }

    private func pluginObservation() throws -> PluginObservation {
        let result = try run(["plugin", "list", "--marketplace", "release-radar", "--available", "--json"])
        guard let root = try strictObject(result.stdout), Set(root.keys) == ["installed", "available"],
              let installed = root["installed"] as? [[String: Any]],
              let available = root["available"] as? [[String: Any]] else {
            lifecycleLogger.error("Malformed plugin list envelope")
            throw LifecycleError.malformedResult
        }
        if installed.isEmpty { return PluginObservation(version: nil) }
        guard installed.count == 1, available.isEmpty,
              let version = exactPluginVersion(installed[0], installed: true) else {
            lifecycleLogger.error("Malformed installed plugin entry")
            throw LifecycleError.malformedResult
        }
        return PluginObservation(version: version)
    }

    private func exactPluginVersion(_ plugin: [String: Any], installed: Bool) -> String? {
        guard Set(plugin.keys) == [
            "pluginId", "name", "marketplaceName", "version", "installed", "enabled",
            "source", "marketplaceSource", "installPolicy", "authPolicy",
        ], plugin["pluginId"] as? String == "release-radar@release-radar",
        plugin["name"] as? String == "release-radar",
        plugin["marketplaceName"] as? String == "release-radar",
        plugin["installed"] as? Bool == installed,
        plugin["enabled"] as? Bool == installed,
        plugin["installPolicy"] as? String == "AVAILABLE",
        plugin["authPolicy"] as? String == "ON_INSTALL",
        let version = plugin["version"] as? String,
        PluginDigester.isStrictSemVer(version),
        let source = plugin["source"] as? [String: Any], Set(source.keys) == ["source", "path"],
        source["source"] as? String == "local",
        source["path"] as? String == marketplaceRoot.appendingPathComponent("plugins/release-radar").path,
        let market = plugin["marketplaceSource"] as? [String: Any], Set(market.keys) == ["sourceType", "source"],
        market["sourceType"] as? String == "local", market["source"] as? String == marketplaceRoot.path
        else { return nil }
        return version
    }

    private func marketplacePath() throws -> String? {
        let result = try run(["plugin", "marketplace", "list", "--json"])
        guard let root = try strictObject(result.stdout), Set(root.keys) == ["marketplaces"],
              let entries = root["marketplaces"] as? [[String: Any]] else {
            lifecycleLogger.error("Malformed marketplace list envelope")
            throw LifecycleError.malformedResult
        }
        let targets = entries.filter { $0["name"] as? String == "release-radar" }
        guard targets.count <= 1 else {
            lifecycleLogger.error("Observed duplicate Release Radar marketplace entries")
            throw LifecycleError.marketplaceConflict
        }
        guard let target = targets.first else { return nil }
        guard Set(target.keys) == ["name", "root", "marketplaceSource"],
              let path = target["root"] as? String,
              let source = target["marketplaceSource"] as? [String: Any],
              Set(source.keys) == ["sourceType", "source"],
              source["sourceType"] as? String == "local",
              source["source"] as? String == path else {
            lifecycleLogger.error("Malformed Release Radar marketplace entry")
            throw LifecycleError.malformedResult
        }
        return path
    }

    private enum MCPState { case absent, exact, conflict }

    private func mcpState(name: String) throws -> MCPState {
        let result = try runAllowingFailure(["mcp", "get", name, "--json"])
        if result.exitStatus == 1,
           result.stdout.isEmpty,
           result.stderr == Data("Error: No MCP server named '\(name)' found.\n".utf8) {
            return .absent
        }
        guard result.exitStatus == 0, result.stderr.isEmpty,
              let root = try strictObject(result.stdout), root["name"] as? String == name,
              root["enabled"] as? Bool == true,
              root["disabled_reason"] is NSNull,
              let transport = root["transport"] as? [String: Any],
              transport["type"] as? String == "stdio",
              transport["command"] as? String == agentTools,
              (transport["args"] as? [Any])?.isEmpty == true,
              (transport["cwd"] == nil || transport["cwd"] is NSNull),
              transport["env"] == nil || transport["env"] is NSNull || (transport["env"] as? [String: Any])?.isEmpty == true,
              transport["env_vars"] == nil || (transport["env_vars"] as? [Any])?.isEmpty == true
        else { return .conflict }
        return .exact
    }

    private func rollback(introducedMarketplace: Bool, restoreDirect: Bool, restoreLegacy: Bool) throws {
        _ = try? run(["plugin", "remove", "release-radar@release-radar", "--json"])
        if introducedMarketplace { _ = try? run(["plugin", "marketplace", "remove", "release-radar", "--json"]) }
        try restoreIssuedMCPEntry(name: "release_radar", issuedRemoval: restoreDirect)
        try restoreIssuedMCPEntry(name: "release-radar", issuedRemoval: restoreLegacy)
    }

    private func restoreIssuedMCPEntry(name: String, issuedRemoval: Bool) throws {
        guard issuedRemoval else { return }
        switch try mcpState(name: name) {
        case .exact:
            return
        case .absent:
            _ = try run(["mcp", "add", name, "--", agentTools])
            guard try mcpState(name: name) == .exact else {
                throw LifecycleError.postconditionFailed
            }
        case .conflict:
            throw LifecycleError.postconditionFailed
        }
    }

    private func verifyCodexExecutable() throws {
        let components = [
            "/Applications", "/Applications/ChatGPT.app", "/Applications/ChatGPT.app/Contents",
            "/Applications/ChatGPT.app/Contents/Resources", cli.path,
        ]
        for component in components {
            var info = stat()
            guard lstat(component, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else {
                throw LifecycleError.codexUntrusted
            }
        }
        var info = stat()
        guard lstat(cli.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_mode & 0o022 == 0, access(cli.path, X_OK) == 0 else {
            throw LifecycleError.codexUntrusted
        }
        try verifyCode(at: URL(fileURLWithPath: "/Applications/ChatGPT.app"), requirement: "anchor apple generic and identifier \"com.openai.codex\" and certificate leaf[subject.OU] = \"2DC432GLL2\"")
        try verifyCode(at: cli, requirement: "anchor apple generic and identifier \"codex\" and certificate leaf[subject.OU] = \"2DC432GLL2\"")
    }

    private func verifyCode(at url: URL, requirement text: String) throws {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        var signingInformation: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess,
              SecCodeCopySigningInformation(
                code,
                SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)),
                &signingInformation
              ) == errSecSuccess,
              let information = signingInformation as? [String: Any],
              let flags = information[kSecCodeInfoFlags as String] as? NSNumber,
              flags.uint32Value & 0x0001_0000 != 0 else { throw LifecycleError.codexUntrusted }
    }

    private func effectiveHome() throws -> URL {
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: Int(sysconf(_SC_GETPW_R_SIZE_MAX).clamped(to: 16_384...1_048_576)))
        guard getpwuid_r(geteuid(), &pwd, &buffer, buffer.count, &result) == 0,
              result != nil, let directory = pwd.pw_dir else { throw LifecycleError.integrityUnknown }
        return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
    }

    private func strictObject(_ data: Data) throws -> [String: Any]? {
        guard !data.isEmpty, String(data: data, encoding: .utf8) != nil,
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let root = object as? [String: Any] else { throw LifecycleError.malformedResult }
        return root
    }

    private struct CommandResult { let exitStatus: Int32; let stdout: Data; let stderr: Data }

    private func run(_ arguments: [String]) throws -> CommandResult {
        let result = try runAllowingFailure(arguments)
        guard result.exitStatus == 0, result.stderr.isEmpty else {
            lifecycleLogger.error(
                "Codex command failed: \(arguments.joined(separator: " "), privacy: .public); status=\(result.exitStatus, privacy: .public); stderrBytes=\(result.stderr.count, privacy: .public)"
            )
            throw LifecycleError.malformedResult
        }
        return result
    }

    private func runAllowingFailure(_ arguments: [String]) throws -> CommandResult {
        try verifyCodexExecutable()
        guard let operationDeadline, Date() < operationDeadline else { throw LifecycleError.timeout }
        var stdoutPipe = [Int32](repeating: -1, count: 2)
        var stderrPipe = [Int32](repeating: -1, count: 2)
        guard pipe(&stdoutPipe) == 0, pipe(&stderrPipe) == 0 else {
            closePipe(stdoutPipe)
            closePipe(stderrPipe)
            throw LifecycleError.codexUnavailable
        }
        var parentDescriptorsOpen = true
        defer {
            if parentDescriptorsOpen {
                closePipe(stdoutPipe)
                closePipe(stderrPipe)
            }
        }

        var fileActions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&fileActions) == 0,
              posix_spawnattr_init(&attributes) == 0 else {
            throw LifecycleError.codexUnavailable
        }
        defer {
            posix_spawn_file_actions_destroy(&fileActions)
            posix_spawnattr_destroy(&attributes)
        }

        guard posix_spawn_file_actions_addopen(
            &fileActions,
            STDIN_FILENO,
            "/dev/null",
            O_RDONLY,
            0
        ) == 0,
        posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO) == 0,
        posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO) == 0,
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0]) == 0,
        posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1]) == 0,
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0]) == 0,
        posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1]) == 0,
        addSpawnChdirAction(&fileActions, path: "/private/var/empty") == 0 else {
            throw LifecycleError.codexUnavailable
        }

        var emptySignals = sigset_t()
        sigemptyset(&emptySignals)
        var defaultSignals = sigset_t()
        sigemptyset(&defaultSignals)
        sigaddset(&defaultSignals, SIGTERM)
        sigaddset(&defaultSignals, SIGINT)
        sigaddset(&defaultSignals, SIGPIPE)
        let spawnFlags = Int16(
            POSIX_SPAWN_SETPGROUP
                | POSIX_SPAWN_SETSIGMASK
                | POSIX_SPAWN_SETSIGDEF
                | POSIX_SPAWN_START_SUSPENDED
        )
        guard posix_spawnattr_setflags(&attributes, spawnFlags) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawnattr_setsigmask(&attributes, &emptySignals) == 0,
              posix_spawnattr_setsigdefault(&attributes, &defaultSignals) == 0 else {
            throw LifecycleError.codexUnavailable
        }

        let argv = [cli.path] + arguments
        let environment = ["LANG=C", "LC_ALL=C", "PATH=/usr/bin:/bin"]
        var childPID = pid_t()
        let spawnStatus = withMutableCStringArray(argv) { argvPointer in
            withMutableCStringArray(environment) { environmentPointer in
                posix_spawn(
                    &childPID,
                    cli.path,
                    &fileActions,
                    &attributes,
                    argvPointer,
                    environmentPointer
                )
            }
        }
        guard spawnStatus == 0, childPID > 0 else {
            throw LifecycleError.codexUnavailable
        }

        close(stdoutPipe[1])
        close(stderrPipe[1])
        stdoutPipe[1] = -1
        stderrPipe[1] = -1

        guard getpgid(childPID) == childPID else {
            _ = kill(childPID, SIGKILL)
            var status = Int32()
            while waitpid(childPID, &status, 0) == -1 && errno == EINTR {}
            throw LifecycleError.codexUnavailable
        }
        processLock.withLock {
            activeProcessGroup = childPID
            activeCancellationRequested = false
        }

        let output = OutputCapture(stdout: stdoutPipe[0], stderr: stderrPipe[0])
        output.start()
        stdoutPipe[0] = -1
        stderrPipe[0] = -1
        parentDescriptorsOpen = false

        guard kill(childPID, SIGCONT) == 0 else {
            var status = Int32()
            var reaped = false
            try terminateAndReap(
                processGroup: childPID,
                childPID: childPID,
                waitStatus: &status,
                childReaped: &reaped
            )
            _ = try? output.finish()
            throw LifecycleError.codexUnavailable
        }

        var waitStatus = Int32()
        var childReaped = false
        var failure: LifecycleError?
        while !childReaped {
            let observation = processLock.withLock { () -> (waited: pid_t, cancelled: Bool) in
                let cancelled = activeCancellationRequested
                let waited = waitpid(childPID, &waitStatus, WNOHANG)
                if waited == childPID {
                    activeProcessGroup = nil
                    activeCancellationRequested = false
                }
                return (waited, cancelled)
            }
            if observation.waited == childPID {
                childReaped = true
                if observation.cancelled { failure = .codexUnavailable }
                break
            }
            if observation.waited == -1, errno != EINTR {
                failure = .postconditionFailed
                break
            }
            if observation.cancelled {
                failure = .codexUnavailable
                break
            }
            if output.didOverflow {
                failure = .outputOverflow
                break
            }
            if output.didReadFail {
                failure = .malformedResult
                break
            }
            if Date() >= operationDeadline {
                failure = .timeout
                break
            }
            usleep(10_000)
        }

        if failure == nil, processGroupExists(childPID) {
            failure = .postconditionFailed
        }
        if failure != nil {
            try terminateAndReap(
                processGroup: childPID,
                childPID: childPID,
                waitStatus: &waitStatus,
                childReaped: &childReaped
            )
        }
        let captured = try output.finish()
        if let failure { throw failure }
        guard childReaped, waitStatusExited(waitStatus) else {
            throw LifecycleError.malformedResult
        }
        return CommandResult(
            exitStatus: waitStatusExitCode(waitStatus),
            stdout: captured.stdout,
            stderr: captured.stderr
        )
    }

    private func terminateAndReap(
        processGroup: pid_t,
        childPID: pid_t,
        waitStatus: inout Int32,
        childReaped: inout Bool
    ) throws {
        if processGroupExists(processGroup) {
            _ = kill(-processGroup, SIGTERM)
        }
        let termDeadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
        while DispatchTime.now().uptimeNanoseconds < termDeadline {
            if !childReaped {
                let waited = processLock.withLock { () -> pid_t in
                    let waited = waitpid(childPID, &waitStatus, WNOHANG)
                    if waited == childPID {
                        activeProcessGroup = nil
                        activeCancellationRequested = false
                    }
                    return waited
                }
                if waited == childPID {
                    childReaped = true
                } else if waited == -1, errno != EINTR, errno != ECHILD {
                    throw LifecycleError.postconditionFailed
                }
            }
            if !processGroupExists(processGroup) { break }
            usleep(10_000)
        }
        if processGroupExists(processGroup) {
            _ = kill(-processGroup, SIGKILL)
        }
        if !childReaped {
            while true {
                let waited = processLock.withLock { () -> pid_t in
                    let waited = waitpid(childPID, &waitStatus, 0)
                    if waited == childPID || (waited == -1 && errno == ECHILD) {
                        activeProcessGroup = nil
                        activeCancellationRequested = false
                    }
                    return waited
                }
                if waited == childPID || (waited == -1 && errno == ECHILD) {
                    childReaped = true
                    break
                }
                if waited == -1, errno == EINTR { continue }
                throw LifecycleError.postconditionFailed
            }
        }
        let killDeadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
        while processGroupExists(processGroup), DispatchTime.now().uptimeNanoseconds < killDeadline {
            usleep(10_000)
        }
        guard !processGroupExists(processGroup) else {
            throw LifecycleError.postconditionFailed
        }
    }
}

private func closePipe(_ descriptors: [Int32]) {
    for descriptor in descriptors where descriptor >= 0 {
        close(descriptor)
    }
}

private func withMutableCStringArray<Result>(
    _ strings: [String],
    body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Result
) -> Result {
    let storage = strings.map { strdup($0)! }
    defer { storage.forEach { free($0) } }
    var pointers: [UnsafeMutablePointer<CChar>?] = storage.map { $0 }
    pointers.append(nil)
    return pointers.withUnsafeMutableBufferPointer { body($0.baseAddress) }
}

private typealias SpawnChdirFunction = @convention(c) (
    UnsafeMutablePointer<posix_spawn_file_actions_t?>?,
    UnsafePointer<CChar>
) -> Int32

private func addSpawnChdirAction(
    _ actions: inout posix_spawn_file_actions_t?,
    path: String
) -> Int32 {
    let defaultSymbolScope = UnsafeMutableRawPointer(bitPattern: -2)
    let symbol = dlsym(defaultSymbolScope, "posix_spawn_file_actions_addchdir")
        ?? dlsym(defaultSymbolScope, "posix_spawn_file_actions_addchdir_np")
    guard let symbol else { return ENOSYS }
    let function = unsafeBitCast(symbol, to: SpawnChdirFunction.self)
    return path.withCString { function(&actions, $0) }
}

private func processGroupExists(_ processGroup: pid_t) -> Bool {
    errno = 0
    return kill(-processGroup, 0) == 0 || errno == EPERM
}

private func waitStatusExited(_ status: Int32) -> Bool {
    status & 0x7f == 0
}

private func waitStatusExitCode(_ status: Int32) -> Int32 {
    (status >> 8) & 0xff
}

private final class OutputCapture: @unchecked Sendable {
    private let stdoutDescriptor: Int32
    private let stderrDescriptor: Int32
    private let queue = DispatchQueue(label: "com.rekonlabs.ReleaseRadar.plugin-lifecycle.output", attributes: .concurrent)
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var overflow = false

    init(stdout: Int32, stderr: Int32) {
        stdoutDescriptor = stdout
        stderrDescriptor = stderr
    }

    var didOverflow: Bool { lock.withLock { overflow } }
    var didReadFail: Bool { lock.withLock { readFailed } }

    private var readFailed = false

    func start() {
        read(stdoutDescriptor, isStandardError: false)
        read(stderrDescriptor, isStandardError: true)
    }

    func finish() throws -> (stdout: Data, stderr: Data) {
        guard group.wait(timeout: .now() + 2) == .success else {
            throw LifecycleError.postconditionFailed
        }
        return try lock.withLock {
            if overflow { throw LifecycleError.outputOverflow }
            if readFailed { throw LifecycleError.malformedResult }
            return (stdout, stderr)
        }
    }

    private func read(_ descriptor: Int32, isStandardError: Bool) {
        group.enter()
        queue.async { [self] in
            defer {
                close(descriptor)
                group.leave()
            }
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = Darwin.read(descriptor, &buffer, buffer.count)
                if count == 0 { return }
                if count < 0 {
                    if errno == EINTR { continue }
                    lock.withLock { readFailed = true }
                    return
                }
                let data = Data(buffer.prefix(count))
                let exceeded = lock.withLock { () -> Bool in
                    var target = isStandardError ? stderr : stdout
                    if target.count + data.count > 1_048_576 {
                        let remaining = Swift.max(0, 1_048_576 - target.count)
                        if remaining > 0 { target.append(data.prefix(remaining)) }
                        overflow = true
                    } else {
                        target.append(data)
                    }
                    if isStandardError { stderr = target } else { stdout = target }
                    return overflow
                }
                if exceeded { return }
            }
        }
    }
}

private enum PluginDigester {
    struct Package { let version: String; let digest: String }
    private static let files = [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]

    static func marketplacePackage(at root: URL) throws -> Package {
        let plugin = root.appendingPathComponent("plugins/release-radar", isDirectory: true)
        return try package(at: plugin, expectedVersion: nil)
    }

    static func installedPackage(home: URL, version: String) throws -> Package {
        guard isStrictSemVer(version) else { throw LifecycleError.integrityInvalid }
        let root = home.appendingPathComponent(".codex/plugins/cache/release-radar/release-radar", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
        return try package(at: root, expectedVersion: version)
    }

    static func isStrictSemVer(_ version: String) -> Bool {
        version.utf8.count <= 128
            && version.range(of: #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"#, options: .regularExpression) != nil
    }

    private static func package(at root: URL, expectedVersion: String?) throws -> Package {
        var inventory: [String] = []
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]) else {
            throw LifecycleError.integrityInvalid
        }
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw LifecycleError.integrityInvalid }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw LifecycleError.integrityInvalid }
            inventory.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        guard inventory.sorted() == files.sorted() else { throw LifecycleError.integrityInvalid }
        let manifestData = try stableFile(root.appendingPathComponent(".codex-plugin/plugin.json"))
        guard let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              manifest["name"] as? String == "release-radar", let version = manifest["version"] as? String,
              isStrictSemVer(version), expectedVersion == nil || version == expectedVersion else {
            throw LifecycleError.integrityInvalid
        }
        let mcpData = try stableFile(root.appendingPathComponent(".mcp.json"))
        guard let mcp = try? JSONSerialization.jsonObject(with: mcpData) as? [String: Any],
              mcp.count == 1, let server = mcp["release_radar"] as? [String: Any],
              server["command"] is String, (server["args"] as? [Any])?.isEmpty == true else {
            throw LifecycleError.integrityInvalid
        }
        var hasher = SHA256()
        for relative in files.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            let data = try stableFile(root.appendingPathComponent(relative))
            hasher.update(data: Data(relative.utf8)); hasher.update(data: Data([0]))
            var count = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &count) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        }
        return Package(version: version, digest: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    private static func stableFile(_ url: URL) throws -> Data {
        var before = stat(), after = stat()
        guard lstat(url.path, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG,
              let data = try? Data(contentsOf: url), lstat(url.path, &after) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else {
            throw LifecycleError.integrityInvalid
        }
        return data
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private let delegate = ListenerDelegate()
private let listener = NSXPCListener(machServiceName: "2UA854NLX4.com.rekonlabs.ReleaseRadar.plugin-lifecycle")
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
