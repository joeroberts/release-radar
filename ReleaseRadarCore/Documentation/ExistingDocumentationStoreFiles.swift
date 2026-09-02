import Darwin
import Foundation

/// Immutable SQLite reads assume writer quiescence. This guard rejects missing,
/// symlinked, replaced or changing databases/sidecars and never creates a path.
struct ExistingDocumentationStoreFiles: Sendable {
    private let url: URL
    private let stamps: [String: FileStamp]
    struct FileStamp: Equatable, Sendable {
        let device: UInt64; let inode: UInt64; let size: Int64
        let modifiedSeconds: Int; let modifiedNanos: Int; let changedSeconds: Int; let changedNanos: Int
        init(_ s: stat) {
            device = UInt64(s.st_dev); inode = UInt64(s.st_ino); size = s.st_size
            modifiedSeconds = s.st_mtimespec.tv_sec; modifiedNanos = s.st_mtimespec.tv_nsec
            changedSeconds = s.st_ctimespec.tv_sec; changedNanos = s.st_ctimespec.tv_nsec
        }
    }
    init(url: URL) throws { self.url = url; stamps = try Self.inspect(url) }
    func verify() throws {
        guard try Self.inspect(url) == stamps else { throw StoreError.unavailable("Documentation store changed; quiesce writers and retry") }
    }
    private static func inspect(_ url: URL) throws -> [String: FileStamp] {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0), url.path == url.standardizedFileURL.path else {
            throw StoreError.unavailable("Select an existing absolute documentation store path")
        }
        var path = ""
        for part in url.deletingLastPathComponent().path.split(separator: "/") {
            path += "/" + part
            var s = stat()
            guard lstat(path, &s) == 0, s.st_mode & S_IFMT == S_IFDIR else {
                throw StoreError.unavailable("Documentation store parent must be an existing directory without symlinks")
            }
        }
        var result: [String: FileStamp] = [:]
        for suffix in ["", "-wal", "-shm", "-journal"] {
            var s = stat()
            if lstat(url.path + suffix, &s) != 0 {
                guard suffix != "", errno == ENOENT else { throw StoreError.unavailable("Documentation store is unavailable") }
                continue
            }
            guard s.st_mode & S_IFMT == S_IFREG, suffix != "-journal" else {
                throw StoreError.unavailable("Documentation store or sidecar is unsafe or requires recovery")
            }
            guard suffix != "-wal" || s.st_size == 0 else {
                throw StoreError.unavailable("Documentation preflight requires checkpointed storage. Close all writers through supported app shutdown, then retry; residual WAL cannot be read safely without effects.")
            }
            result[suffix] = FileStamp(s)
        }
        return result
    }
}
