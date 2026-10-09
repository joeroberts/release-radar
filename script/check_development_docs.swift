import Darwin
import Foundation

private let maximumLines = 60
private let maximumBytes = 6_144
private let maximumReadBytes = maximumBytes + 1

private enum Input {
    case root(URL)
    case standardInput
}

private func usage() -> Never {
    FileHandle.standardError.write(Data("Usage: check_development_docs.swift (--root <absolute-repository-root> | --progress-stdin)\n".utf8))
    exit(64)
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

private func parseInput(arguments: [String]) -> Input {
    guard arguments.count == 1 || arguments.count == 2 else { usage() }

    if arguments == ["--progress-stdin"] {
        return .standardInput
    }

    guard arguments.count == 2, arguments[0] == "--root", arguments[1].hasPrefix("/") else {
        usage()
    }
    return .root(URL(fileURLWithPath: arguments[1], isDirectory: true))
}

private func readBoundedData(from handle: FileHandle, description: String) -> Data {
    do {
        return try handle.read(upToCount: maximumReadBytes) ?? Data()
    } catch {
        fail("Could not read \(description). Check that it is readable and retry.")
    }
}

private func requireRegularFile(at url: URL) {
    var metadata = stat()
    guard lstat(url.path, &metadata) == 0 else {
        fail("Could not inspect progress file at \(url.path). Check that docs/delivery/progress.md exists and is a regular readable file.")
    }

    guard (metadata.st_mode & S_IFMT) == S_IFREG else {
        fail("Progress file at \(url.path) must be a regular file, not a symbolic link or another special file.")
    }
}

private func progressData(for input: Input) -> Data {
    switch input {
    case .standardInput:
        return readBoundedData(from: .standardInput, description: "progress content from standard input")
    case let .root(root):
        let progress = root.appendingPathComponent("docs/delivery/progress.md", isDirectory: false)
        requireRegularFile(at: progress)
        do {
            return readBoundedData(
                from: try FileHandle(forReadingFrom: progress),
                description: "progress file at \(progress.path)"
            )
        } catch {
            fail("Could not read progress file at \(progress.path). Check that docs/delivery/progress.md exists and is a regular readable file.")
        }
    }
}

private func validate(_ data: Data) {
    guard data.count <= maximumBytes else {
        fail("Progress file has at least \(maximumReadBytes) UTF-8 bytes; reduce it to \(maximumBytes) or fewer.")
    }

    guard String(data: data, encoding: .utf8) != nil else {
        fail("Progress content must be valid UTF-8. Repair the file encoding and retry.")
    }

    let lineCount = data.reduce(into: 0) { count, byte in
        if byte == 0x0A { count += 1 }
    } + (data.last == nil || data.last == 0x0A ? 0 : 1)
    var violations: [String] = []

    if lineCount > maximumLines {
        violations.append("has \(lineCount) lines; reduce it to \(maximumLines) or fewer")
    }
    if !violations.isEmpty {
        fail("Progress file \(violations.joined(separator: "; ")).")
    }
}

private let input = parseInput(arguments: Array(CommandLine.arguments.dropFirst()))
validate(progressData(for: input))
// Temporary #166 live-routing evidence probe. This branch will not be merged.
