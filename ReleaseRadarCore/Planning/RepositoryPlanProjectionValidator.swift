import CryptoKit
import Foundation

public enum RepositoryPlanProjectionValidator {
    public static let maximumProjectionBytes = 1_048_576
    private static let maximumPhases = 256
    private static let maximumTickets = 5_000
    private static let maximumTasks = 5_000
    private static let maximumDependencyEdges = 20_000
    private static let maximumIdentityBytes = 256
    private static let maximumTextBytes = 4_096

    public static func validate(
        _ bytes: Data,
        against manifest: RepositoryPlanSourceManifest
    ) throws -> ValidatedRepositoryPlanProjection {
        guard bytes.count <= maximumProjectionBytes else {
            throw failure(.limitExceeded, path: "$", limit: maximumProjectionBytes, actual: bytes.count)
        }
        guard !bytes.starts(with: [0xEF, 0xBB, 0xBF]), String(data: bytes, encoding: .utf8) != nil else {
            throw failure(.invalidUTF8, path: "$")
        }

        var scanner = StrictJSONDuplicateKeyScanner(bytes: bytes)
        try scanner.validate()
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: bytes)
        } catch {
            throw failure(.malformedJSON, path: "$")
        }
        try validateShape(root)

        let projection: RepositoryPlanProjection
        do {
            projection = try JSONDecoder().decode(RepositoryPlanProjection.self, from: bytes)
        } catch let error as DecodingError {
            switch error {
            case let .keyNotFound(key, context):
                throw failure(.missingRequiredField, path: codingPath(context.codingPath + [key]))
            case let .valueNotFound(_, context):
                throw failure(.invalidValue, path: codingPath(context.codingPath))
            case let .typeMismatch(_, context):
                throw failure(.invalidValue, path: codingPath(context.codingPath))
            case let .dataCorrupted(context):
                throw failure(.invalidValue, path: codingPath(context.codingPath))
            @unknown default:
                throw failure(.invalidValue, path: "$")
            }
        } catch {
            throw failure(.invalidValue, path: "$")
        }

        try validateManifest(manifest)
        guard exact(projection.repositoryID, manifest.repositoryID) else {
            throw failure(.sourceMismatch, path: "$.repositoryID")
        }
        guard projection.format == "release-radar.repository-plan" else {
            throw failure(.unsupportedFormat, path: "$.format")
        }
        guard projection.schemaVersion == 1 else {
            throw failure(.unsupportedVersion, path: "$.schemaVersion")
        }
        try requireIdentity(projection.repositoryID, path: "$.repositoryID")
        guard validUUID(projection.projectionID) else {
            throw failure(.invalidValue, path: "$.projectionID")
        }
        guard projection.projectionRevision > 0 else {
            throw failure(.invalidValue, path: "$.projectionRevision")
        }

        let projectionDigest = digest(bytes)
        if let suppliedProjection = manifest.sources.first(where: {
            Data($0.path.utf8) == Data("docs/delivery/reconstruction-plan.json".utf8)
        }), suppliedProjection.bytes != bytes || suppliedProjection.contentSHA256 != projectionDigest {
            throw failure(.sourceMismatch, path: "$.projectionID")
        }

        guard projection.phases.count <= maximumPhases else {
            throw failure(.limitExceeded, path: "$.phases", limit: maximumPhases, actual: projection.phases.count)
        }
        guard projection.tickets.count <= maximumTickets else {
            throw failure(.limitExceeded, path: "$.tickets", limit: maximumTickets, actual: projection.tickets.count)
        }
        let taskCount = projection.tickets.reduce(0) { $0 + ($1.taskPlan?.tasks.count ?? 0) }
        guard taskCount <= maximumTasks else {
            throw failure(.limitExceeded, path: "$.tickets[*].taskPlan.tasks", limit: maximumTasks, actual: taskCount)
        }
        let edgeCount = projection.phaseDependencies.count + projection.ticketDependencies.count
        guard edgeCount <= maximumDependencyEdges else {
            throw failure(.limitExceeded, path: "$.phaseDependencies+$.ticketDependencies", limit: maximumDependencyEdges, actual: edgeCount)
        }

        let manifestByArtifact = Dictionary(
            uniqueKeysWithValues: manifest.sources.map { (Data($0.artifactID.utf8), $0) }
        )
        let documentIDs = try unique(
            projection.documents.map(\.id), path: "$.documents[*].id"
        )
        for (index, document) in projection.documents.enumerated() {
            try requireIdentity(document.id, path: "$.documents[\(index)].id")
            try requireIdentity(document.artifactID, path: "$.documents[\(index)].artifactID")
            guard validDigest(document.contentSHA256),
                  let captured = manifestByArtifact[Data(document.artifactID.utf8)],
                  captured.contentSHA256 == document.contentSHA256 else {
                throw failure(.sourceMismatch, path: "$.documents[\(index)]")
            }
        }

        guard let rootObject = root as? [String: Any] else {
            throw failure(.malformedJSON, path: "$")
        }
        let phaseIDs = try unique(projection.phases.map(\.sourceID), path: "$.phases[*].sourceID")
        for (index, phase) in projection.phases.enumerated() {
            try requireIdentity(phase.sourceID, path: "$.phases[\(index)].sourceID")
            try requireText(phase.name, path: "$.phases[\(index)].name")
            try validate(phase.sourceRefs, documentIDs: documentIDs, root: rootObject,
                         path: "$.phases[\(index)].sourceRefs")
            try validate(phase.stateEvidence, documentIDs: documentIDs, root: rootObject,
                         path: "$.phases[\(index)].stateEvidence")
            if phase.lifecycle == .completed, phase.stateEvidence.isEmpty {
                throw failure(.invalidStateEvidence, path: "$.phases[\(index)].stateEvidence")
            }
        }

        let ticketIDs = try unique(projection.tickets.map(\.sourceID), path: "$.tickets[*].sourceID")
        for (ticketIndex, ticket) in projection.tickets.enumerated() {
            let ticketPath = "$.tickets[\(ticketIndex)]"
            var taskLabels = Set<Data>()
            try requireIdentity(ticket.sourceID, path: ticketPath + ".sourceID")
            try requireText(ticket.outcome, path: ticketPath + ".outcome")
            try validate(ticket.sourceRefs, documentIDs: documentIDs, root: rootObject,
                         path: ticketPath + ".sourceRefs")
            try validate(ticket.stateEvidence, documentIDs: documentIDs, root: rootObject,
                         path: ticketPath + ".stateEvidence")
            try validate(ticket.evidenceRefs, documentIDs: documentIDs, root: rootObject,
                         path: ticketPath + ".evidenceRefs")

            guard (ticket.phaseSourceID == nil) == (ticket.lane == nil) else {
                throw failure(.invalidPlacement, path: ticketPath)
            }
            if let phaseSourceID = ticket.phaseSourceID {
                try requireIdentity(phaseSourceID, path: ticketPath + ".phaseSourceID")
                guard phaseIDs.contains(Data(phaseSourceID.utf8)) else {
                    throw failure(.invalidReference, path: ticketPath + ".phaseSourceID")
                }
            }

            if let taskPlan = ticket.taskPlan {
                guard taskPlan.sourceRevision > 0 else {
                    throw failure(.invalidValue, path: ticketPath + ".taskPlan.sourceRevision")
                }
                _ = try unique(taskPlan.tasks.map(\.sourceID), path: ticketPath + ".taskPlan.tasks[*].sourceID")
                guard taskPlan.tasks.contains(where: { $0.lifecycle == .active }) else {
                    throw failure(.invalidValue, path: ticketPath + ".taskPlan.tasks")
                }
                for (taskIndex, task) in taskPlan.tasks.enumerated() {
                    let taskPath = ticketPath + ".taskPlan.tasks[\(taskIndex)]"
                    try requireIdentity(task.sourceID, path: taskPath + ".sourceID")
                    guard validText(task.label, maximumUTF8Bytes: TicketTaskPlanningPolicy.maximumTaskLabelUTF8Bytes) else {
                        throw failure(.invalidValue, path: taskPath + ".label")
                    }
                    guard taskLabels.insert(Data(task.label.utf8)).inserted else {
                        throw failure(.duplicateIdentity, path: taskPath + ".label")
                    }
                    try requireText(task.title, path: taskPath + ".title")
                    guard task.sortOrder >= 0 else {
                        throw failure(.invalidValue, path: taskPath + ".sortOrder")
                    }
                    try validate(task.sourceRefs, documentIDs: documentIDs, root: rootObject,
                                 path: taskPath + ".sourceRefs")
                    try validate(task.stateEvidence, documentIDs: documentIDs, root: rootObject,
                                 path: taskPath + ".stateEvidence")
                    if ticket.phaseSourceID == nil, task.completion == .completed {
                        throw failure(.invalidPlacement, path: taskPath + ".completion")
                    }
                    if (task.completion == .completed || task.lifecycle == .superseded),
                       task.stateEvidence.isEmpty {
                        throw failure(.invalidStateEvidence, path: taskPath + ".stateEvidence")
                    }
                }
                if ticket.lane == .accepted,
                   taskPlan.tasks.contains(where: { $0.lifecycle == .active && $0.completion != .completed }) {
                    throw failure(.invalidValue, path: ticketPath + ".taskPlan.tasks")
                }
            }
            if ticket.lane == .accepted, ticket.stateEvidence.isEmpty {
                throw failure(.invalidStateEvidence, path: ticketPath + ".stateEvidence")
            }
        }

        try validateDependencies(
            projection.phaseDependencies,
            nodes: phaseIDs,
            documentIDs: documentIDs,
            root: rootObject,
            path: "$.phaseDependencies"
        )
        try validateDependencies(
            projection.ticketDependencies,
            nodes: ticketIDs,
            documentIDs: documentIDs,
            root: rootObject,
            path: "$.ticketDependencies"
        )

        return .init(
            projection: projection,
            bytes: bytes,
            contentSHA256: projectionDigest,
            sourceManifest: manifest
        )
    }

    private static func validateManifest(_ manifest: RepositoryPlanSourceManifest) throws {
        guard exact(manifest.projectID.rawValue, manifest.registration.projectID.rawValue),
              validIdentity(manifest.projectID.rawValue), validIdentity(manifest.rootID),
              manifest.rootPath.hasPrefix("/"), validIdentity(manifest.repositoryID),
              manifest.acceptedCatalogVersion > 0, validDigest(manifest.acceptedCatalogDigest) else {
            throw failure(.sourceMismatch, path: "manifest")
        }
        _ = try unique(manifest.sources.map(\.artifactID), path: "manifest.sources[*].artifactID")
        for (index, source) in manifest.sources.enumerated() {
            try requireIdentity(source.artifactID, path: "manifest.sources[\(index)].artifactID")
            do {
                try RepositoryDocumentReader.validatePath(source.path, limits: .init(), docsOnly: false)
            } catch {
                throw failure(.sourceMismatch, path: "manifest.sources[\(index)].path")
            }
            guard validDigest(source.contentSHA256), digest(source.bytes) == source.contentSHA256 else {
                throw failure(.sourceMismatch, path: "manifest.sources[\(index)].contentSHA256")
            }
        }
    }

    private static func validateDependencies(
        _ dependencies: [RepositoryPlanProjectionDependency],
        nodes: Set<Data>,
        documentIDs: Set<Data>,
        root: [String: Any],
        path: String
    ) throws {
        _ = try unique(dependencies.map(\.sourceID), path: path + "[*].sourceID")
        var adjacency: [Data: [Data]] = [:]
        var pairs = Set<DependencyPair>()
        for (index, dependency) in dependencies.enumerated() {
            let itemPath = path + "[\(index)]"
            try requireIdentity(dependency.sourceID, path: itemPath + ".sourceID")
            try requireIdentity(dependency.subjectSourceID, path: itemPath + ".subjectSourceID")
            try requireIdentity(dependency.dependsOnSourceID, path: itemPath + ".dependsOnSourceID")
            let subject = Data(dependency.subjectSourceID.utf8)
            let prerequisite = Data(dependency.dependsOnSourceID.utf8)
            guard subject != prerequisite, nodes.contains(subject), nodes.contains(prerequisite) else {
                throw failure(.invalidReference, path: itemPath)
            }
            guard pairs.insert(.init(subject: subject, prerequisite: prerequisite)).inserted else {
                throw failure(.duplicateIdentity, path: itemPath)
            }
            adjacency[subject, default: []].append(prerequisite)
            try validate(dependency.sourceRefs, documentIDs: documentIDs, root: root,
                         path: itemPath + ".sourceRefs")
        }

        var visiting = Set<Data>()
        var visited = Set<Data>()
        func visit(_ node: Data) -> Bool {
            if visiting.contains(node) { return true }
            if visited.contains(node) { return false }
            visiting.insert(node)
            for next in adjacency[node] ?? [] where visit(next) { return true }
            visiting.remove(node)
            visited.insert(node)
            return false
        }
        for node in nodes where visit(node) {
            throw failure(.dependencyCycle, path: path)
        }
    }

    private static func validate(
        _ references: [RepositoryPlanSourceReference],
        documentIDs: Set<Data>,
        root: [String: Any],
        path: String
    ) throws {
        for (index, reference) in references.enumerated() {
            switch reference {
            case let .projection(pointer):
                guard resolves(pointer: pointer, in: root) else {
                    throw failure(.invalidReference, path: path + "[\(index)]")
                }
            case let .document(documentID, locator):
                guard validIdentity(documentID), documentIDs.contains(Data(documentID.utf8)),
                      validText(locator) else {
                    throw failure(.invalidReference, path: path + "[\(index)]")
                }
            }
        }
    }

    private static func resolves(pointer: String, in root: Any) -> Bool {
        if pointer.isEmpty { return true }
        guard pointer.first == "/" else { return false }
        var value: Any = root
        for encodedComponent in pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            let encoded = String(encodedComponent)
            guard validPointerComponent(encoded) else { return false }
            let component = encoded
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            if let object = value as? [String: Any], let next = object[component] {
                value = next
            } else if let array = value as? [Any], let index = Int(component),
                      String(index) == component, array.indices.contains(index) {
                value = array[index]
            } else {
                return false
            }
        }
        return true
    }

    private static func validPointerComponent(_ component: String) -> Bool {
        var index = component.startIndex
        while index < component.endIndex {
            guard component[index] == "~" else {
                index = component.index(after: index)
                continue
            }
            let escaped = component.index(after: index)
            guard escaped < component.endIndex,
                  component[escaped] == "0" || component[escaped] == "1" else { return false }
            index = component.index(after: escaped)
        }
        return true
    }

    private static func unique(_ values: [String], path: String) throws -> Set<Data> {
        var result = Set<Data>()
        for value in values where !result.insert(Data(value.utf8)).inserted {
            throw failure(.duplicateIdentity, path: path)
        }
        return result
    }

    private static func requireIdentity(_ value: String, path: String) throws {
        guard validIdentity(value) else { throw failure(.invalidValue, path: path) }
    }

    private static func requireText(_ value: String, path: String) throws {
        guard validText(value) else { throw failure(.invalidValue, path: path) }
    }

    private static func validIdentity(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= maximumIdentityBytes
            && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    private static func validText(_ value: String, maximumUTF8Bytes: Int = maximumTextBytes) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= maximumUTF8Bytes
            && !value.unicodeScalars.contains(where: { $0.value == 0 })
    }

    private static func validUUID(_ value: String) -> Bool {
        guard let uuid = UUID(uuidString: value) else { return false }
        return uuid.uuidString.lowercased() == value.lowercased()
    }

    private static func validDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private static func exact(_ lhs: String, _ rhs: String) -> Bool {
        Data(lhs.utf8) == Data(rhs.utf8)
    }

    private static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func failure(
        _ code: RepositoryPlanProjectionError.Code,
        path: String?,
        limit: Int? = nil,
        actual: Int? = nil
    ) -> RepositoryPlanProjectionError {
        .init(code: code, fieldPath: path, limit: limit, actual: actual)
    }

    private static func codingPath(_ path: [any CodingKey]) -> String {
        path.reduce("$") { result, key in
            if let index = key.intValue { return result + "[\(index)]" }
            return result + "." + key.stringValue
        }
    }

    private static func validateShape(_ root: Any) throws {
        guard let object = root as? [String: Any] else {
            throw failure(.malformedJSON, path: "$")
        }
        try requireKeys(object, exactly: [
            "format", "schemaVersion", "repositoryID", "projectionID", "projectionRevision",
            "documents", "phases", "tickets", "phaseDependencies", "ticketDependencies",
        ], path: "$")

        try objects(object["documents"], path: "$.documents").enumerated().forEach { index, value in
            try requireKeys(value, exactly: ["id", "artifactID", "contentSHA256"], path: "$.documents[\(index)]")
        }
        try objects(object["phases"], path: "$.phases").enumerated().forEach { index, value in
            let path = "$.phases[\(index)]"
            try requireKeys(value, exactly: ["sourceID", "authorityClass", "sourceRefs", "name", "lifecycle", "stateEvidence"], path: path)
            try validateReferenceShapes(value["sourceRefs"], path: path + ".sourceRefs")
            try validateReferenceShapes(value["stateEvidence"], path: path + ".stateEvidence")
        }
        try objects(object["tickets"], path: "$.tickets").enumerated().forEach { index, value in
            let path = "$.tickets[\(index)]"
            try requireKeys(value, exactly: [
                "sourceID", "authorityClass", "sourceRefs", "outcome", "phaseSourceID", "lane",
                "taskPlan", "stateEvidence", "evidenceRefs",
            ], path: path)
            try validateReferenceShapes(value["sourceRefs"], path: path + ".sourceRefs")
            try validateReferenceShapes(value["stateEvidence"], path: path + ".stateEvidence")
            try validateReferenceShapes(value["evidenceRefs"], path: path + ".evidenceRefs")
            if !(value["taskPlan"] is NSNull) {
                guard let taskPlan = value["taskPlan"] as? [String: Any] else {
                    throw failure(.invalidValue, path: path + ".taskPlan")
                }
                try requireKeys(taskPlan, exactly: ["sourceRevision", "tasks"], path: path + ".taskPlan")
                try objects(taskPlan["tasks"], path: path + ".taskPlan.tasks").enumerated().forEach { taskIndex, task in
                    let taskPath = path + ".taskPlan.tasks[\(taskIndex)]"
                    try requireKeys(task, exactly: [
                        "sourceID", "authorityClass", "sourceRefs", "label", "title", "sortOrder",
                        "completion", "lifecycle", "stateEvidence",
                    ], path: taskPath)
                    try validateReferenceShapes(task["sourceRefs"], path: taskPath + ".sourceRefs")
                    try validateReferenceShapes(task["stateEvidence"], path: taskPath + ".stateEvidence")
                }
            }
        }
        for key in ["phaseDependencies", "ticketDependencies"] {
            try objects(object[key], path: "$.\(key)").enumerated().forEach { index, value in
                let path = "$.\(key)[\(index)]"
                try requireKeys(value, exactly: ["sourceID", "subjectSourceID", "dependsOnSourceID", "sourceRefs"], path: path)
                try validateReferenceShapes(value["sourceRefs"], path: path + ".sourceRefs")
            }
        }
    }

    private static func validateReferenceShapes(_ value: Any?, path: String) throws {
        try objects(value, path: path).enumerated().forEach { index, reference in
            let itemPath = path + "[\(index)]"
            guard let kind = reference["kind"] as? String else {
                throw failure(.missingRequiredField, path: itemPath + ".kind")
            }
            switch kind {
            case "projection":
                try requireKeys(reference, exactly: ["kind", "pointer"], path: itemPath)
            case "document":
                try requireKeys(reference, exactly: ["kind", "documentID", "locator"], path: itemPath)
            default:
                throw failure(.invalidValue, path: itemPath + ".kind")
            }
        }
    }

    private static func objects(_ value: Any?, path: String) throws -> [[String: Any]] {
        guard let array = value as? [Any] else { throw failure(.invalidValue, path: path) }
        return try array.enumerated().map { index, item in
            guard let object = item as? [String: Any] else {
                throw failure(.invalidValue, path: path + "[\(index)]")
            }
            return object
        }
    }

    private static func requireKeys(
        _ object: [String: Any],
        exactly expected: Set<String>,
        path: String
    ) throws {
        if let unknown = object.keys.first(where: { !expected.contains($0) }) {
            throw failure(.unknownKey, path: path + "." + unknown)
        }
        if let missing = expected.first(where: { object[$0] == nil }) {
            throw failure(.missingRequiredField, path: path + "." + missing)
        }
    }
}

