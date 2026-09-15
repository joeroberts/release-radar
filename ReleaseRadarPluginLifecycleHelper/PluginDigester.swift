import CryptoKit
import Darwin
import Foundation

enum LifecycleError: String, Codable, Error {
    case codexUnavailable, codexUntrusted, unauthorizedPeer, marketplaceConflict
    case malformedResult, outputOverflow, timeout, integrityInvalid, integrityUnknown
    case postconditionFailed, partialReinstall
}

enum PluginDigester {
    struct Package { let version: String; let digest: String }
    private static let legacyFiles = [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]
    private static let files = legacyFiles + ["skills/shared-execution/SKILL.md"]

    static func marketplacePackage(at root: URL) throws -> Package {
        let plugin = root.appendingPathComponent("plugins/release-radar", isDirectory: true)
        return try package(at: plugin, expectedVersion: nil)
    }

    static func installedPackage(home: URL, version: String) throws -> Package {
        try installedSnapshot(home: home, version: version, testEvent: nil)
    }

    #if DEBUG
    // Internal synthetic-fixture seam; production callers cannot supply hooks.
    static func installedPackage(
        home: URL, version: String, testEvent: @escaping (SnapshotEvent) throws -> Void
    ) throws -> Package {
        try installedSnapshot(home: home, version: version, testEvent: testEvent)
    }
    #endif

    enum SnapshotEvent: Equatable {
        case willOpenDirectory(String)
        case openedDirectory(String)
        case willOpenFile(String)
        case openedFile(String)
        case readChunk(String)
        case readFile(String)
        case snapshotRead
    }

