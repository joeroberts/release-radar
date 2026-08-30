import CryptoKit
import Darwin
import Foundation

public enum CodexPluginIntent: String, Codable, Sendable {
    case neverInstalled
    case managedInstalled
    case removed
    case attentionRequired
}

public struct CodexPluginReceipt: Codable, Equatable, Sendable {
    public let intent: CodexPluginIntent
    public let managedVersion: String?
    public let managedDigest: String?
    public let verifiedAt: Date?

    public init(
        intent: CodexPluginIntent,
        managedVersion: String?,
        managedDigest: String?,
        verifiedAt: Date?
    ) {
        self.intent = intent
        self.managedVersion = managedVersion
        self.managedDigest = managedDigest
        self.verifiedAt = verifiedAt
    }

    public static let neverInstalled = CodexPluginReceipt(
        intent: .neverInstalled,
        managedVersion: nil,
        managedDigest: nil,
        verifiedAt: nil
    )
}

public enum CodexPluginObservedState: Codable, Equatable, Sendable {
    case absent
    case clean(version: String, digest: String)
    case modified(version: String?, observedDigest: String?)
    case needsRepair(CodexPluginLifecycleError)
}

public enum CodexPluginPresentationState: Equatable, Sendable {
    case checking
    case notInstalled
    case installed(version: String)
    case updateAvailable(installed: String, shipped: String)
    case modified(version: String?)
    case needsRepair
    case failed(CodexPluginLifecycleError)
}

public enum CodexPluginLifecycleError: String, Codable, Error, Equatable, Sendable {
    case codexUnavailable
    case codexUntrusted
    case unauthorizedPeer
    case marketplaceConflict
    case malformedResult
    case outputOverflow
    case timeout
    case integrityInvalid
    case integrityUnknown
    case postconditionFailed
    case partialReinstall
}

public struct CodexPluginHelperReply: Codable, Equatable, Sendable {
    public let wireVersion: Int
    public let observedState: CodexPluginObservedState?
    public let error: CodexPluginLifecycleError?

    public init(
        wireVersion: Int,
        observedState: CodexPluginObservedState?,
        error: CodexPluginLifecycleError?
    ) {
        self.wireVersion = wireVersion
        self.observedState = observedState
        self.error = error
    }
}

public protocol CodexPluginLifecycleManaging: Sendable {
    func status() async -> CodexPluginHelperReply
    func install() async -> CodexPluginHelperReply
    func remove() async -> CodexPluginHelperReply
    func reinstall() async -> CodexPluginHelperReply
}

public struct CodexPluginLifecycleResult: Equatable, Sendable {
    public let state: CodexPluginPresentationState
    public let changedInstallation: Bool

    public init(state: CodexPluginPresentationState, changedInstallation: Bool = false) {
        self.state = state
        self.changedInstallation = changedInstallation
    }
}

