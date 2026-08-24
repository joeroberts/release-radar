import Foundation

public protocol GitWorktreeDiscovering: Sendable {
    func discoverWorktrees(at folder: URL) throws -> [URL]
}

public struct GitWorktreeDiscovery: GitWorktreeDiscovering, Sendable {
    public init() {}

    public func discoverWorktrees(at folder: URL) throws -> [URL] {
        guard let output = try Self.runGit(["-C", folder.path, "worktree", "list", "--porcelain"]) else {
            return []
        }
        return Self.parseWorktreeList(output)
    }

    public static func discoverGitRoot(at folder: URL) -> URL? {
        guard let output = try? runGit(["-C", folder.path, "rev-parse", "--show-toplevel"]),
              let path = output.split(separator: "\n").first
        else { return nil }
        return URL(fileURLWithPath: String(path)).standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func runGit(_ arguments: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    public static func parseWorktreeList(_ output: String) -> [URL] {
        output.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let prefix = "worktree "
            guard line.hasPrefix(prefix) else { return nil }
            return URL(fileURLWithPath: String(line.dropFirst(prefix.count)))
                .standardizedFileURL
                .resolvingSymlinksInPath()
        }
    }
}
