import Darwin
import Foundation

/// Descriptor-relative I/O keeps every read below the caller-authorized root.
/// A second metadata pass detects replacement, content changes, and tree changes.
final class RepositoryDocumentReader {
    private struct Stamp: Equatable {
        let device: dev_t
        let inode: ino_t
        let mode: mode_t
        let size: off_t
        let modifiedSeconds: Int
        let modifiedNanos: Int
        let changedSeconds: Int
        let changedNanos: Int
        init(_ value: stat) {
            device = value.st_dev; inode = value.st_ino; mode = value.st_mode; size = value.st_size
            modifiedSeconds = value.st_mtimespec.tv_sec; modifiedNanos = value.st_mtimespec.tv_nsec
            changedSeconds = value.st_ctimespec.tv_sec; changedNanos = value.st_ctimespec.tv_nsec
        }
    }
    private let root: Int32
    private let rootURL: URL
    private let rootStamp: Stamp
    private let limits: RepositoryDocumentContract.Limits
    private let afterRead: ((String) -> Void)?
    private var stamps: [String: Stamp] = [:]
    private var data: [String: Data] = [:]
    private var totalBytes = 0
    private var fileCount = 0
    private var directoryCount = 0

    init(rootURL: URL, limits: RepositoryDocumentContract.Limits, afterRead: ((String) -> Void)?, beforeRootOpen: ((String) -> Void)? = nil) throws {
        guard rootURL.isFileURL else { throw RepositoryDocumentError(.unsafePath) }
        self.rootURL = rootURL
        self.limits = limits
        self.afterRead = afterRead
        root = try Self.openRoot(rootURL, beforeOpen: beforeRootOpen)
        var info = stat()
        guard fstat(root, &info) == 0 else {
            close(root)
            throw RepositoryDocumentError(.readFailed)
        }
        rootStamp = Stamp(info)
    }
    deinit { close(root) }

    private static func openRoot(_ url: URL, beforeOpen: ((String) -> Void)? = nil) throws -> Int32 {
        let path = url.path
        guard path.hasPrefix("/"), !path.utf8.contains(0) else { throw RepositoryDocumentError(.unsafePath) }
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { throw RepositoryDocumentError(.readFailed) }
        do {
            for component in path.split(separator: "/") {
                guard component != ".", component != ".." else { throw RepositoryDocumentError(.unsafePath) }
                var info = stat()
                guard fstatat(descriptor, String(component), &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                    throw RepositoryDocumentError(.readFailed)
                }
                guard info.st_mode & S_IFMT == S_IFDIR else { throw RepositoryDocumentError(.unsafeFileType) }
                beforeOpen?(String(component))
                let next = openat(descriptor, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw RepositoryDocumentError(.changedDuringRead) }
                var opened = stat()
                guard fstat(next, &opened) == 0, Stamp(opened) == Stamp(info) else {
                    close(next)
                    throw RepositoryDocumentError(.changedDuringRead)
                }
                close(descriptor)
                descriptor = next
            }
            return descriptor
        } catch {
            close(descriptor)
            throw error
        }
    }

    static func validatePath(_ path: String, limits: RepositoryDocumentContract.Limits, docsOnly: Bool = true) throws {
        guard !path.isEmpty, path.utf8.count <= limits.maximumPathBytes,
              path == path.precomposedStringWithCanonicalMapping,
              !path.hasPrefix("/"), !path.hasSuffix("/"),
              !path.contains(where: { "\\%:?#".contains($0) }),
              !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw RepositoryDocumentError(.unsafePath)
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= limits.maximumDepth, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              !docsOnly || parts.first == "docs" else { throw RepositoryDocumentError(.unsafePath) }
    }

    static func isProhibited(_ path: String) -> Bool {
        path.split(separator: "/").contains { part in
            part.hasPrefix(".") || part.hasSuffix("~") || part.hasSuffix(".tmp") || part.hasSuffix(".swp")
                || part.hasSuffix(".bak") || ["build", "DerivedData", "node_modules"].contains(String(part))
        }
    }

    private func openRelative(_ path: String, directory: Bool = false) throws -> Int32 {
        try Self.validatePath(path, limits: limits, docsOnly: false)
        var descriptor = dup(root)
        guard descriptor >= 0 else { throw RepositoryDocumentError(.readFailed, path: path) }
        do {
            let components = path.split(separator: "/").map(String.init)
            for (index, component) in components.enumerated() {
                let wantsDirectory = index < components.count - 1 || directory
                var info = stat()
                guard fstatat(descriptor, component, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                    throw RepositoryDocumentError(errno == ENOENT ? .missingFile : .readFailed, path: path)
                }
                guard info.st_mode & S_IFMT == (wantsDirectory ? S_IFDIR : S_IFREG) else {
                    throw RepositoryDocumentError(.unsafeFileType, path: path)
                }
                let next = openat(descriptor, component, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK | (wantsDirectory ? O_DIRECTORY : 0))
                guard next >= 0 else { throw RepositoryDocumentError(.changedDuringRead, path: path) }
                var opened = stat()
                guard fstat(next, &opened) == 0, Stamp(opened) == Stamp(info) else {
                    close(next)
                    throw RepositoryDocumentError(.changedDuringRead, path: path)
                }
                close(descriptor)
                descriptor = next
            }
            return descriptor
        } catch {
            close(descriptor)
            throw error
        }
    }