private struct DependencyPair: Hashable {
    let subject: Data
    let prerequisite: Data
}

struct StrictJSONDuplicateKeyScanner {
    private static let maximumNestingDepth = 128
    private let bytes: [UInt8]
    private var index = 0

    init(bytes: Data) {
        self.bytes = Array(bytes)
    }

    mutating func validate() throws {
        skipWhitespace()
        try value(depth: 0)
        skipWhitespace()
        guard index == bytes.count else { throw malformed() }
    }

    private mutating func value(depth: Int) throws {
        skipWhitespace()
        guard index < bytes.count else { throw malformed() }
        switch bytes[index] {
        case 0x7B:
            try requireNestingDepth(depth + 1)
            try object(depth: depth + 1)
        case 0x5B:
            try requireNestingDepth(depth + 1)
            try array(depth: depth + 1)
        case 0x22: _ = try string()
        case 0x74: try literal("true")
        case 0x66: try literal("false")
        case 0x6E: try literal("null")
        default: try number()
        }
    }

    private mutating func object(depth: Int) throws {
        index += 1
        skipWhitespace()
        if consume(0x7D) { return }
        var keys = Set<Data>()
        while true {
            skipWhitespace()
            let key = try string()
            guard keys.insert(Data(key.utf8)).inserted else {
                throw RepositoryPlanProjectionError(code: .duplicateKey)
            }
            skipWhitespace()
            guard consume(0x3A) else { throw malformed() }
            try value(depth: depth)
            skipWhitespace()
            if consume(0x7D) { return }
            guard consume(0x2C) else { throw malformed() }
        }
    }

