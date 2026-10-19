import Darwin
import Foundation

struct ProjectExecutionPurgeInventory: Codable, Equatable, Sendable {
    let registration: ProjectRegistration
    let targetPolicy: ProjectExecutionPolicy?
    let targetAssignments: [ProjectExecutionAssignment]
    let policyUpdates: [ProjectExecutionPurgePolicyUpdate]
    let blockingAssignmentIDs: [String]
}

struct ProjectExecutionPurgePolicyUpdate: Codable, Equatable, Sendable {
    let before: ProjectExecutionPolicy
    let after: ProjectExecutionPolicy
}

struct ProjectExecutionPurgeFile: Codable, Equatable, Sendable {
    let path: [String]
    let bytes: Data
}

struct ProjectExecutionPurgeFileUpdate: Codable, Equatable, Sendable {
    let path: [String]
    let before: Data
    let after: Data
}

struct ProjectExecutionPurgeStage: Codable, Equatable, Sendable {
    let id: String
    let removalID: ProjectRemovalID
    let registration: ProjectRegistration
    let deletedFiles: [ProjectExecutionPurgeFile]
    let updatedFiles: [ProjectExecutionPurgeFileUpdate]
}

/// A bounded protected-store claim used by the cleanup-preview producer.
/// The configuration owner remains responsible for the selected-context
/// observation and for interpreting missing-context claims as unresolved.
public struct ProjectExecutionProfileOwnershipClaim: Equatable, Sendable {
    public let candidateProfileID: String
    public let projectID: String
    public let registrationID: String
    public let registrationGeneration: Int
    public let assignmentID: String
    public let codexContextID: UUID?

    public init(candidateProfileID: String, projectID: String, registrationID: String,
                registrationGeneration: Int, assignmentID: String, codexContextID: UUID?) {
        self.candidateProfileID = candidateProfileID
        self.projectID = projectID
        self.registrationID = registrationID
        self.registrationGeneration = registrationGeneration
        self.assignmentID = assignmentID
        self.codexContextID = codexContextID
    }
}

/// Owns the exact writer locks and manifest lock until commit/rollback cleanup.
/// The owner flock also distinguishes a suspended live operation from a crash.
final class ProjectExecutionPurgeLease: @unchecked Sendable {
    let stage: ProjectExecutionPurgeStage
    private let descriptors: [Int32]

    fileprivate init(stage: ProjectExecutionPurgeStage, descriptors: [Int32]) {
        self.stage = stage
        self.descriptors = descriptors
    }

    deinit {
        for descriptor in descriptors.reversed() {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
    }
}

/// Fixed file contract, separate from SQLite. All authority paths stay outside worker checkouts.
public final class ProjectExecutionFileStore: @unchecked Sendable {
    public let root: URL
    private let descriptor: Int32
    private let lock = NSLock()
    public static let applicationGroup = "2UA854NLX4.com.rekonlabs.ReleaseRadar"