    private static func installedSnapshot(
        home: URL, version: String, testEvent: ((SnapshotEvent) throws -> Void)?
    ) throws -> Package {
        guard home.isFileURL, home.path.hasPrefix("/"), !home.path.utf8.contains(0),
              isStrictSemVer(version) else { throw LifecycleError.integrityInvalid }
        let snapshot = InstalledSnapshot(testEvent: testEvent)
        var parent = try snapshot.openHome(home)
        let components = [".codex", "plugins", "cache", "release-radar", "release-radar", version]
        for (index, component) in components.enumerated() {
            parent = try snapshot.openDirectory(
                component, parent: parent, relative: "fixed/\(index)"
            )
        }
        let inventory = try snapshot.inventory(parent: parent)
        let packageFiles: [String]
        if inventory.sorted() == files.sorted() {
            packageFiles = files
        } else if inventory.sorted() == legacyFiles.sorted() {
            packageFiles = legacyFiles
        } else {
            throw LifecycleError.integrityInvalid
        }
        var contents: [String: Data] = [:]
        for relative in packageFiles.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            contents[relative] = try snapshot.readFile(relative)
        }
        try testEvent?(.snapshotRead)
        try snapshot.validate()
        guard let manifestData = contents[".codex-plugin/plugin.json"],
              let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              manifest["name"] as? String == "release-radar",
              manifest["version"] as? String == version else {
            throw LifecycleError.integrityInvalid
        }
        guard let mcpData = contents[".mcp.json"],
              let mcp = try? JSONSerialization.jsonObject(with: mcpData) as? [String: Any],
              mcp.count == 1, let server = mcp["release_radar"] as? [String: Any],
              server["command"] is String, (server["args"] as? [Any])?.isEmpty == true else {
            throw LifecycleError.integrityInvalid
        }
        var hasher = SHA256()
        for relative in packageFiles.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
            let data = contents[relative]!
            hasher.update(data: Data(relative.utf8)); hasher.update(data: Data([0]))
            var count = UInt64(data.count).bigEndian
            withUnsafeBytes(of: &count) { hasher.update(data: Data($0)) }
            hasher.update(data: data)
        }
        return Package(version: version, digest: hasher.finalize().map { String(format: "%02x", $0) }.joined())
    }

    private struct Metadata: Equatable {
        let device: dev_t
        let inode: ino_t
        let mode: mode_t
        let size: off_t
        let modifiedSeconds: time_t
        let modifiedNanoseconds: Int64
        let changedSeconds: time_t
        let changedNanoseconds: Int64

        init(_ value: stat) {
            device = value.st_dev; inode = value.st_ino; mode = value.st_mode; size = value.st_size
            modifiedSeconds = value.st_mtimespec.tv_sec
            modifiedNanoseconds = Int64(value.st_mtimespec.tv_nsec)
            changedSeconds = value.st_ctimespec.tv_sec
            changedNanoseconds = Int64(value.st_ctimespec.tv_nsec)
        }

        var type: mode_t { mode & S_IFMT }
    }

    private final class InstalledSnapshot {
        struct Handle {
            let descriptor: Int32
            let parent: Int32?
            let name: String
            let before: Metadata
        }

        let testEvent: ((SnapshotEvent) throws -> Void)?
        var handles: [Handle] = []
        var directoryInventories: [(Int32, Set<String>)] = []
        var fileEntries: [String: (parent: Int32, name: String)] = [:]

        init(testEvent: ((SnapshotEvent) throws -> Void)?) { self.testEvent = testEvent }
        deinit { for handle in handles.reversed() { close(handle.descriptor) } }

        private func failure() -> LifecycleError {
            switch errno {
            case ENOENT, ENOTDIR, ELOOP: return .integrityInvalid
            default: return .integrityUnknown
            }
        }

        private func metadata(_ descriptor: Int32) throws -> Metadata {
            var value = stat()
            guard fstat(descriptor, &value) == 0 else { throw failure() }
            return Metadata(value)
        }

        private func entry(_ name: String, parent: Int32?) throws -> Metadata {
            var value = stat()
            let result = parent.map { fstatat($0, name, &value, AT_SYMLINK_NOFOLLOW) }
                ?? lstat(name, &value)
            guard result == 0 else { throw failure() }
            return Metadata(value)
        }

        func openHome(_ home: URL) throws -> Int32 {
            try openDirectory(home.path, parent: nil, relative: "home")
        }

        func openDirectory(_ name: String, parent: Int32?, relative: String) throws -> Int32 {
            let before = try entry(name, parent: parent)
            guard before.type == S_IFDIR else { throw LifecycleError.integrityInvalid }
            try testEvent?(.willOpenDirectory(relative))
            let flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
            let descriptor = parent.map { openat($0, name, flags) } ?? open(name, flags)
            guard descriptor >= 0 else { throw failure() }
            do {
                let opened = try metadata(descriptor)
                guard before == opened else { throw LifecycleError.integrityInvalid }
                handles.append(Handle(descriptor: descriptor, parent: parent, name: name, before: opened))
            } catch {
                close(descriptor)
                throw error
            }
            try testEvent?(.openedDirectory(relative))
            return descriptor
        }

        private func names(_ descriptor: Int32) throws -> Set<String> {
            // A new open file description avoids sharing the retained handle's offset.
            let independent = openat(descriptor, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard independent >= 0 else { throw failure() }
            guard let directory = fdopendir(independent) else {
                let error = failure()
                close(independent)
                throw error
            }
            defer { closedir(directory) }
            var result: Set<String> = []
            while true {
                errno = 0
                guard let item = readdir(directory) else {
                    if errno != 0 { throw failure() }
                    break
                }
                let name = withUnsafePointer(to: &item.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
                }
                if name == "." || name == ".." { continue }
                guard !name.isEmpty, !name.contains("/"), result.insert(name).inserted else {
                    throw LifecycleError.integrityInvalid
                }
            }
            return result
        }

        func inventory(parent: Int32, relative: String = "") throws -> [String] {
            let entries = try names(parent)
            directoryInventories.append((parent, entries))
            var result: [String] = []
            for name in entries.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
                let path = relative.isEmpty ? name : "\(relative)/\(name)"
                let value = try entry(name, parent: parent)
                switch value.type {
                case S_IFDIR:
                    let child = try openDirectory(name, parent: parent, relative: path)
                    result += try inventory(parent: child, relative: path)
                case S_IFREG:
                    fileEntries[path] = (parent, name)
                    result.append(path)
                default: throw LifecycleError.integrityInvalid
                }
            }
            return result
        }

        func readFile(_ relative: String) throws -> Data {
            guard let source = fileEntries[relative] else { throw LifecycleError.integrityInvalid }
            let before = try entry(source.name, parent: source.parent)
            guard before.type == S_IFREG, before.size >= 0 else { throw LifecycleError.integrityInvalid }
            try testEvent?(.willOpenFile(relative))
            let descriptor = openat(source.parent, source.name, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { throw failure() }
            do {
                let opened = try metadata(descriptor)
                guard opened.type == S_IFREG, before == opened else { throw LifecycleError.integrityInvalid }
                handles.append(Handle(descriptor: descriptor, parent: source.parent, name: source.name, before: opened))
            } catch {
                close(descriptor)
                throw error
            }
            try testEvent?(.openedFile(relative))
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 16_384)
            while true {
                let count = Darwin.read(descriptor, &buffer, buffer.count)
                if count == 0 { break }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw failure()
                }
                data.append(contentsOf: buffer.prefix(count))
                try testEvent?(.readChunk(relative))
            }
            try testEvent?(.readFile(relative))
            guard try metadata(descriptor) == before,
                  try entry(source.name, parent: source.parent) == before,
                  data.count == before.size else { throw LifecycleError.integrityInvalid }
            return data
        }

        func validate() throws {
            for (descriptor, expected) in directoryInventories {
                guard try names(descriptor) == expected else { throw LifecycleError.integrityInvalid }
            }
            for handle in handles.reversed() {
                guard try metadata(handle.descriptor) == handle.before,
                      try entry(handle.name, parent: handle.parent) == handle.before else {
                    throw LifecycleError.integrityInvalid
                }
            }
        }
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
        let packageFiles: [String]
        if inventory.sorted() == files.sorted() {
            packageFiles = files
        } else if inventory.sorted() == legacyFiles.sorted() {
            packageFiles = legacyFiles
        } else {
            throw LifecycleError.integrityInvalid
        }
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
        for relative in packageFiles.sorted(by: { $0.utf8.lexicographicallyPrecedes($1.utf8) }) {
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