public actor CodexPluginLifecycleCoordinator {
    private let manager: any CodexPluginLifecycleManaging
    private let store: CodexPluginLifecycleStore
    private let shippedVersion: String
    private let shippedDigest: String
    private let now: @Sendable () -> Date

    public init(
        manager: any CodexPluginLifecycleManaging,
        store: CodexPluginLifecycleStore,
        shippedVersion: String,
        shippedDigest: String,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.manager = manager
        self.store = store
        self.shippedVersion = shippedVersion
        self.shippedDigest = shippedDigest
        self.now = now
    }

    public func status() async -> CodexPluginLifecycleResult {
        guard let receipt = try? await store.load() else {
            return .init(state: .failed(.malformedResult))
        }
        if receipt.intent == .neverInstalled || receipt.intent == .removed {
            return .init(state: .notInstalled)
        }
        return await statusFrom(reply: await manager.status(), receipt: receipt)
    }

    public func install() async -> CodexPluginLifecycleResult {
        await change(
            operation: manager.install,
            reason: "Install Release Radar Codex plugin"
        )
    }

    public func update() async -> CodexPluginLifecycleResult {
        await change(
            operation: manager.install,
            reason: "Update Release Radar Codex plugin"
        )
    }

    public func reinstall() async -> CodexPluginLifecycleResult {
        await change(
            operation: manager.reinstall,
            reason: "Reinstall Release Radar Codex plugin"
        )
    }

    public func remove() async -> CodexPluginLifecycleResult {
        let reply = await manager.remove()
        guard reply.wireVersion == 1, reply.error == nil else {
            return .init(state: .failed(reply.error ?? .malformedResult))
        }
        let postcondition = await manager.status()
        guard postcondition.wireVersion == 1,
              postcondition.error == nil,
              postcondition.observedState == .absent
        else { return .init(state: .failed(postcondition.error ?? .postconditionFailed)) }
        do {
            let current = try await store.load()
            let removed = CodexPluginReceipt(
                intent: .removed,
                managedVersion: current.managedVersion,
                managedDigest: current.managedDigest,
                verifiedAt: current.verifiedAt
            )
            try await store.recordVerified(removed, reason: "Remove Release Radar Codex plugin")
            return .init(state: .notInstalled, changedInstallation: true)
        } catch {
            return .init(state: .failed(.postconditionFailed))
        }
    }

    public func performAutomaticUpdateIfEligible() async -> CodexPluginLifecycleResult {
        guard let receipt = try? await store.load() else {
            return .init(state: .failed(.malformedResult))
        }
        guard receipt.intent != .neverInstalled, receipt.intent != .removed else {
            return .init(state: .notInstalled)
        }
        let observedReply = await manager.status()
        guard observedReply.wireVersion == 1,
              observedReply.error == nil,
              let observed = observedReply.observedState,
              CodexPluginLifecycleReducer.shouldAutomaticallyUpdate(
                receipt: receipt,
                observed: observed,
                shippedVersion: shippedVersion
              )
        else { return await statusFrom(reply: observedReply, receipt: receipt) }
        return await update()
    }

    private func change(
        operation: @Sendable () async -> CodexPluginHelperReply,
        reason: String
    ) async -> CodexPluginLifecycleResult {
        let reply = await operation()
        if reply.wireVersion == 1, reply.error == .partialReinstall {
            return .init(state: .needsRepair)
        }
        guard reply.wireVersion == 1, reply.error == nil else {
            return .init(state: .failed(reply.error ?? .malformedResult))
        }
        let postcondition = await manager.status()
        guard postcondition.wireVersion == 1,
              postcondition.error == nil,
              postcondition.observedState == .clean(version: shippedVersion, digest: shippedDigest)
        else { return .init(state: .failed(postcondition.error ?? .postconditionFailed)) }
        let receipt = CodexPluginReceipt(
            intent: .managedInstalled,
            managedVersion: shippedVersion,
            managedDigest: shippedDigest,
            verifiedAt: now()
        )
        do {
            try await store.recordVerified(receipt, reason: reason)
            return .init(state: .installed(version: shippedVersion), changedInstallation: true)
        } catch {
            return .init(state: .failed(.postconditionFailed))
        }
    }

    private func statusFrom(
        reply: CodexPluginHelperReply,
        receipt: CodexPluginReceipt
    ) async -> CodexPluginLifecycleResult {
        guard reply.wireVersion == 1, reply.error == nil, let observed = reply.observedState
        else { return .init(state: .failed(reply.error ?? .malformedResult)) }
        do {
            let updated = observationReceipt(current: receipt, observed: observed)
            if updated.intent != receipt.intent {
                try await store.recordObservation(
                    updated,
                    reason: "Observe Release Radar Codex plugin state"
                )
            }
            return .init(state: CodexPluginLifecycleReducer.presentation(
                receipt: updated,
                observed: observed,
                shippedVersion: shippedVersion
            ))
        } catch {
            return .init(state: .failed(.malformedResult))
        }
    }

    private func observationReceipt(
        current: CodexPluginReceipt,
        observed: CodexPluginObservedState
    ) -> CodexPluginReceipt {
        let intent: CodexPluginIntent
        switch observed {
        case .absent where current.intent == .managedInstalled:
            intent = .removed
        case let .clean(_, digest) where current.managedDigest != digest:
            intent = .attentionRequired
        case .modified, .needsRepair:
            intent = .attentionRequired
        default:
            intent = current.intent
        }
        return CodexPluginReceipt(
            intent: intent,
            managedVersion: current.managedVersion,
            managedDigest: current.managedDigest,
            verifiedAt: current.verifiedAt
        )
    }
}

