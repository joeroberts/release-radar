import Foundation
import Darwin

public enum ProjectGuidanceState: Equatable, Sendable {
    case missing
    case current(version: Int)
    case handoffIncomplete(version: Int)
    case outdated(installed: Int, current: Int)
    case needsRepair
    case unavailable
}

public struct ProjectGuidanceObservation: Equatable, Sendable {
    public let projectRoot: URL?
    public let state: ProjectGuidanceState

    public init(projectRoot: URL?, state: ProjectGuidanceState) {
        self.projectRoot = projectRoot
        self.state = state
    }
}

public enum ProjectGuidanceInspection {
    public static let currentVersion = 1
    public static let handoffEvidenceIDPrefix = "release-radar-handoff:v1:"
    public static let managedBlock = """
    <!-- release-radar-guidance:v1:start -->
    ## Release Radar tracking

    This repository is tracked by Release Radar. When initializing tracking, reporting delivery status, selecting the next eligible task, or changing tracked delivery state, invoke the installed `release-radar` skill and follow it.

    - `docs/delivery/progress.md` is the repository's durable delivery source of truth.
    - Codex may update repository tracking documents under owner authorization.
    - Release Radar is the only writer of its SQLite database. Use its existing typed MCP mutations; never edit that database directly.
    - Do not claim synchronization without both a successful audited MCP result and direct readback of the corresponding repository files.
    - Preserve unrelated repository instructions, files, Codex configuration, and Release Radar state.
    <!-- release-radar-guidance:end -->
    """

    private static let startPrefix = "<!-- release-radar-guidance:v"
    private static let startSuffix = ":start -->"
    private static let endMarker = "<!-- release-radar-guidance:end -->"

    public static func inspect(
        rootURL: URL,
        hasAuditedHandoff: Bool = false
    ) -> ProjectGuidanceState {
        let agentsURL = rootURL.appendingPathComponent("AGENTS.md", isDirectory: false)
        var metadata = stat()
        let status: Int32 = agentsURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return lstat(path, &metadata)
        }
        if status != 0 {
            return errno == ENOENT ? .missing : .unavailable
        }
        guard metadata.st_mode & S_IFMT == S_IFREG else { return .unavailable }
        guard
            let data = try? Data(contentsOf: agentsURL),
            let contents = String(data: data, encoding: .utf8)
        else { return .needsRepair }
        let guidanceState = inspect(contents: contents)
        guard case let .current(version) = guidanceState else { return guidanceState }
        return hasAuditedHandoff ? guidanceState : .handoffIncomplete(version: version)
    }

    public static func inspect(contents: String?) -> ProjectGuidanceState {
        guard let contents else { return .missing }
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let starts = lines.indices.filter {
            lines[$0].hasPrefix(startPrefix) && lines[$0].hasSuffix(startSuffix)
        }
        let ends = lines.indices.filter { lines[$0] == endMarker }
        let markerLines = lines.indices.filter { lines[$0].contains("release-radar-guidance") }
        guard !markerLines.isEmpty else {
            return .missing
        }
        guard markerLines.count == 2, starts.count == 1, ends.count == 1, starts[0] < ends[0] else {
            return .needsRepair
        }

        let startLine = lines[starts[0]]
        let versionStart = startLine.index(startLine.startIndex, offsetBy: startPrefix.count)
        let versionEnd = startLine.index(startLine.endIndex, offsetBy: -startSuffix.count)
        guard let installedVersion = Int(startLine[versionStart..<versionEnd]), installedVersion >= 0 else {
            return .needsRepair
        }
        guard installedVersion <= currentVersion else { return .needsRepair }
        guard installedVersion == currentVersion else {
            return .outdated(installed: installedVersion, current: currentVersion)
        }

        let observedBlock = lines[starts[0]...ends[0]].joined(separator: "\n")
        return observedBlock == managedBlock ? .current(version: currentVersion) : .needsRepair
    }
}