    public static func applicationRoot() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroup) else {
            throw ProjectExecutionError.unavailable
        }
        return container.appendingPathComponent("Execution", isDirectory: true)
    }

    public init(root: URL, create: Bool) throws {
        guard root.isFileURL, !root.path.utf8.contains(0),
              root.standardizedFileURL.path == root.resolvingSymlinksInPath().path else { throw ProjectExecutionError.conflict }
        self.root = root.standardizedFileURL
        if create { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        descriptor = open(root.path, O_SEARCH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw ProjectExecutionError.unavailable }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
            close(descriptor); throw ProjectExecutionError.conflict
        }
    }
    deinit { close(descriptor) }

    public func codexContext() throws -> CodexExecutionContext? {
        try lock.withLock {
            let path = ["CodexContext", "selection.json"]
            return try exists(path) ? read(CodexExecutionContext.self, path: path) : nil
        }
    }

    /// Explicit owner selection only. Uses the same protected selection receipt/CAS boundary.
    public func saveCodexContext(_ context: CodexExecutionContext, expected: CodexExecutionContext?) throws {
        try context.validateFolder()
        try withAuthorityLock(["context-selection"]) {
            try lock.withLock {
                let path = ["CodexContext", "selection.json"]
                if let expected, !expected.identifiesSameFolder(as: context) {
                    try requireRetiredCodexResources()
                }
                try withAuthorityLock(path) { try write(context, expected: expected, path: path) }
            }
        }
    }

    public func policy(projectID: String) throws -> ProjectExecutionPolicy {
        try lock.withLock { try read(ProjectExecutionPolicy.self, path: ["Projects", ProjectExecutionPaths.component(projectID), "policy.json"]) }
    }

    public func policyIfPresent(projectID: String) throws -> ProjectExecutionPolicy? {
        try lock.withLock {
            let path = ["Projects", try ProjectExecutionPaths.component(projectID), "policy.json"]
            guard try exists(path) else { return nil }
            return try read(ProjectExecutionPolicy.self, path: path)
        }
    }

    /// Only the primary project's fixed hook file; this does not expose a general writer.
    public func hookConfiguration() throws -> Data? {
        try lock.withLock {
            let path = [".codex", "hooks.json"]
            return try exists(path) ? readBytes(path: path) : nil
        }
    }

    public func saveHookConfiguration(_ data: Data, expected: Data?) throws {
        try lock.withLock {
            guard (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { throw ProjectExecutionError.conflict }
            try writeBytes(data, expected: expected, path: [".codex", "hooks.json"])
        }
    }

    public func assignment(projectID: String, taskID: String) throws -> ProjectExecutionAssignment {
        try lock.withLock {
            let value = try read(ProjectExecutionAssignment.self, path: ["Assignments", ProjectExecutionPaths.component(projectID), ProjectExecutionPaths.component(taskID), "assignment.json"])
            try value.validated()
            guard value.registration.projectID.rawValue == projectID, value.id == taskID else { throw ProjectExecutionError.identityMismatch }
            return value
        }
    }

    public func assignmentIfPresent(projectID: String, taskID: String) throws -> ProjectExecutionAssignment? {
        try lock.withLock {
            let path = ["Assignments", try ProjectExecutionPaths.component(projectID), try ProjectExecutionPaths.component(taskID), "assignment.json"]
            guard try exists(path) else { return nil }
            let value = try read(ProjectExecutionAssignment.self, path: path)
            try value.validated()
            guard value.registration.projectID.rawValue == projectID, value.id == taskID else {
                throw ProjectExecutionError.identityMismatch
            }
            return value
        }
    }

    public func assignments(projectID: String) throws -> [ProjectExecutionAssignment] {
        try lock.withLock {
            let project = try ProjectExecutionPaths.component(projectID)
            let path = ["Assignments", project, "unused"]
            guard try exists(["Assignments", project]) else { return [] }
            let directory = try parent(path, create: false); defer { close(directory) }
            let listing = openat(directory, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard listing >= 0, let stream = fdopendir(listing) else {
                if listing >= 0 { close(listing) }; throw ProjectExecutionError.unavailable
            }
            defer { closedir(stream) }
            var result = [ProjectExecutionAssignment]()
            errno = 0
            while let entry = readdir(stream) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                }
                if name == "." || name == ".." { continue }
                try ProjectExecutionPaths.component(name)
                guard result.count < 1000 else { throw ProjectExecutionError.unavailable }
                let value = try read(ProjectExecutionAssignment.self, path: ["Assignments", project, name, "assignment.json"])
                try value.validated()
                guard value.id == name, value.registration.projectID.rawValue == project else { throw ProjectExecutionError.identityMismatch }
                result.append(value); errno = 0
            }
            guard errno == 0 else { throw ProjectExecutionError.unavailable }
            return result
        }
    }

    /// Reads at most two relevant claims for each candidate profile from every
    /// protected assignment namespace. Known other-context records cannot
    /// compete with the selected context; an absent context is retained so the
    /// caller can fail closed. This is an observation, not a global snapshot.
    public func profileOwnershipClaims(candidateProfileIDs: Set<String>,
                                       selectedCodexContextID: UUID) throws -> [ProjectExecutionProfileOwnershipClaim] {
        guard !candidateProfileIDs.isEmpty else { return [] }
        let candidates = try Set(candidateProfileIDs.map { try ProjectExecutionPaths.component($0) })
        return try lock.withLock {
            var claims = [ProjectExecutionProfileOwnershipClaim]()
            var retainedCounts = Dictionary(uniqueKeysWithValues: candidates.map { ($0, 0) })
            for project in try childNames(["Assignments"]) {
                for task in try childNames(["Assignments", project]) {
                    let value = try read(ProjectExecutionAssignment.self,
                                         path: ["Assignments", project, task, "assignment.json"])
                    try value.validated()
                    guard value.id == task, value.registration.projectID.rawValue == project else {
                        throw ProjectExecutionError.identityMismatch
                    }
                    guard candidates.contains(value.permissionProfile),
                          value.codexContextID == nil || value.codexContextID == selectedCodexContextID,
                          retainedCounts[value.permissionProfile, default: 0] < 2 else { continue }
                    guard let registrationGeneration = Int(exactly: value.registration.requestGeneration) else {
                        throw ProjectExecutionError.unavailable
                    }
                    claims.append(.init(candidateProfileID: value.permissionProfile, projectID: project,
                                        registrationID: value.registration.registrationID,
                                        registrationGeneration: registrationGeneration,
                                        assignmentID: value.id, codexContextID: value.codexContextID))
                    retainedCounts[value.permissionProfile, default: 0] += 1
                }
            }
            return claims.sorted { left, right in
                if left.candidateProfileID != right.candidateProfileID {
                    return left.candidateProfileID < right.candidateProfileID
                }
                if left.projectID != right.projectID { return left.projectID < right.projectID }
                if left.registrationID != right.registrationID { return left.registrationID < right.registrationID }
                if left.registrationGeneration != right.registrationGeneration {
                    return left.registrationGeneration < right.registrationGeneration
                }
                if left.assignmentID != right.assignmentID { return left.assignmentID < right.assignmentID }
                return (left.codexContextID?.uuidString ?? "") < (right.codexContextID?.uuidString ?? "")
            }
        }
    }

    public func savePolicy(_ value: ProjectExecutionPolicy, expected: ProjectExecutionPolicy?) throws {
        let path = ["Projects", try ProjectExecutionPaths.component(value.registration.projectID.rawValue), "policy.json"]
        // Store transactions reconcile synchronously. Never wait here for a
        // purge lease whose owner may itself be awaiting the store actor, or
        // for a context-selection holder waiting on that lease.
        try withAuthorityLock(["context-selection"], nonblocking: true) {
            try withAuthorityLock(path, nonblocking: true) {
                try lock.withLock { try write(value, expected: expected, path: path) }
            }
        }
    }

    public func saveAssignment(_ value: ProjectExecutionAssignment, expected: ProjectExecutionAssignment?) throws {
        try value.validated()
        let selectionSensitive = expected == nil || value.state == .preparing || value.state == .authorized
        let project = try ProjectExecutionPaths.component(value.registration.projectID.rawValue)
        let path = ["Assignments", project, try ProjectExecutionPaths.component(value.id), "assignment.json"]
        let persist = {
            try self.withAuthorityLocks([path, ["Projects", project, "policy.json"]], nonblocking: true) {
                try self.lock.withLock {
                    if selectionSensitive {
                        try self.requireSelectedCodexContext(value.codexContextID)
                    }
                    try self.write(value, expected: expected, path: path)
                }
            }
        }
        if selectionSensitive { try withAuthorityLock(["context-selection"], nonblocking: true, persist) }
        else { try persist() } // STOP/closure cannot wait behind unrelated provisioning.
    }

    /// Validate selection before materializing a checkout, then persist its intent
    /// before allowing a different-home selection to inspect the resource inventory.
    public func createAssignment(codexContextID: UUID?, prepare: () throws -> ProjectExecutionAssignment) throws -> ProjectExecutionAssignment {
        try withProjectExecutionPreparationStage(.assignmentStoreIntegrity) {
            try withAuthorityLock(["context-selection"]) {
                try lock.withLock { try requireSelectedCodexContext(codexContextID) }
                let value = try prepare() // Keep the instance mutex available to STOP/closure.
                try value.validated()
                guard value.codexContextID == codexContextID else { throw CodexExecutionContextError.changed }
                try withProjectExecutionPreparationStage(.assignmentStoreCompareAndSwap) {
                    let project = try ProjectExecutionPaths.component(value.registration.projectID.rawValue)
                    let path = ["Assignments", project, try ProjectExecutionPaths.component(value.id), "assignment.json"]
                    try withAuthorityLocks([path, ["Projects", project, "policy.json"]]) {
                        try lock.withLock { try write(value, expected: Optional<ProjectExecutionAssignment>.none, path: path) }
                    }
                }
                return value
            }
        }
    }

    func permanentPurgeInventory(registration: ProjectRegistration) throws -> ProjectExecutionPurgeInventory {
        try lock.withLock { try permanentPurgeInventoryUnlocked(registration: registration) }
    }

    func stagePermanentPurge(
        removalID: ProjectRemovalID,
        expected: ProjectExecutionPurgeInventory
    ) throws -> ProjectExecutionPurgeLease {
        let project = try ProjectExecutionPaths.component(expected.registration.projectID.rawValue)
        let paths = [["Projects", project, "policy.json"]]
            + expected.targetAssignments.map { ["Assignments", project, $0.id, "assignment.json"] }
            + expected.policyUpdates.map { ["Projects", $0.before.registration.projectID.rawValue, "policy.json"] }
        var descriptors = try acquireAuthorityLocks(paths)
        var transferred = false
        defer { if !transferred { releaseAuthorityLocks(descriptors) } }
        let stage = try lock.withLock {
            let current = try permanentPurgeInventoryUnlocked(registration: expected.registration)
            guard current == expected else { throw ProjectExecutionError.conflict }
            guard current.blockingAssignmentIDs.isEmpty else { throw ProjectExecutionError.assignmentNotAuthorized }

            let project = try ProjectExecutionPaths.component(expected.registration.projectID.rawValue)
            var deleted = [ProjectExecutionPurgeFile]()
            if current.targetPolicy != nil {
                let path = ["Projects", project, "policy.json"]
                deleted.append(.init(path: path, bytes: try readBytes(path: path)))
            }
            for assignment in current.targetAssignments {
                let path = [
                    "Assignments", project,
                    try ProjectExecutionPaths.component(assignment.id), "assignment.json",
                ]
                deleted.append(.init(path: path, bytes: try readBytes(path: path)))
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let updates = try current.policyUpdates.map { update -> ProjectExecutionPurgeFileUpdate in
                let path = [
                    "Projects", try ProjectExecutionPaths.component(update.before.registration.projectID.rawValue),
                    "policy.json",
                ]
                return .init(
                    path: path,
                    before: try readBytes(path: path),
                    after: try encoder.encode(update.after)
                )
            }
            let stage = ProjectExecutionPurgeStage(
                id: UUID().uuidString,
                removalID: removalID,
                registration: expected.registration,
                deletedFiles: deleted,
                updatedFiles: updates
            )
            let manifestPath = ["PermanentPurge", stage.id]
            guard let owner = try acquireAuthorityLock(manifestPath, nonblocking: true) else {
                throw ProjectExecutionError.conflict
            }
            descriptors.append(owner)
            let manifest = try encoder.encode(stage)
            try writeBytes(manifest, expected: nil, path: manifestPath)
            do {
                for file in deleted { try removeBytes(path: file.path, expected: file.bytes) }
                for update in updates {
                    try writeBytes(update.after, expected: update.before, path: update.path)
                }
                return stage
            } catch {
                try? restorePermanentPurgeUnlocked(stage, manifestBytes: manifest)
                throw error
            }
        }
        transferred = true
        return ProjectExecutionPurgeLease(stage: stage, descriptors: descriptors)
    }

    func pendingPermanentPurgeStages() throws -> [ProjectExecutionPurgeStage] {
        try lock.withLock {
            let names = try childNames(["PermanentPurge"], metadataEntries: true)
            for name in names where name.hasPrefix(".rr-") && name.hasSuffix(".tmp") {
                _ = try validatedTemporaryPurgeStage(readBytes(path: ["PermanentPurge", name]))
            }
            return try names.filter { !$0.hasPrefix(".") }.sorted().map { name in
                let stage = try read(ProjectExecutionPurgeStage.self, path: ["PermanentPurge", name])
                guard stage.id == name else { throw ProjectExecutionError.identityMismatch }
                try validate(stage: stage)
                return stage
            }
        }
    }

    /// A live owner wins even while suspended awaiting SQLite. Recovery never
    /// waits for it or interprets a still-existing removal row as a rollback.
    func recoverPermanentPurgeLease(_ stage: ProjectExecutionPurgeStage) throws -> ProjectExecutionPurgeLease? {
        try validate(stage: stage)
        guard let owner = try acquireAuthorityLock(["PermanentPurge", stage.id], nonblocking: true) else { return nil }
        var descriptors = [owner]
        var transferred = false
        defer { if !transferred { releaseAuthorityLocks(descriptors) } }
        guard try lock.withLock({ try exists(["PermanentPurge", stage.id]) }) else {
            try lock.withLock {
                try removeLockFile(for: ["PermanentPurge", stage.id])
                try removeEmptyDirectory(["PermanentPurge"])
            }
            return nil
        }
        let project = try ProjectExecutionPaths.component(stage.registration.projectID.rawValue)
        descriptors += try acquireAuthorityLocks(
            [["Projects", project, "policy.json"]] + stage.deletedFiles.map(\.path) + stage.updatedFiles.map(\.path)
        )
        try lock.withLock { _ = try manifestBytes(for: stage) }
        transferred = true
        return ProjectExecutionPurgeLease(stage: stage, descriptors: descriptors)
    }

    func restorePermanentPurge(_ lease: ProjectExecutionPurgeLease) throws {
        let stage = lease.stage
        try lock.withLock {
            let manifest = try manifestBytes(for: stage)
            try restorePermanentPurgeUnlocked(stage, manifestBytes: manifest)
        }
    }

    func finalizePermanentPurge(_ lease: ProjectExecutionPurgeLease) throws {
        let stage = lease.stage
        try lock.withLock {
            let manifest = try manifestBytes(for: stage)
            for file in stage.deletedFiles {
                if try exists(file.path) { try removeBytes(path: file.path, expected: file.bytes) }
            }
            for update in stage.updatedFiles {
                if try readBytes(path: update.path) == update.before {
                    try writeBytes(update.after, expected: update.before, path: update.path)
                } else {
                    guard try readBytes(path: update.path) == update.after else {
                        throw ProjectExecutionError.conflict
                    }
                }
            }
            try removeTargetMetadataDirectories(after: stage)
            try removePurgeManifest(stage, bytes: manifest)
        }
    }

    private func permanentPurgeInventoryUnlocked(
        registration: ProjectRegistration
    ) throws -> ProjectExecutionPurgeInventory {
        let project = try ProjectExecutionPaths.component(registration.projectID.rawValue)
        let policyPath = ["Projects", project, "policy.json"]
        let storedPolicy = try exists(policyPath) ? read(ProjectExecutionPolicy.self, path: policyPath) : nil
        let targetPolicy = storedPolicy.map { Self.sameRegistration($0.registration, registration) } == true ? storedPolicy : nil

        var assignments = [ProjectExecutionAssignment]()
        for task in try childNames(["Assignments", project]) {
            let value = try read(
                ProjectExecutionAssignment.self,
                path: ["Assignments", project, task, "assignment.json"]
            )
            try value.validated()
            guard value.id == task, value.registration.projectID.rawValue == project else {
                throw ProjectExecutionError.identityMismatch
            }
            if Self.sameRegistration(value.registration, registration) { assignments.append(value) }
        }
        assignments.sort { $0.id < $1.id }

        var updates = [ProjectExecutionPurgePolicyUpdate]()
        for policyProject in try childNames(["Projects"]) {
            let path = ["Projects", policyProject, "policy.json"]
            if try !exists(path) {
                guard try childNames(["Projects", policyProject], metadataEntries: true).allSatisfy({ $0 == ".policy.json.lock" }) else {
                    throw ProjectExecutionError.conflict
                }
                continue
            }
            let policy = try read(ProjectExecutionPolicy.self, path: path)
            guard policy.registration.projectID.rawValue == policyProject else {
                throw ProjectExecutionError.identityMismatch
            }
            guard !Self.sameRegistration(policy.registration, registration),
                  policy.previousProjectIDs?.contains(registration.projectID.rawValue) == true else { continue }
            var updated = policy
            updated.previousProjectIDs = policy.previousProjectIDs?.filter {
                $0 != registration.projectID.rawValue
            }
            updates.append(.init(before: policy, after: updated))
        }
        updates.sort { $0.before.registration.projectID.rawValue < $1.before.registration.projectID.rawValue }

        let blockers = assignments.filter(Self.blocksPermanentPurge).map(\.id).sorted()
        return .init(
            registration: registration,
            targetPolicy: targetPolicy,
            targetAssignments: assignments,
            policyUpdates: updates,
            blockingAssignmentIDs: blockers
        )
    }

    private static func sameRegistration(_ lhs: ProjectRegistration, _ rhs: ProjectRegistration) -> Bool {
        lhs.projectID == rhs.projectID && lhs.registrationID == rhs.registrationID
    }

    private static func blocksPermanentPurge(_ assignment: ProjectExecutionAssignment) -> Bool {
        assignment.state == .authorized
            || assignment.state == .preparing
            || assignment.state == .unknown
            || assignment.state == .stopped
            || assignment.uncertainOutcome == true
            || assignment.finalizationFailed == true
            || assignment.retirement.map { !$0.completed } == true
            || assignment.profileCleanupReceipt.map {
                $0.state != .removalVerified
                    || $0.helperClosureState != .verified
                    || $0.finalizationPending
            } == true
            || ((assignment.sessionID != nil || assignment.launchReserved == true)
                && assignment.connectionClosed != true && assignment.state != .closed)
    }

    private func validate(stage: ProjectExecutionPurgeStage) throws {
        guard !stage.id.isEmpty else { throw ProjectExecutionError.identityMismatch }
        try ProjectExecutionPaths.component(stage.id)
        let project = try ProjectExecutionPaths.component(stage.registration.projectID.rawValue)
        for file in stage.deletedFiles {
            if file.path == ["Projects", project, "policy.json"] {
                let policy = try JSONDecoder().decode(ProjectExecutionPolicy.self, from: file.bytes)
                guard Self.sameRegistration(policy.registration, stage.registration) else {
                    throw ProjectExecutionError.identityMismatch
                }
                continue
            }
            guard file.path.count == 4,
                  file.path[0] == "Assignments",
                  file.path[1] == project,
                  file.path[3] == "assignment.json" else {
                throw ProjectExecutionError.identityMismatch
            }
            try ProjectExecutionPaths.component(file.path[2])
            let assignment = try JSONDecoder().decode(ProjectExecutionAssignment.self, from: file.bytes)
            try assignment.validated()
            guard assignment.id == file.path[2], Self.sameRegistration(assignment.registration, stage.registration),
                  !Self.blocksPermanentPurge(assignment) else { throw ProjectExecutionError.identityMismatch }
        }
        for update in stage.updatedFiles {
            guard update.path.count == 3,
                  update.path[0] == "Projects",
                  update.path[2] == "policy.json" else {
                throw ProjectExecutionError.identityMismatch
            }
            let updateProject = update.path[1]
            try ProjectExecutionPaths.component(updateProject)
            guard let before = try? JSONDecoder().decode(ProjectExecutionPolicy.self, from: update.before),
                  let after = try? JSONDecoder().decode(ProjectExecutionPolicy.self, from: update.after),
                  !Self.sameRegistration(before.registration, stage.registration),
                  before.registration.projectID.rawValue == updateProject,
                  before.previousProjectIDs?.contains(project) == true else {
                throw ProjectExecutionError.identityMismatch
            }
            var expected = before
            expected.previousProjectIDs = before.previousProjectIDs?.filter { $0 != project }
            guard after == expected else { throw ProjectExecutionError.identityMismatch }
        }
    }

    private func manifestBytes(for stage: ProjectExecutionPurgeStage) throws -> Data {
        try validate(stage: stage)
        let path = ["PermanentPurge", stage.id]
        let bytes = try readBytes(path: path)
        guard try JSONDecoder().decode(ProjectExecutionPurgeStage.self, from: bytes) == stage else {
            throw ProjectExecutionError.conflict
        }
        return bytes
    }

    private func restorePermanentPurgeUnlocked(
        _ stage: ProjectExecutionPurgeStage,
        manifestBytes: Data
    ) throws {
        for file in stage.deletedFiles {
            if try exists(file.path) {
                guard try readBytes(path: file.path) == file.bytes else { throw ProjectExecutionError.conflict }
            } else {
                try writeBytes(file.bytes, expected: nil, path: file.path)
            }
        }
        for update in stage.updatedFiles {
            let current = try readBytes(path: update.path)
            if current == update.after {
                try writeBytes(update.before, expected: update.after, path: update.path)
            } else if current != update.before {
                throw ProjectExecutionError.conflict
            }
        }
        for file in stage.deletedFiles {
            let names = try childNames(Array(file.path.dropLast()), metadataEntries: true)
            let allowed = Set([file.path.last!, "." + file.path.last! + ".lock"])
            guard names.allSatisfy(allowed.contains) else { throw ProjectExecutionError.conflict }
        }
        let project = try ProjectExecutionPaths.component(stage.registration.projectID.rawValue)
        let policyPath = ["Projects", project, "policy.json"]
        if try !exists(policyPath) {
            try removeLockFile(for: policyPath)
            try removeEmptyDirectory(["Projects", project], requireEmpty: true)
        }
        try removePurgeManifest(stage, bytes: manifestBytes)
    }

    private func removePurgeManifest(_ stage: ProjectExecutionPurgeStage, bytes: Data) throws {
        // A crash between link/rename and writeBytes' deferred unlink can leave
        // an identifying manifest copy. Only remove a decoded exact-stage copy;
        // opaque interrupted writes remain recoverable and block completion.
        for name in try childNames(["PermanentPurge"], metadataEntries: true) where name.hasPrefix(".rr-") && name.hasSuffix(".tmp") {
            let path = ["PermanentPurge", name]
            let temporary = try readBytes(path: path)
            let candidate = try validatedTemporaryPurgeStage(temporary)
            if candidate.id == stage.id {
                guard candidate == stage else { throw ProjectExecutionError.conflict }
                try removeBytes(path: path, expected: temporary)
            }
        }
        try removeBytes(path: ["PermanentPurge", stage.id], expected: bytes)
        try removeLockFile(for: ["PermanentPurge", stage.id])
        try removeEmptyDirectory(["PermanentPurge"])
    }

    private func validatedTemporaryPurgeStage(_ bytes: Data) throws -> ProjectExecutionPurgeStage {
        let candidate = try JSONDecoder().decode(ProjectExecutionPurgeStage.self, from: bytes)
        try validate(stage: candidate)
        // A temporary file may predate publication of its manifest. Without a
        // matching durable manifest, preserve it and block both discovery and
        // finalization; a new purge must not hide an older identifying orphan.
        guard try exists(["PermanentPurge", candidate.id]) else { throw ProjectExecutionError.conflict }
        _ = try manifestBytes(for: candidate)
        return candidate
    }

    private func removeBytes(path: [String], expected: Data) throws {
        guard try readBytes(path: path) == expected else { throw ProjectExecutionError.conflict }
        let directory = try parent(path, create: false)
        defer { close(directory) }
        guard unlinkat(directory, path.last!, 0) == 0, fsync(directory) == 0 else {
            throw ProjectExecutionError.unavailable
        }
    }

    private func removeTargetMetadataDirectories(after stage: ProjectExecutionPurgeStage) throws {
        for file in stage.deletedFiles where file.path.first == "Assignments" {
            try removeLockFile(for: file.path)
            try removeEmptyDirectory(Array(file.path.dropLast()), requireEmpty: true)
        }
        let project = try ProjectExecutionPaths.component(stage.registration.projectID.rawValue)
        // Every remaining task must prove a different registration. Unknown
        // directories/temp files keep the recovery manifest and fail cleanup.
        for task in try childNames(["Assignments", project]) {
            let assignment = try read(ProjectExecutionAssignment.self, path: ["Assignments", project, task, "assignment.json"])
            try assignment.validated()
            guard assignment.id == task, assignment.registration.projectID.rawValue == project,
                  !Self.sameRegistration(assignment.registration, stage.registration) else {
                throw ProjectExecutionError.conflict
            }
        }
        let policyPath = ["Projects", project, "policy.json"]
        if try exists(policyPath) {
            let policy = try read(ProjectExecutionPolicy.self, path: policyPath)
            guard policy.registration.projectID.rawValue == project,
                  !Self.sameRegistration(policy.registration, stage.registration) else {
                throw ProjectExecutionError.conflict
            }
        } else {
            try removeLockFile(for: policyPath)
            try removeEmptyDirectory(["Projects", project], requireEmpty: true)
        }
        try removeEmptyDirectory(["Assignments", project])
    }

    private func removeLockFile(for path: [String]) throws {
        let lockPath = Array(path.dropLast()) + ["." + path.last! + ".lock"]
        guard try exists(lockPath) else { return }
        let directory = try parent(path, create: false)
        defer { close(directory) }
        let name = "." + path.last! + ".lock"
        var metadata = stat()
        guard fstatat(directory, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ENOENT { return }
            throw ProjectExecutionError.unavailable
        }
        guard metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == getuid(), metadata.st_mode & 0o077 == 0,
              metadata.st_nlink == 1 else { throw ProjectExecutionError.conflict }
        guard unlinkat(directory, name, 0) == 0, fsync(directory) == 0 else {
            throw ProjectExecutionError.unavailable
        }
    }

    private func removeEmptyDirectory(_ path: [String], requireEmpty: Bool = false) throws {
        guard !path.isEmpty, try exists(path) else { return }
        // Open the target itself to enforce the same no-follow/owner checks as
        // reads, including on a restart where some ancestors already vanished.
        let target = try parent(path + ["unused"], create: false)
        close(target)
        let parentPath = Array(path.dropLast()) + ["unused"]
        let directory = try parent(parentPath, create: false)
        defer { close(directory) }
        if unlinkat(directory, path.last!, AT_REMOVEDIR) != 0 {
            if errno == ENOENT || (errno == ENOTEMPTY && !requireEmpty) { return }
            throw ProjectExecutionError.unavailable
        }
        guard fsync(directory) == 0 else { throw ProjectExecutionError.unavailable }
    }

    private func requireSelectedCodexContext(_ id: UUID?) throws {
        // Legacy fixtures/records remain writable; production lifecycle admission
        // independently rejects unbound contexts. Existing STOP/close updates remain available.
        guard let id else { return }
        let path = ["CodexContext", "selection.json"]
        guard try exists(path), try read(CodexExecutionContext.self, path: path).id == id else { throw CodexExecutionContextError.changed }
    }

    /// A home switch cannot strand profiles, checkouts or installed hook ownership.
    /// Called under the shared selection lock used by policy/assignment writers.
    private func requireRetiredCodexResources() throws {
        for project in try childNames(["Assignments"]) {
            for task in try childNames(["Assignments", project]) {
                let value = try read(ProjectExecutionAssignment.self, path: ["Assignments", project, task, "assignment.json"])
                try value.validated()
                guard value.id == task, value.registration.projectID.rawValue == project else { throw ProjectExecutionError.identityMismatch }
                guard value.retirement?.completed == true else { throw CodexExecutionContextError.resourcesRetained }
            }
        }
        for project in try childNames(["Projects"]) {
            let path = ["Projects", project, "policy.json"]
            if try !exists(path) {
                guard try childNames(["Projects", project], metadataEntries: true).allSatisfy({ $0 == ".policy.json.lock" }) else {
                    throw ProjectExecutionError.conflict
                }
                continue
            }
            let value = try read(ProjectExecutionPolicy.self, path: path)
            guard value.registration.projectID.rawValue == project else { throw ProjectExecutionError.identityMismatch }
            guard value.hookReceipt?.installed != true else { throw CodexExecutionContextError.resourcesRetained }
        }
    }

    private func childNames(_ path: [String], metadataEntries: Bool = false) throws -> [String] {
        guard try exists(path) else { return [] }
        let directory = try parent(path + ["unused"], create: false); defer { close(directory) }
        let listing = openat(directory, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard listing >= 0, let stream = fdopendir(listing) else {
            if listing >= 0 { close(listing) }; throw ProjectExecutionError.unavailable
        }
        defer { closedir(stream) }
        var names = [String](); errno = 0
        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
            }
            if name == "." || name == ".." { continue }
            if !metadataEntries { try ProjectExecutionPaths.component(name) }
            guard names.count < 1000 else { throw ProjectExecutionError.unavailable }
            names.append(name); errno = 0
        }
        guard errno == 0 else { throw ProjectExecutionError.unavailable }
        return names
    }

    /// Serialize cooperating native writers across process instances. The stable
    /// lock inode is separate from the atomically replaced authority JSON file.
    private func withAuthorityLock<T>(_ path: [String], nonblocking: Bool = false, _ body: () throws -> T) throws -> T {
        guard let file = try acquireAuthorityLock(path, nonblocking: nonblocking) else { throw ProjectExecutionError.conflict }
        defer { releaseAuthorityLocks([file]) }
        return try body()
    }

    private func withAuthorityLocks<T>(_ paths: [[String]], nonblocking: Bool = false, _ body: () throws -> T) throws -> T {
        let files = try acquireAuthorityLocks(paths, nonblocking: nonblocking)
        defer { releaseAuthorityLocks(files) }
        return try body()
    }

    private func acquireAuthorityLocks(_ paths: [[String]], nonblocking: Bool = false) throws -> [Int32] {
        // Project policy locks fence creation of new assignment paths. Acquire
        // them before task locks so a waiting writer cannot leave a new task
        // directory inside a purge that is already cleaning up.
        let ordered = Set(paths).sorted {
            if ($0.first == "Projects") != ($1.first == "Projects") { return $0.first == "Projects" }
            return $0.lexicographicallyPrecedes($1)
        }
        var result = [Int32]()
        do {
            for path in ordered {
                guard let file = try acquireAuthorityLock(path, nonblocking: nonblocking) else { throw ProjectExecutionError.conflict }
                result.append(file)
            }
            return result
        } catch {
            releaseAuthorityLocks(result)
            throw error
        }
    }

    private func releaseAuthorityLocks(_ descriptors: [Int32]) {
        for file in descriptors.reversed() { flock(file, LOCK_UN); close(file) }
    }

    private func acquireAuthorityLock(_ path: [String], nonblocking: Bool = false) throws -> Int32? {
        let directory = try parent(path, create: true); defer { close(directory) }
        let name = "." + path.last! + ".lock"
        let file = openat(directory, name, O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw ProjectExecutionError.conflict }
        var transferred = false
        defer { if !transferred { close(file) } }
        var metadata = stat(), entry = stat()
        guard fstat(file, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == getuid(), metadata.st_mode & 0o077 == 0, metadata.st_nlink == 1 else {
            throw ProjectExecutionError.conflict
        }
        while flock(file, LOCK_EX | (nonblocking ? LOCK_NB : 0)) != 0 {
            if nonblocking, errno == EWOULDBLOCK { return nil }
            if errno == EINTR { continue }; throw ProjectExecutionError.unavailable
        }
        guard fstatat(directory, name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              metadata.st_dev == entry.st_dev, metadata.st_ino == entry.st_ino else { throw ProjectExecutionError.conflict }
        transferred = true
        return file
    }

    private func parent(_ path: [String], create: Bool) throws -> Int32 {
        var current = dup(descriptor)
        guard current >= 0 else { throw ProjectExecutionError.unavailable }
        do {
            for name in path.dropLast() {
                if create, mkdirat(current, name, 0o700) != 0, errno != EEXIST { throw ProjectExecutionError.unavailable }
                let next = openat(current, name, (create ? O_RDONLY : O_SEARCH) | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw ProjectExecutionError.conflict }
                var metadata = stat()
                guard fstat(next, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
                    close(next); throw ProjectExecutionError.conflict
                }
                close(current); current = next
            }
            return current
        } catch { close(current); throw error }
    }

    private func exists(_ path: [String]) throws -> Bool {
        var current = dup(descriptor)
        guard current >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(current) }
        for component in path.dropLast() {
            let next = openat(current, component, O_SEARCH | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if next < 0 {
                if errno == ENOENT { return false }
                throw ProjectExecutionError.conflict
            }
            var metadata = stat()
            guard fstat(next, &metadata) == 0, metadata.st_uid == getuid(), metadata.st_mode & 0o022 == 0 else {
                close(next); throw ProjectExecutionError.conflict
            }
            close(current); current = next
        }
        var metadata = stat()
        if fstatat(current, path.last!, &metadata, AT_SYMLINK_NOFOLLOW) == 0 { return true }
        if errno == ENOENT { return false }
        throw ProjectExecutionError.conflict
    }

    private func read<T: Decodable>(_ type: T.Type, path: [String]) throws -> T {
        let data = try readBytes(path: path)
        do { return try JSONDecoder().decode(type, from: data) } catch { throw ProjectExecutionError.conflict }
    }

    private func readBytes(path: [String]) throws -> Data {
        let directory = try parent(path, create: false); defer { close(directory) }
        let file = openat(directory, path.last!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard file >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(file) }
        var before = stat(), after = stat(), entry = stat()
        guard fstat(file, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(), before.st_mode & 0o022 == 0,
              before.st_size > 0, before.st_size <= 1_048_576 else { throw ProjectExecutionError.conflict }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = Darwin.read(file, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 { if errno == EINTR { continue }; throw ProjectExecutionError.unavailable }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= 1_048_576 else { throw ProjectExecutionError.conflict }
        }
        guard fstat(file, &after) == 0, fstatat(directory, path.last!, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino, before.st_ino == entry.st_ino,
              before.st_dev == entry.st_dev, before.st_size == after.st_size, before.st_size == data.count,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec, before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
        else { throw ProjectExecutionError.conflict }
        return data
    }

    private func write<T: Codable & Equatable>(_ value: T, expected: T?, path: [String]) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        var expectedBytes: Data?
        if let expected {
            let current = try readBytes(path: path)
            guard try JSONDecoder().decode(T.self, from: current) == expected else { throw ProjectExecutionError.conflict }
            expectedBytes = current
        }
        try writeBytes(data, expected: expectedBytes, path: path)
    }

    private func writeBytes(_ data: Data, expected: Data?, path: [String]) throws {
        let directory = try parent(path, create: true); defer { close(directory) }
        let name = path.last!
        var metadata = stat()
        let exists = fstatat(directory, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0
        if exists {
            guard let expected, try readBytes(path: path) == expected else { throw ProjectExecutionError.conflict }
        } else {
            guard errno == ENOENT, expected == nil else { throw ProjectExecutionError.conflict }
        }
        guard data.count <= 1_048_576 else { throw ProjectExecutionError.invalidAssignment }
        let temporary = ".rr-\(UUID().uuidString).tmp"
        let file = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw ProjectExecutionError.unavailable }
        defer { close(file); unlinkat(directory, temporary, 0) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(file, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 { if errno == EINTR { continue }; throw ProjectExecutionError.unavailable }
                guard count > 0 else { throw ProjectExecutionError.unavailable }; offset += count
            }
        }
        guard fsync(file) == 0 else { throw ProjectExecutionError.unavailable }
        if exists {
            // Refuse an observed conflicting edit; this is not a cross-process CAS promise.
            guard try readBytes(path: path) == expected else { throw ProjectExecutionError.conflict }
            guard renameat(directory, temporary, directory, name) == 0 else { throw ProjectExecutionError.unavailable }
        } else {
            guard linkat(directory, temporary, directory, name, 0) == 0 else { throw ProjectExecutionError.conflict }
        }
        guard fsync(directory) == 0, try readBytes(path: path) == data else { throw ProjectExecutionError.unavailable }
    }
}