public enum CodexPluginLifecycleAction: String, CaseIterable, Equatable, Sendable {
    case install
    case update
    case remove
    case reinstall
    case tryAgain
}

public enum CodexPluginLifecycleReducer {
    public static func presentation(
        receipt: CodexPluginReceipt,
        observed: CodexPluginObservedState,
        shippedVersion: String
    ) -> CodexPluginPresentationState {
        switch observed {
        case .absent:
            return .notInstalled
        case let .clean(version, digest):
            guard receipt.managedDigest == digest else { return .modified(version: version) }
            guard receipt.intent == .managedInstalled else { return .needsRepair }
            if compareSemVer(version, shippedVersion) == .orderedAscending {
                return .updateAvailable(installed: version, shipped: shippedVersion)
            }
            return .installed(version: version)
        case let .modified(version, _):
            return .modified(version: version)
        case let .needsRepair(error):
            return error == .integrityUnknown ? .failed(error) : .needsRepair
        }
    }

    public static func actions(for state: CodexPluginPresentationState) -> [CodexPluginLifecycleAction] {
        switch state {
        case .checking: []
        case .notInstalled: [.install]
        case .installed: [.remove]
        case .updateAvailable: [.update, .remove]
        case .modified, .needsRepair: [.reinstall, .remove]
        case .failed: [.tryAgain]
        }
    }

    public static func shouldAutomaticallyUpdate(
        receipt: CodexPluginReceipt,
        observed: CodexPluginObservedState,
        shippedVersion: String
    ) -> Bool {
        guard receipt.intent == .managedInstalled,
              case let .clean(version, digest) = observed,
              receipt.managedVersion == version,
              receipt.managedDigest == digest
        else { return false }
        return compareSemVer(version, shippedVersion) == .orderedAscending
    }

    private static func compareSemVer(_ lhs: String, _ rhs: String) -> ComparisonResult {
        guard let left = semVerParts(lhs), let right = semVerParts(rhs) else {
            return lhs.compare(rhs, options: .numeric)
        }
        for index in 0..<3 {
            let result = compareNumericIdentifier(left.core[index], right.core[index])
            if result != .orderedSame { return result }
        }
        switch (left.prerelease, right.prerelease) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (leftPrerelease?, rightPrerelease?):
            for index in 0..<min(leftPrerelease.count, rightPrerelease.count) {
                let leftIdentifier = leftPrerelease[index]
                let rightIdentifier = rightPrerelease[index]
                let leftIsNumeric = leftIdentifier.allSatisfy(\.isNumber)
                let rightIsNumeric = rightIdentifier.allSatisfy(\.isNumber)
                let result: ComparisonResult
                switch (leftIsNumeric, rightIsNumeric) {
                case (true, true):
                    result = compareNumericIdentifier(leftIdentifier, rightIdentifier)
                case (true, false):
                    result = .orderedAscending
                case (false, true):
                    result = .orderedDescending
                case (false, false):
                    result = leftIdentifier.compare(rightIdentifier)
                }
                if result != .orderedSame { return result }
            }
            if leftPrerelease.count == rightPrerelease.count { return .orderedSame }
            return leftPrerelease.count < rightPrerelease.count ? .orderedAscending : .orderedDescending
        }
    }

    private static func semVerParts(_ version: String) -> (core: [String], prerelease: [String]?)? {
        guard CodexPluginPackage.isStrictSemVer(version) else { return nil }
        let withoutBuild = version.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let releaseAndPrerelease = withoutBuild.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let core = releaseAndPrerelease[0].split(separator: ".").map(String.init)
        guard core.count == 3 else { return nil }
        let prerelease = releaseAndPrerelease.count == 2
            ? releaseAndPrerelease[1].split(separator: ".").map(String.init)
            : nil
        return (core, prerelease)
    }

    private static func compareNumericIdentifier(_ lhs: String, _ rhs: String) -> ComparisonResult {
        if lhs.count != rhs.count { return lhs.count < rhs.count ? .orderedAscending : .orderedDescending }
        return lhs.compare(rhs)
    }
}

public enum CodexPluginPackageError: Error, Equatable, Sendable {
    case invalidMarketplace
    case invalidManifest
    case invalidMCP
    case invalidInventory
    case invalidVersion
    case readFailed
}

