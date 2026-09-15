import Darwin
import Foundation
import XCTest

final class InstalledPluginDigesterTests: XCTestCase {
    private let version = "1.2.3"
    private let legacyDigest = "b9a8ab9f422bf1667c3f74c1acb3fe954d0abf1ed0cc76260681ea225b50bb78"
    private let currentDigest = "198d0eb5dd466d01cc72fce616c9ce42a7bf01e39fbca933623911096b8db04a"
    private let fixed = [".codex", "plugins", "cache", "release-radar", "release-radar", "1.2.3"]

    private func fixture(current: Bool, reverse: Bool = false) throws -> (home: URL, root: URL) {
        let temporary = ProcessInfo.processInfo.environment["TMPDIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        } ?? FileManager.default.temporaryDirectory
        let home = temporary.appendingPathComponent(UUID().uuidString)
        let root = fixed.reduce(home) { $0.appendingPathComponent($1) }
        var contents: [(String, String)] = [
            (".codex-plugin/plugin.json", #"{"name":"release-radar","version":"1.2.3","extra":true}"#),
            (".mcp.json", #"{"release_radar":{"command":"synthetic","args":[],"extra":true}}"#),
            ("skills/release-radar/SKILL.md", "synthetic radar\n"),
        ]
        if current { contents.append(("skills/shared-execution/SKILL.md", "synthetic shared\n")) }
        let ordered = reverse ? Array(contents.reversed()) : contents
        for (path, value) in ordered {
            let file = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(value.utf8).write(to: file)
        }
        addTeardownBlock { try FileManager.default.removeItem(at: home) }
        return (home, root)
    }

    private func invalid(_ operation: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) {
            XCTAssertEqual($0 as? LifecycleError, .integrityInvalid, file: file, line: line)
        }
    }

    func testBothInventoriesRetainFrozenDigestsAndEmptyDirectories() throws {
        for current in [false, true] {
            for reverse in [false, true] {
                let f = try fixture(current: current, reverse: reverse)
                try FileManager.default.createDirectory(at: f.root.appendingPathComponent("harmless/empty"), withIntermediateDirectories: true)
                let package = try PluginDigester.installedPackage(home: f.home, version: version)
                XCTAssertEqual(package.version, version)
                XCTAssertEqual(package.digest, current ? currentDigest : legacyDigest)
            }
        }
    }

    func testSymlinkedFixedComponentsCannotReadExternalPackages() throws {
        for current in [false, true] {
            for index in fixed.indices {
                let f = try fixture(current: current)
                let component = fixed.prefix(index + 1).reduce(f.home) { $0.appendingPathComponent($1) }
                let parked = f.home.appendingPathComponent("external-\(index)")
                try FileManager.default.moveItem(at: component, to: parked)
                try FileManager.default.createSymbolicLink(at: component, withDestinationURL: parked)
                var reads: [String] = []
                invalid {
                    _ = try PluginDigester.installedPackage(home: f.home, version: version) {
                        if case .readChunk(let path) = $0 { reads.append(path) }
                    }
                }
                XCTAssertTrue(reads.isEmpty, "Symlink rejection must precede any package read")
            }
        }
    }

    func testVersionTraversalAndMismatchFailClosed() throws {
        let f = try fixture(current: true)
        for invalidVersion in ["../1.2.3", "1.2.3/../1.2.3", "", "01.2.3"] {
            invalid { _ = try PluginDigester.installedPackage(home: f.home, version: invalidVersion) }
        }
        let manifest = f.root.appendingPathComponent(".codex-plugin/plugin.json")
        try Data(#"{"name":"release-radar","version":"1.2.4"}"#.utf8).write(to: manifest)
        invalid { _ = try PluginDigester.installedPackage(home: f.home, version: version) }
    }

    func testHomeAndPackageSymlinksDoNotReadTargets() throws {
        for current in [false, true] {
            let dirs = [".codex-plugin", "skills", "skills/release-radar"]
                + (current ? ["skills/shared-execution"] : [])
            let paths = dirs + [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]
                + (current ? ["skills/shared-execution/SKILL.md"] : [])
            for path in paths {
                let f = try fixture(current: current)
                let source = f.root.appendingPathComponent(path)
                let external = f.home.appendingPathComponent("external")
                try FileManager.default.moveItem(at: source, to: external)
                try FileManager.default.createSymbolicLink(at: source, withDestinationURL: external)
                var reads = 0
                invalid {
                    _ = try PluginDigester.installedPackage(home: f.home, version: version) {
                        if case .readChunk = $0 { reads += 1 }
                    }
                }
                XCTAssertEqual(reads, 0)
            }
            let f = try fixture(current: current)
            let external = f.home.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
            try FileManager.default.moveItem(at: f.home, to: external)
            addTeardownBlock { try FileManager.default.removeItem(at: external) }
            try FileManager.default.createSymbolicLink(at: f.home, withDestinationURL: external)
            var reads = 0
            invalid {
                _ = try PluginDigester.installedPackage(home: f.home, version: version) {
                    if case .readChunk = $0 { reads += 1 }
                }
            }
            XCTAssertEqual(reads, 0)
        }
    }

    func testMissingExtraNonregularAndInvalidMCPFailClosed() throws {
        for current in [false, true] {
            for variant in ["missing", "extra", "fifo", "mcp", "symlink-empty-dir"] {
                let f = try fixture(current: current)
                let mcp = f.root.appendingPathComponent(".mcp.json")
                switch variant {
                case "missing": try FileManager.default.removeItem(at: mcp)
                case "extra": try Data("extra".utf8).write(to: f.root.appendingPathComponent("extra"))
                case "fifo":
                    try FileManager.default.removeItem(at: mcp)
                    XCTAssertEqual(mkfifo(mcp.path, 0o600), 0)
                case "mcp": try Data(#"{"release_radar":{"command":"synthetic","args":["unexpected"]}}"#.utf8).write(to: mcp)
                default:
                    let empty = f.home.appendingPathComponent("empty")
                    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
                    try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("extra"), withDestinationURL: empty)
                }
                invalid { _ = try PluginDigester.installedPackage(home: f.home, version: version) }
            }
        }
    }

    func testDirectoryReplacementAndRestorationIsRejected() throws {
        for current in [false, true] {
            let paths = fixed.indices.map { ("fixed/\($0)", fixed.prefix($0 + 1).joined(separator: "/")) }
                + [(".codex-plugin", fixed.joined(separator: "/") + "/.codex-plugin"),
                   ("skills/release-radar", fixed.joined(separator: "/") + "/skills/release-radar")]
                + (current ? [("skills/shared-execution", fixed.joined(separator: "/") + "/skills/shared-execution")] : [])
            for (eventPath, path) in paths {
                for restore in [false, true] {
                    let f = try fixture(current: current)
                    let source = f.home.appendingPathComponent(path)
                    // Outside every component being replaced, but within synthetic scratch.
                    let scratch = f.home.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
                    addTeardownBlock { try FileManager.default.removeItem(at: scratch) }
                    let alternate = scratch.appendingPathComponent("alternate")
                    let parked = scratch.appendingPathComponent("parked")
                    try FileManager.default.copyItem(at: source, to: alternate)
                    var ran = false
                    invalid {
                        _ = try PluginDigester.installedPackage(home: f.home, version: version) { event in
                            guard event == .openedDirectory(eventPath), !ran else { return }
                            ran = true
                            try FileManager.default.moveItem(at: source, to: parked)
                            try FileManager.default.moveItem(at: alternate, to: source)
                            if restore {
                                try FileManager.default.moveItem(at: source, to: alternate)
                                try FileManager.default.moveItem(at: parked, to: source)
                            }
                        }
                    }
                    XCTAssertTrue(ran)
                }
            }
        }
    }

    func testFileReplacementBeforeOpenAndAfterReadIsRejected() throws {
        for current in [false, true] {
            let paths = [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]
                + (current ? ["skills/shared-execution/SKILL.md"] : [])
            for path in paths {
                for beforeOpen in [false, true] {
                    let f = try fixture(current: current)
                    let source = f.root.appendingPathComponent(path)
                    let replacement = f.home.appendingPathComponent("replacement")
                    let parked = f.home.appendingPathComponent("parked")
                    try FileManager.default.copyItem(at: source, to: replacement)
                    var ran = false
                    var readTarget = false
                    invalid {
                        _ = try PluginDigester.installedPackage(home: f.home, version: version) { event in
                            if event == .readChunk(path) { readTarget = true }
                            let trigger: PluginDigester.SnapshotEvent = beforeOpen ? .willOpenFile(path) : .readFile(path)
                            guard event == trigger, !ran else { return }
                            ran = true
                            try FileManager.default.moveItem(at: source, to: parked)
                            try FileManager.default.moveItem(at: replacement, to: source)
                        }
                    }
                    XCTAssertTrue(ran)
                    if beforeOpen { XCTAssertFalse(readTarget) }
                }
            }
        }
    }

    func testSymlinkAndFIFOReplacementAfterMetadataNeverReadTargets() throws {
        for current in [false, true] {
            for fifo in [false, true] {
                let f = try fixture(current: current)
                let source = f.root.appendingPathComponent(".mcp.json")
                let external = f.home.appendingPathComponent("external")
                var ran = false
                var openedTarget = false
                var readTarget = false
                invalid {
                    _ = try PluginDigester.installedPackage(home: f.home, version: version) { event in
                        if event == .openedFile(".mcp.json") { openedTarget = true }
                        if event == .readChunk(".mcp.json") { readTarget = true }
                        guard event == .willOpenFile(".mcp.json"), !ran else { return }
                        ran = true
                        try FileManager.default.moveItem(at: source, to: external)
                        if fifo {
                            XCTAssertEqual(mkfifo(source.path, 0o600), 0)
                        } else {
                            try FileManager.default.createSymbolicLink(at: source, withDestinationURL: external)
                        }
                    }
                }
                XCTAssertTrue(ran)
                XCTAssertFalse(openedTarget)
                XCTAssertFalse(readTarget)
            }
        }
    }

    func testSameSizeFileModificationAndRestorationIsRejected() throws {
        for current in [false, true] {
            let paths = [".codex-plugin/plugin.json", ".mcp.json", "skills/release-radar/SKILL.md"]
                + (current ? ["skills/shared-execution/SKILL.md"] : [])
            for path in paths {
                let f = try fixture(current: current)
                let source = f.root.appendingPathComponent(path)
                let original = try Data(contentsOf: source)
                var ran = false
                invalid {
                    _ = try PluginDigester.installedPackage(home: f.home, version: version) { event in
                        guard event == .readChunk(path), !ran else { return }
                        ran = true
                        let descriptor = open(source.path, O_WRONLY | O_CLOEXEC)
                        XCTAssertGreaterThanOrEqual(descriptor, 0)
                        guard descriptor >= 0 else { throw LifecycleError.integrityUnknown }
                        defer { close(descriptor) }
                        var byte = original[0] ^ 1
                        XCTAssertEqual(pwrite(descriptor, &byte, 1, 0), 1)
                        byte = original[0]
                        XCTAssertEqual(pwrite(descriptor, &byte, 1, 0), 1)
                        XCTAssertEqual(fsync(descriptor), 0)
                    }
                }
                XCTAssertTrue(ran)
                XCTAssertEqual(try Data(contentsOf: source), original)
            }
        }
    }

    func testReadErrorsAreNormalizedAndSentinelsUntouched() throws {
        for current in [false, true] {
            let f = try fixture(current: current)
            let config = f.home.appendingPathComponent(".codex/config.toml")
            let sibling = f.home.appendingPathComponent(".codex/plugins/cache/other/secret")
            try FileManager.default.createDirectory(at: sibling.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sentinel = Data("synthetic sentinel".utf8)
            try sentinel.write(to: config)
            try sentinel.write(to: sibling)
            var readPaths: [String] = []
            _ = try PluginDigester.installedPackage(home: f.home, version: version) {
                if case .readFile(let path) = $0 { readPaths.append(path) }
            }
            XCTAssertEqual(readPaths.count, current ? 4 : 3)
            XCTAssertEqual(Set(readPaths).count, readPaths.count, "Read each included file once")
            XCTAssertEqual(try Data(contentsOf: config), sentinel)
            XCTAssertEqual(try Data(contentsOf: sibling), sentinel)
            let file = f.root.appendingPathComponent(".mcp.json")
            XCTAssertEqual(chmod(file.path, 0), 0)
            defer { _ = chmod(file.path, 0o600) }
            XCTAssertThrowsError(try PluginDigester.installedPackage(home: f.home, version: version)) {
                XCTAssertEqual($0 as? LifecycleError, .integrityUnknown)
                XCTAssertFalse(String(describing: $0).contains(f.home.path))
            }
        }
    }
}
