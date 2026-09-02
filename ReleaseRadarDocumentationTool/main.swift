import Darwin
import Foundation
import ReleaseRadarCore

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3, ["check", "write"].contains(arguments[0]),
      arguments[1] == "--root", arguments[2].hasPrefix("/"),
      !arguments[2].utf8.contains(0) else {
    FileHandle.standardError.write(Data("Usage: ReleaseRadarDocumentationTool <check|write> --root <absolute-repository-root>\n".utf8))
    exit(64)
}

let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
do {
    let tool = RepositoryDocumentIndexTool()
    if arguments[0] == "check" {
        try tool.check(authorizedRoot: root)
        print("Repository documentation indexes match the catalog.")
    } else {
        let paths = try tool.write(authorizedRoot: root)
        print("Updated \(paths.count) managed index file(s).")
        for path in paths { print(path) }
    }
} catch {
    let message: String
    if let failure = error as? RepositoryDocumentError {
        message = failure.localizedDescription
    } else if let failure = error as? RepositoryDocumentIndexError {
        message = failure.localizedDescription
    } else {
        message = "Repository documentation failed. Check repository access and retry."
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