public struct CodexPluginPackage: Equatable, Sendable {
    public static let pluginID = "release-radar"
    public static let relativeFiles = [
        ".codex-plugin/plugin.json",
        ".mcp.json",
        "skills/release-radar/SKILL.md",
    ]

    public let marketplaceRoot: URL
    public let pluginRoot: URL
    public let version: String
    public let digest: String
    public let relativeFiles: [String]

    public init(rootURL: URL) throws {
        try self.init(rootURL: rootURL, afterReadingFile: { _ in })
    }

    init(
        rootURL: URL,
        afterReadingFile: (String) -> Void
    ) throws {
        marketplaceRoot = rootURL
        pluginRoot = rootURL.appendingPathComponent("plugins/release-radar", isDirectory: true)
        relativeFiles = Self.relativeFiles

        let files = try Self.stableSnapshot(
            rootURL: rootURL,
            afterReadingFile: afterReadingFile
        )
        try Self.validateMarketplace(files[".agents/plugins/marketplace.json"]!)
        let manifestData = files["plugins/release-radar/.codex-plugin/plugin.json"]!
        let manifest = try Self.object(from: manifestData, error: .invalidManifest)
        guard manifest["name"] as? String == Self.pluginID,
              let manifestVersion = manifest["version"] as? String,
              Self.isStrictSemVer(manifestVersion),
              manifest["mcpServers"] as? String == "./.mcp.json",
              manifest["skills"] as? String == "./skills/"
        else { throw CodexPluginPackageError.invalidManifest }
        version = manifestVersion

        let mcpData = files["plugins/release-radar/.mcp.json"]!
        let mcp = try Self.object(from: mcpData, error: .invalidMCP)
        guard mcp.count == 1,
              let server = mcp["release_radar"] as? [String: Any],
              server["command"] as? String == "/Applications/ReleaseRadar.app/Contents/Helpers/ReleaseRadarAgentTools",
              (server["args"] as? [Any])?.isEmpty == true
        else { throw CodexPluginPackageError.invalidMCP }

        digest = Self.digest(files: files)
    }

    private static func validateMarketplace(_ data: Data) throws {
        let object = try self.object(from: data, error: .invalidMarketplace)
        guard object["name"] as? String == pluginID,
              let plugins = object["plugins"] as? [[String: Any]], plugins.count == 1,
              plugins[0]["name"] as? String == pluginID,
              let source = plugins[0]["source"] as? [String: Any],
              source["source"] as? String == "local",
              source["path"] as? String == "./plugins/release-radar"
        else { throw CodexPluginPackageError.invalidMarketplace }
    }