    private mutating func array(depth: Int) throws {
        index += 1
        skipWhitespace()
        if consume(0x5D) { return }
        while true {
            try value(depth: depth)
            skipWhitespace()
            if consume(0x5D) { return }
            guard consume(0x2C) else { throw malformed() }
        }
    }

    private mutating func string() throws -> String {
        guard index < bytes.count, bytes[index] == 0x22 else { throw malformed() }
        let start = index
        index += 1
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x22 {
                index += 1
                let data = Data(bytes[start..<index])
                guard let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                      let value = decoded as? String else {
                    throw malformed()
                }
                return value
            }
            if byte < 0x20 { throw malformed() }
            if byte == 0x5C {
                index += 1
                guard index < bytes.count else { throw malformed() }
                if bytes[index] == 0x75 {
                    guard index + 4 < bytes.count,
                          bytes[(index + 1)...(index + 4)].allSatisfy(isHex) else { throw malformed() }
                    index += 5
                } else {
                    guard [0x22, 0x5C, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74].contains(bytes[index]) else {
                        throw malformed()
                    }
                    index += 1
                }
            } else {
                index += 1
            }
        }
        throw malformed()
    }

    private mutating func literal(_ value: String) throws {
        let expected = Array(value.utf8)
        guard index + expected.count <= bytes.count,
              Array(bytes[index..<(index + expected.count)]) == expected else { throw malformed() }
        index += expected.count
    }

    private mutating func number() throws {
        let start = index
        while index < bytes.count, ![0x20, 0x09, 0x0A, 0x0D, 0x2C, 0x5D, 0x7D].contains(bytes[index]) {
            index += 1
        }
        guard index > start else { throw malformed() }
    }

    private mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }

    private func isHex(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
    }

    private func malformed() -> RepositoryPlanProjectionError {
        .init(code: .malformedJSON)
    }

    private func requireNestingDepth(_ depth: Int) throws {
        guard depth <= Self.maximumNestingDepth else {
            throw RepositoryPlanProjectionError(
                code: .limitExceeded,
                fieldPath: "$",
                limit: Self.maximumNestingDepth,
                actual: depth
            )
        }
    }
}
