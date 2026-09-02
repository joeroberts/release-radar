import Darwin
import Foundation

/// Candidates are complete before any target changes. Atomic swaps retain each
/// original inode beside its target until the whole bounded batch succeeds.
/// This is synchronous failure recovery, not a power-loss transaction.
enum RepositoryDocumentIndexWriter {
    private final class Staged {
        let path: String
        let directory: Int32
        let name: String
        let temporaryName: String
        var originalStamp: RepositoryDocumentReader.Stamp?
        var candidateStamp: RepositoryDocumentReader.Stamp?
        var swapped = false
        var retainForRecovery = false

        init(path: String, directory: Int32, temporaryName: String) {
            self.path = path
            self.directory = directory
            name = String(path.split(separator: "/").last!)
            self.temporaryName = temporaryName
        }
        deinit { close(directory) }
        func stamp(_ name: String) throws -> RepositoryDocumentReader.Stamp {
            var info = stat()
            guard fstatat(directory, name, &info, AT_SYMLINK_NOFOLLOW) == 0, info.st_mode & S_IFMT == S_IFREG else {
                throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path])
            }
            return RepositoryDocumentReader.Stamp(info)
        }
        func verify() throws {
            guard try stamp(swapped ? name : temporaryName) == candidateStamp else {
                throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path])
            }
            if swapped, try stamp(temporaryName) != originalStamp {
                throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path])
            }
        }
        var temporaryPath: String { String(path.prefix(upTo: path.lastIndex(of: "/")!)) + "/" + temporaryName }
    }

    static func replace(_ changes: [String: Data], reader: RepositoryDocumentReader,
                        beforeReplace: ((String) throws -> Void)?, beforeCleanup: ((String) -> Void)?) throws {
        guard !changes.isEmpty else { return }
        try reader.verifyStable()
        var staged: [Staged] = []
        var failure: Error?
        do {
            for path in changes.keys.sorted() {
                let parent = String(path.prefix(upTo: path.lastIndex(of: "/")!))
                let directory = try reader.openRelative(parent, directory: true)
                let entry = Staged(path: path, directory: directory, temporaryName: ".release-radar-index-\(UUID().uuidString).tmp")
                let original = try reader.openRelative(path)
                var info = stat()
                let status = fstat(original, &info)
                close(original)
                guard status == 0 else { throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path]) }
                entry.originalStamp = RepositoryDocumentReader.Stamp(info)
                let file = openat(directory, entry.temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
                guard file >= 0 else { throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path]) }
                staged.append(entry)
                do {
                    try writeAll(changes[path]!, descriptor: file)
                    guard fchmod(file, info.st_mode & 0o777) == 0, fsync(file) == 0 else {
                        throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path])
                    }
                    guard fstat(file, &info) == 0 else { throw RepositoryDocumentIndexError(code: .writeFailed, paths: [path]) }
                    entry.candidateStamp = RepositoryDocumentReader.Stamp(info)
                    close(file)
                } catch {
                    close(file)
                    throw error
                }
            }
            var replaced = Set<String>()
            for entry in staged {
                try beforeReplace?(entry.path)
                try reader.verifyStable(temporaryPaths: Set(staged.map(\.temporaryPath)), replacedPaths: replaced)
                for candidate in staged { try candidate.verify() }
                guard renameatx_np(entry.directory, entry.temporaryName, entry.directory, entry.name, UInt32(RENAME_SWAP)) == 0 else {
                    throw RepositoryDocumentIndexError(code: .writeFailed, paths: [entry.path])
                }
                entry.swapped = true
                let candidate = try entry.stamp(entry.name)
                let original = try entry.stamp(entry.temporaryName)
                guard entry.candidateStamp?.matchesAfterRename(candidate) == true,
                      entry.originalStamp?.matchesAfterRename(original) == true else {
                    entry.retainForRecovery = true
                    throw RepositoryDocumentIndexError(code: .writeFailed, paths: [entry.path])
                }
                entry.candidateStamp = candidate
                entry.originalStamp = original
                replaced.insert(entry.path)
            }
        } catch {
            failure = error
            for entry in staged.reversed() where entry.swapped {
                do { try entry.verify() }
                catch { entry.retainForRecovery = true }
                if entry.retainForRecovery { continue }
                if renameatx_np(entry.directory, entry.temporaryName, entry.directory, entry.name, UInt32(RENAME_SWAP)) == 0 {
                    entry.swapped = false
                } else {
                    entry.retainForRecovery = true
                }
            }
        }
        var originalBackups: [String] = []
        var cleanupResidue: [String] = []
        for entry in staged {
            if entry.retainForRecovery {
                originalBackups.append(entry.temporaryPath)
                continue
            }
            beforeCleanup?(entry.temporaryPath)
            if unlinkat(entry.directory, entry.temporaryName, 0) != 0 {
                cleanupResidue.append(entry.temporaryPath)
            }
        }
        if !originalBackups.isEmpty {
            throw RepositoryDocumentIndexError(code: .rollbackFailed, paths: originalBackups.sorted(),
                                               disposableCandidatePaths: cleanupResidue.sorted())
        }
        if !cleanupResidue.isEmpty {
            // A successful batch leaves obsolete originals; a failed batch that
            // rolled back leaves generated (possibly partial) candidates.
            throw RepositoryDocumentIndexError(code: failure == nil ? .cleanupFailedAfterCommit : .cleanupFailedAfterRollback,
                                               paths: cleanupResidue.sorted())
        }
        if failure != nil {
            throw RepositoryDocumentIndexError(code: .writeFailed, paths: changes.keys.sorted())
        }
    }

    private static func writeAll(_ bytes: Data, descriptor: Int32) throws {
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw RepositoryDocumentIndexError(code: .writeFailed, paths: []) }
                offset += count
            }
        }
    }
}