    private static func digest(files: [String: Data]) -> String {
        var hasher = SHA256()
        for relative in relativeFiles.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            let data = files["plugins/release-radar/\(relative)"]!
            hasher.update(data: Data(relative.utf8))
            hasher.update(data: Data([0]))
            var length = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &length) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func stableSnapshot(
        rootURL: URL,
        afterReadingFile: (String) -> Void
    ) throws -> [String: Data] {
        var checked: [CheckedDescriptor] = []
        defer { for item in checked.reversed() { close(item.fileDescriptor) } }

        func openDirectory(
            parent: Int32? = nil,
            name: String,
            entries: Set<String>
        ) throws -> Int32 {
            let descriptor = parent.map {
                openat($0, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            } ?? open(name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0,
                  let metadata = fileMetadata(descriptor),
                  (metadata.mode & S_IFMT) == S_IFDIR,
                  try directoryEntries(descriptor) == entries
            else {
                if descriptor >= 0 { close(descriptor) }
                throw CodexPluginPackageError.invalidInventory
            }
            checked.append(.init(
                fileDescriptor: descriptor,
                metadata: metadata,
                directoryEntries: entries
            ))
            return descriptor
        }

        func openFile(parent: Int32, name: String) throws -> Int32 {
            let descriptor = openat(
                parent,
                name,
                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC
            )
            guard descriptor >= 0,
                  let metadata = fileMetadata(descriptor),
                  (metadata.mode & S_IFMT) == S_IFREG
            else {
                if descriptor >= 0 { close(descriptor) }
                throw CodexPluginPackageError.invalidInventory
            }
            checked.append(.init(
                fileDescriptor: descriptor,
                metadata: metadata,
                directoryEntries: nil
            ))
            return descriptor
        }

        let root = try openDirectory(name: rootURL.path, entries: [".agents", "plugins"])
        let agents = try openDirectory(parent: root, name: ".agents", entries: ["plugins"])
        let agentPlugins = try openDirectory(
            parent: agents,
            name: "plugins",
            entries: ["marketplace.json"]
        )
        let plugins = try openDirectory(parent: root, name: "plugins", entries: [pluginID])
        let plugin = try openDirectory(
            parent: plugins,
            name: pluginID,
            entries: [".codex-plugin", ".mcp.json", "skills"]
        )
        let manifestDirectory = try openDirectory(
            parent: plugin,
            name: ".codex-plugin",
            entries: ["plugin.json"]
        )
        let skills = try openDirectory(parent: plugin, name: "skills", entries: [pluginID])
        let skillDirectory = try openDirectory(
            parent: skills,
            name: pluginID,
            entries: ["SKILL.md"]
        )
        let sources: [(String, Int32, String)] = [
            (".agents/plugins/marketplace.json", agentPlugins, "marketplace.json"),
            ("plugins/release-radar/.codex-plugin/plugin.json", manifestDirectory, "plugin.json"),
            ("plugins/release-radar/.mcp.json", plugin, ".mcp.json"),
            ("plugins/release-radar/skills/release-radar/SKILL.md", skillDirectory, "SKILL.md"),
        ]
        var files: [String: Data] = [:]
        for (relative, parent, name) in sources {
            files[relative] = try readFile(openFile(parent: parent, name: name))
            afterReadingFile(relative)
        }
        for item in checked {
            guard fileMetadata(item.fileDescriptor) == item.metadata else {
                throw CodexPluginPackageError.invalidInventory
            }
            if let expected = item.directoryEntries,
               try directoryEntries(item.fileDescriptor) != expected {
                throw CodexPluginPackageError.invalidInventory
            }
        }
        return files
    }

    private static func fileMetadata(_ descriptor: Int32) -> StableFileMetadata? {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else { return nil }
        return .init(value)
    }

    private static func directoryEntries(_ descriptor: Int32) throws -> Set<String> {
        let duplicate = dup(descriptor)
        guard duplicate >= 0, let directory = fdopendir(duplicate) else {
            if duplicate >= 0 { close(duplicate) }
            throw CodexPluginPackageError.readFailed
        }
        defer { closedir(directory) }
        rewinddir(directory)
        var names: Set<String> = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if name != ".", name != ".." { names.insert(name) }
        }
        return names
    }

    private static func readFile(_ descriptor: Int32) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 {
                if errno == EINTR { continue }
                throw CodexPluginPackageError.readFailed
            }
            result.append(contentsOf: buffer.prefix(count))
        }
    }

    private static func object(
        from data: Data,
        error: CodexPluginPackageError
    ) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw error
        }
        return object
    }

    public static func isStrictSemVer(_ version: String) -> Bool {
        guard version.utf8.count <= 128,
              version.range(of: #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"#, options: .regularExpression) != nil,
              !version.split(separator: ".").contains(where: { $0 == "." || $0 == ".." })
        else { return false }
        if let prerelease = version.split(separator: "-", maxSplits: 1).dropFirst().first?.split(separator: "+", maxSplits: 1).first {
            for component in prerelease.split(separator: ".") where component.allSatisfy(\.isNumber) {
                if component.count > 1, component.first == "0" { return false }
            }
        }
        return true
    }
}

private struct CheckedDescriptor {
    let fileDescriptor: Int32
    let metadata: StableFileMetadata
    let directoryEntries: Set<String>?
}

private struct StableFileMetadata: Equatable {
    let device: dev_t
    let inode: ino_t
    let mode: mode_t
    let size: off_t
    let modifiedSeconds: time_t
    let modifiedNanoseconds: Int64
    let changedSeconds: time_t
    let changedNanoseconds: Int64

    init(_ value: stat) {
        device = value.st_dev
        inode = value.st_ino
        mode = value.st_mode
        size = value.st_size
        modifiedSeconds = value.st_mtimespec.tv_sec
        modifiedNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changedSeconds = value.st_ctimespec.tv_sec
        changedNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }
}