    func read(_ path: String, catalog: Bool = false) throws -> Data {
        if let existing = data[path] { return existing }
        let descriptor = try openRelative(path)
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw RepositoryDocumentError(.readFailed, path: path) }
        let before = Stamp(info)
        let maximum = catalog ? limits.maximumCatalogBytes : limits.maximumFileBytes
        guard info.st_size >= 0, info.st_size <= maximum, totalBytes <= limits.maximumTotalBytes - Int(info.st_size) else {
            throw RepositoryDocumentError(.limitExceeded, path: path)
        }
        var bytes = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0 {
                if errno == EINTR { continue }
                throw RepositoryDocumentError(.readFailed, path: path)
            }
            if count == 0 { break }
            guard bytes.count <= maximum - count else { throw RepositoryDocumentError(.limitExceeded, path: path) }
            bytes.append(contentsOf: buffer.prefix(count))
        }
        guard fstat(descriptor, &info) == 0, before == Stamp(info), bytes.count == Int(info.st_size) else {
            throw RepositoryDocumentError(.changedDuringRead, path: path)
        }
        totalBytes += bytes.count
        guard totalBytes <= limits.maximumTotalBytes else { throw RepositoryDocumentError(.limitExceeded, path: path) }
        stamps[path] = before
        data[path] = bytes
        afterRead?(path)
        return bytes
    }

    func inventory() throws -> (files: Set<String>, directories: Set<String>) {
        var files = Set<String>()
        var directories = Set<String>()
        try walk("docs", files: &files, directories: &directories)
        return (files, directories)
    }

    private func walk(_ path: String, files: inout Set<String>, directories: inout Set<String>) throws {
        try Self.validatePath(path, limits: limits)
        directoryCount += 1
        guard directoryCount <= limits.maximumCollectionCount else { throw RepositoryDocumentError(.limitExceeded, path: path) }
        let descriptor = try openRelative(path, directory: true)
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw RepositoryDocumentError(.readFailed, path: path) }
        stamps[path] = Stamp(info)
        directories.insert(path)
        let duplicate = dup(descriptor)
        guard duplicate >= 0 else { throw RepositoryDocumentError(.readFailed, path: path) }
        guard let stream = fdopendir(duplicate) else {
            close(duplicate)
            throw RepositoryDocumentError(.readFailed, path: path)
        }
        defer { closedir(stream) }
        var names: [String] = []
        while true {
            errno = 0
            guard let entry = readdir(stream) else {
                guard errno == 0 else { throw RepositoryDocumentError(.readFailed, path: path) }
                break
            }
            let name: String? = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(validatingCString: $0) }
            }
            guard let name else { throw RepositoryDocumentError(.invalidUTF8, path: path) }
            if name == "." || name == ".." { continue }
            names.append(name)
            guard names.count <= limits.maximumArtifactCount + limits.maximumCollectionCount else {
                throw RepositoryDocumentError(.limitExceeded, path: path)
            }
        }
        for name in names.sorted() {
            let child = path + "/" + name
            try Self.validatePath(child, limits: limits)
            guard !Self.isProhibited(child) else { throw RepositoryDocumentError(.prohibitedContent, path: child) }
            guard fstatat(descriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw RepositoryDocumentError(.changedDuringRead, path: child)
            }
            switch info.st_mode & S_IFMT {
            case S_IFDIR: try walk(child, files: &files, directories: &directories)
            case S_IFREG:
                fileCount += 1
                guard fileCount <= limits.maximumArtifactCount + 1 else { throw RepositoryDocumentError(.limitExceeded, path: child) }
                files.insert(child)
                _ = try read(child, catalog: child == RepositoryDocumentContract.catalogPath)
            default: throw RepositoryDocumentError(.unsafeFileType, path: child)
            }
        }
    }

    func verifyStable() throws {
        do {
            let currentRoot = try Self.openRoot(rootURL)
            defer { close(currentRoot) }
            var info = stat()
            guard fstat(currentRoot, &info) == 0, Stamp(info) == rootStamp else {
                throw RepositoryDocumentError(.changedDuringRead)
            }
            for (path, expected) in stamps.sorted(by: { $0.key < $1.key }) {
                let descriptor = try openRelative(path, directory: expected.mode & S_IFMT == S_IFDIR)
                defer { close(descriptor) }
                guard fstat(descriptor, &info) == 0, Stamp(info) == expected else {
                    throw RepositoryDocumentError(.changedDuringRead, path: path)
                }
            }
        } catch {
            throw RepositoryDocumentError(.changedDuringRead)
        }
    }
}
