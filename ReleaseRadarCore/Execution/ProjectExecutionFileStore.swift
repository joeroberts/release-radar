import Darwin
import Foundation

/// Fixed file contract, separate from SQLite. All authority paths stay outside worker checkouts.
public final class ProjectExecutionFileStore: @unchecked Sendable {
    public let root: URL
    private let descriptor: Int32
    private let lock = NSLock()
    public static let applicationGroup = "2UA854NLX4.com.rekonlabs.ReleaseRadar"

    public static func applicationRoot() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroup) else {
            throw ProjectExecutionError.unavailable
        }
        return container.appendingPathComponent("Execution", isDirectory: true)
    }

    public init(root: URL, create: Bool) throws {
        guard root.isFileURL, !root.path.utf8.contains(0),
              root.standardizedFileURL.path == root.resolvingSymlinksInPath().path else { throw ProjectExecutionError.conflict }
        self.root = root.standardizedFileURL
        if create { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        descriptor = open(root.path, O_SEARCH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw ProjectExecutionError.unavailable }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
            close(descriptor); throw ProjectExecutionError.conflict
        }
    }
    deinit { close(descriptor) }

    public func codexContext() throws -> CodexExecutionContext? {
        try lock.withLock {
            let path = ["CodexContext", "selection.json"]
            return try exists(path) ? read(CodexExecutionContext.self, path: path) : nil
        }
    }

    /// Explicit owner selection only. Uses the same protected selection receipt/CAS boundary.
    public func saveCodexContext(_ context: CodexExecutionContext, expected: CodexExecutionContext?) throws {
        try context.validateFolder()
        try lock.withLock {
            let path = ["CodexContext", "selection.json"]
            try withAuthorityLock(path) { try write(context, expected: expected, path: path) }
        }
    }

    public func policy(projectID: String) throws -> ProjectExecutionPolicy {
        try lock.withLock { try read(ProjectExecutionPolicy.self, path: ["Projects", ProjectExecutionPaths.component(projectID), "policy.json"]) }
    }

    public func policyIfPresent(projectID: String) throws -> ProjectExecutionPolicy? {
        try lock.withLock {
            let path = ["Projects", try ProjectExecutionPaths.component(projectID), "policy.json"]
            guard try exists(path) else { return nil }
            return try read(ProjectExecutionPolicy.self, path: path)
        }
    }

    /// Only the primary project's fixed hook file; this does not expose a general writer.
    public func hookConfiguration() throws -> Data? {
        try lock.withLock {
            let path = [".codex", "hooks.json"]
            return try exists(path) ? readBytes(path: path) : nil
        }
    }

    public func saveHookConfiguration(_ data: Data, expected: Data?) throws {
        try lock.withLock {
            guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw ProjectExecutionError.conflict }
            try writeBytes(data, expected: expected, path: [".codex", "hooks.json"])
        }
    }

    public func assignment(projectID: String, taskID: String) throws -> ProjectExecutionAssignment {
        try lock.withLock {
            let value = try read(ProjectExecutionAssignment.self, path: ["Assignments", ProjectExecutionPaths.component(projectID), ProjectExecutionPaths.component(taskID), "assignment.json"])
            try value.validated()
            guard value.registration.projectID.rawValue == projectID, value.id == taskID else { throw ProjectExecutionError.identityMismatch }
            return value
        }
    }

    public func assignments(projectID: String) throws -> [ProjectExecutionAssignment] {
        try lock.withLock {
            let project = try ProjectExecutionPaths.component(projectID)
            let path = ["Assignments", project, "unused"]
            guard try exists(["Assignments", project]) else { return [] }
            let directory = try parent(path, create: false); defer { close(directory) }
            let listing = openat(directory, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard listing >= 0, let stream = fdopendir(listing) else {
                if listing >= 0 { close(listing) }; throw ProjectExecutionError.unavailable
            }
            defer { closedir(stream) }
            var result = [ProjectExecutionAssignment]()
            errno = 0
            while let entry = readdir(stream) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
                if name == "." || name == ".." { continue }
                try ProjectExecutionPaths.component(name)
                guard result.count < 1000 else { throw ProjectExecutionError.unavailable }
                let value = try read(ProjectExecutionAssignment.self, path: ["Assignments", project, name, "assignment.json"])
                try value.validated()
                guard value.id == name, value.registration.projectID.rawValue == project else { throw ProjectExecutionError.identityMismatch }
                result.append(value); errno = 0
            }
            guard errno == 0 else { throw ProjectExecutionError.unavailable }
            return result
        }
    }

    public func savePolicy(_ value: ProjectExecutionPolicy, expected: ProjectExecutionPolicy?) throws {
        try lock.withLock {
            let path = ["Projects", try ProjectExecutionPaths.component(value.registration.projectID.rawValue), "policy.json"]
            try withAuthorityLock(path) { try write(value, expected: expected, path: path) }
        }
    }

    public func saveAssignment(_ value: ProjectExecutionAssignment, expected: ProjectExecutionAssignment?) throws {
        try value.validated()
        try lock.withLock {
            let path = ["Assignments", try ProjectExecutionPaths.component(value.registration.projectID.rawValue), try ProjectExecutionPaths.component(value.id), "assignment.json"]
            try withAuthorityLock(path) { try write(value, expected: expected, path: path) }
        }
    }

    /// Serialize cooperating native writers across process instances. The stable
    /// lock inode is separate from the atomically replaced authority JSON file.
    private func withAuthorityLock<T>(_ path: [String], _ body: () throws -> T) throws -> T {
        let directory = try parent(path, create: true); defer { close(directory) }
        let name = "." + path.last! + ".lock"
        let file = openat(directory, name, O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw ProjectExecutionError.conflict }
        defer { close(file) }
        var metadata = stat(), entry = stat()
        guard fstat(file, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == getuid(), metadata.st_mode & 0o077 == 0, metadata.st_nlink == 1 else {
            throw ProjectExecutionError.conflict
        }
        while flock(file, LOCK_EX) != 0 {
            if errno == EINTR { continue }; throw ProjectExecutionError.unavailable
        }
        defer { flock(file, LOCK_UN) }
        guard fstatat(directory, name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              metadata.st_dev == entry.st_dev, metadata.st_ino == entry.st_ino else { throw ProjectExecutionError.conflict }
        return try body()
    }

    private func parent(_ path: [String], create: Bool) throws -> Int32 {
        var current = dup(descriptor)
        guard current >= 0 else { throw ProjectExecutionError.unavailable }
        do {
            for name in path.dropLast() {
                if create, mkdirat(current, name, 0o700) != 0, errno != EEXIST { throw ProjectExecutionError.unavailable }
                let next = openat(current, name, (create ? O_RDONLY : O_SEARCH) | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw ProjectExecutionError.conflict }
                var metadata = stat()
                guard fstat(next, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
                    close(next); throw ProjectExecutionError.conflict
                }
                close(current); current = next
            }
            return current
        } catch { close(current); throw error }
    }

    private func exists(_ path: [String]) throws -> Bool {
        var current = dup(descriptor)
        guard current >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(current) }
        for component in path.dropLast() {
            let next = openat(current, component, O_SEARCH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if next < 0 {
                if errno == ENOENT { return false }
                throw ProjectExecutionError.conflict
            }
            var metadata = stat()
            guard fstat(next, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
                close(next); throw ProjectExecutionError.conflict
            }
            close(current); current = next
        }
        var metadata = stat()
        if fstatat(current, path.last!, &metadata, AT_SYMLINK_NOFOLLOW) == 0 { return true }
        if errno == ENOENT { return false }
        throw ProjectExecutionError.conflict
    }

    private func read<T: Decodable>(_ type: T.Type, path: [String]) throws -> T {
        let data = try readBytes(path: path)
        do { return try JSONDecoder().decode(type, from: data) } catch { throw ProjectExecutionError.conflict }
    }

    private func readBytes(path: [String]) throws -> Data {
        let directory = try parent(path, create: false); defer { close(directory) }
        let file = openat(directory, path.last!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard file >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(file) }
        var before = stat(), after = stat(), entry = stat()
        guard fstat(file, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(), before.st_mode & 0o022 == 0,
              before.st_size > 0, before.st_size <= 1_048_576 else { throw ProjectExecutionError.conflict }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = Darwin.read(file, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 { if errno == EINTR { continue }; throw ProjectExecutionError.unavailable }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= 1_048_576 else { throw ProjectExecutionError.conflict }
        }
        guard fstat(file, &after) == 0, fstatat(directory, path.last!, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino, before.st_ino == entry.st_ino,
              before.st_dev == entry.st_dev, before.st_size == after.st_size, before.st_size == data.count,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec, before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
        else { throw ProjectExecutionError.conflict }
        return data
    }

    private func write<T: Codable & Equatable>(_ value: T, expected: T?, path: [String]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        var expectedBytes: Data?
        if let expected {
            let current = try readBytes(path: path)
            guard try JSONDecoder().decode(T.self, from: current) == expected else { throw ProjectExecutionError.conflict }
            expectedBytes = current
        }
        try writeBytes(data, expected: expectedBytes, path: path)
    }

    private func writeBytes(_ data: Data, expected: Data?, path: [String]) throws {
        let directory = try parent(path, create: true); defer { close(directory) }
        let name = path.last!
        var metadata = stat()
        let exists = fstatat(directory, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0
        if exists {
            guard let expected, try readBytes(path: path) == expected else { throw ProjectExecutionError.conflict }
        } else {
            guard errno == ENOENT, expected == nil else { throw ProjectExecutionError.conflict }
        }
        guard data.count <= 1_048_576 else { throw ProjectExecutionError.invalidAssignment }
        let temporary = ".rr-\(UUID().uuidString).tmp"
        let file = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(file); unlinkat(directory, temporary, 0) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(file, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 { if errno == EINTR { continue }; throw ProjectExecutionError.unavailable }
                guard count > 0 else { throw ProjectExecutionError.unavailable }; offset += count
            }
        }
        guard fsync(file) == 0 else { throw ProjectExecutionError.unavailable }
        if exists {
            // Refuse an observed conflicting edit; this is not a cross-process CAS promise.
            guard try readBytes(path: path) == expected else { throw ProjectExecutionError.conflict }
            guard renameat(directory, temporary, directory, name) == 0 else { throw ProjectExecutionError.unavailable }
        } else {
            guard linkat(directory, temporary, directory, name, 0) == 0 else { throw ProjectExecutionError.conflict }
        }
        guard fsync(directory) == 0, try readBytes(path: path) == data else { throw ProjectExecutionError.unavailable }
    }
}
