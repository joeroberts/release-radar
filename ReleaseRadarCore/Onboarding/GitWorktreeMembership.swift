import Darwin
import Foundation

/// C4 exact-pair validation only. No Git process, discovery, metadata repair or
/// access outside the two already-active folder grants.
enum GitWorktreeMembership {
    struct Proof: Equatable, Codable, Sendable {
        let commonPath: String
        let device: Int32
        let inode: UInt64
        let primaryAdmin: String
        let candidateAdmin: String
    }
    private struct Grant {
        let root: URL
        let reader: RepositoryDocumentReader
    }
    private struct Directory {
        let admin: URL
        let common: URL
        let device: Int32
        let inode: UInt64
        let stamp: RepositoryDocumentReader.Stamp
    }

    static func validate(primary: URL, candidate: URL) throws -> Proof {
        do {
            let limits = RepositoryDocumentContract.Limits(maximumFileBytes: 4096, maximumTotalBytes: 32_768)
            let grants = try [primary, candidate].map {
                Grant(root: $0, reader: try RepositoryDocumentReader(rootURL: $0, limits: limits, afterRead: nil))
            }
            let first = try directory(for: primary, grants: grants)
            let second = try directory(for: candidate, grants: grants)
            guard first.common.path == second.common.path, first.device == second.device, first.inode == second.inode,
                  first.admin.path != second.admin.path else { throw ProjectRootManagementError.wrongWorktree }
            for directory in [first, second] {
                guard try identify(admin: directory.admin, common: directory.common, grants: grants).stamp == directory.stamp else {
                    throw ProjectRootManagementError.invalidGitMetadata
                }
            }
            for grant in grants { try grant.reader.verifyStable() }
            return .init(commonPath: first.common.path, device: first.device, inode: first.inode,
                primaryAdmin: first.admin.path, candidateAdmin: second.admin.path)
        } catch let error as ProjectRootManagementError { throw error }
        catch { throw ProjectRootManagementError.invalidGitMetadata }
    }

    private static func directory(for root: URL, grants: [Grant]) throws -> Directory {
        let marker = root.appendingPathComponent(".git", isDirectory: false)
        let (reader, relative) = try locate(marker, grants: grants)
        if let fd = try? reader.openRelative(relative, directory: true) {
            var initial = stat()
            let statResult = fstat(fd, &initial)
            close(fd)
            guard statResult == 0 else { throw ProjectRootManagementError.invalidGitMetadata }
            // A redirected main .git layout is not an ordinary main worktree.
            do {
                _ = try reader.read(relative + "/commondir")
                throw ProjectRootManagementError.invalidGitMetadata
            } catch let error as RepositoryDocumentError where error.code == .missingFile { }
            let result = try identify(admin: marker, common: marker, grants: grants)
            guard result.stamp == RepositoryDocumentReader.Stamp(initial) else { throw ProjectRootManagementError.invalidGitMetadata }
            return result
        }
        let markerLine = try line(reader.read(relative))
        guard markerLine.hasPrefix("gitdir: ") else { throw ProjectRootManagementError.invalidGitMetadata }
        let admin = try pointer(String(markerLine.dropFirst(8)), relativeTo: root)
        let (adminReader, adminPath) = try locate(admin, grants: grants)
        let common = try pointer(line(adminReader.read(adminPath + "/commondir")), relativeTo: admin)
        let slotPrefix = common.path + "/worktrees/"
        guard admin.path.hasPrefix(slotPrefix), !admin.path.dropFirst(slotPrefix.count).isEmpty,
              !admin.path.dropFirst(slotPrefix.count).contains("/") else { throw ProjectRootManagementError.invalidGitMetadata }
        let backlink = try pointer(line(adminReader.read(adminPath + "/gitdir")), relativeTo: admin)
        guard backlink.path == marker.path else { throw ProjectRootManagementError.invalidGitMetadata }
        return try identify(admin: admin, common: common, grants: grants)
    }

    private static func identify(admin: URL, common: URL, grants: [Grant]) throws -> Directory {
        let (reader, path) = try locate(common, grants: grants)
        let fd = try reader.openRelative(path, directory: true)
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw ProjectRootManagementError.invalidGitMetadata }
        return .init(admin: admin, common: common, device: info.st_dev, inode: info.st_ino, stamp: RepositoryDocumentReader.Stamp(info))
    }

    private static func locate(_ path: URL, grants: [Grant]) throws -> (RepositoryDocumentReader, String) {
        // Containment precedes every filesystem access, including metadata.
        guard let grant = grants.first(where: { path.path.hasPrefix($0.root.path + "/") }) else {
            throw ProjectRootManagementError.gitMetadataOutsideAuthorization
        }
        return (grant.reader, String(path.path.dropFirst(grant.root.path.count + 1)))
    }

    private static func line(_ data: Data) throws -> String {
        guard var value = String(data: data, encoding: .utf8) else { throw ProjectRootManagementError.invalidGitMetadata }
        if value.hasSuffix("\n") { value.removeLast() }
        if value.hasSuffix("\r") { value.removeLast() }
        guard !value.isEmpty, !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
            throw ProjectRootManagementError.invalidGitMetadata
        }
        return value
    }

    private static func pointer(_ value: String, relativeTo base: URL) throws -> URL {
        guard !value.isEmpty else { throw ProjectRootManagementError.invalidGitMetadata }
        let absolute = value.hasPrefix("/")
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        var sawName = absolute
        for (index, component) in components.enumerated() {
            if absolute && index == 0 { continue }
            guard !component.isEmpty else { throw ProjectRootManagementError.invalidGitMetadata }
            if component == ".." || component == "." {
                // Leading ../ is Git's relative-link form. Never collapse a
                // potentially symlinked name/.. into apparent containment.
                guard !sawName else { throw ProjectRootManagementError.invalidGitMetadata }
            } else { sawName = true }
        }
        return URL(fileURLWithPath: value, isDirectory: true, relativeTo: absolute ? nil : URL(fileURLWithPath: base.path, isDirectory: true)).standardizedFileURL
    }
}
