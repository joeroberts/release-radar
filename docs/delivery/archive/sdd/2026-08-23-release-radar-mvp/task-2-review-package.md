# Review package: 40afa6a95b78919ca5282493230f07d3eb412f0b..HEAD

## Commits
ecaeda5 docs: record RR-02 implementation evidence
7362903 fix: enforce phase dependency acyclicity
6126178 feat: add transactional delivery store

## Files changed
 ReleaseRadar.xcodeproj/project.pbxproj        |   4 +-
 ReleaseRadarCore/Models/DeliveryModels.swift  |  54 +++++
 ReleaseRadarCore/Store/DeliveryStore.swift    | 134 ++++++++++++
 ReleaseRadarCore/Store/SQLiteConnection.swift | 176 +++++++++++++++
 ReleaseRadarCore/Store/StoreMigrations.swift  | 206 ++++++++++++++++++
 ReleaseRadarTests/StoreAcceptanceTests.swift  | 299 ++++++++++++++++++++++++++
 docs/delivery/progress.md                     |  17 +-
 7 files changed, 886 insertions(+), 4 deletions(-)

## Diff
diff --git a/ReleaseRadar.xcodeproj/project.pbxproj b/ReleaseRadar.xcodeproj/project.pbxproj
index 501ace5..f6ce46a 100644
--- a/ReleaseRadar.xcodeproj/project.pbxproj
+++ b/ReleaseRadar.xcodeproj/project.pbxproj
@@ -237,22 +237,22 @@
 		A80000000000000000000002 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000001 /* ReleaseRadar */; targetProxy = A70000000000000000000002 /* PBXContainerItemProxy */; };
 		A80000000000000000000003 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000002 /* ReleaseRadarCore */; targetProxy = A70000000000000000000003 /* PBXContainerItemProxy */; };
 		A80000000000000000000004 /* PBXTargetDependency */ = {isa = PBXTargetDependency; target = A20000000000000000000001 /* ReleaseRadar */; targetProxy = A70000000000000000000004 /* PBXContainerItemProxy */; };
 /* End PBXTargetDependency section */
 
 /* Begin XCBuildConfiguration section */
 		A50000000000000000000050 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CODE_SIGN_IDENTITY = "Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"; CODE_SIGN_STYLE = Manual; DEBUG_INFORMATION_FORMAT = dwarf; DEVELOPMENT_TEAM = 2UA854NLX4; ENABLE_CODE_COVERAGE = NO; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; MACOSX_DEPLOYMENT_TARGET = 14.0; ONLY_ACTIVE_ARCH = YES; SDKROOT = macosx; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_VERSION = 6.0; }; name = Debug; };
 		A50000000000000000000051 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; CODE_SIGN_IDENTITY = "Apple Development: jaroberts4@gmail.com (PT7GS96H3L)"; CODE_SIGN_STYLE = Manual; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; DEVELOPMENT_TEAM = 2UA854NLX4; MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O"; SWIFT_VERSION = 6.0; }; name = Release; };
 		A50000000000000000000053 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadar/ReleaseRadar.entitlements; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = ReleaseRadar/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", ); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadar; PRODUCT_NAME = ReleaseRadar; SWIFT_EMIT_LOC_STRINGS = YES; }; name = Debug; };
 		A50000000000000000000054 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {CODE_SIGN_ENTITLEMENTS = ReleaseRadar/ReleaseRadar.entitlements; COMBINE_HIDPI_IMAGES = YES; CURRENT_PROJECT_VERSION = 1; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = NO; INFOPLIST_FILE = ReleaseRadar/Info.plist; LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks", ); MARKETING_VERSION = 0.1.0; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadar; PRODUCT_NAME = ReleaseRadar; SWIFT_EMIT_LOC_STRINGS = YES; }; name = Release; };
-		A50000000000000000000056 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Debug; };
-		A50000000000000000000057 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Release; };
+		A50000000000000000000056 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; OTHER_LDFLAGS = "-lsqlite3"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Debug; };
+		A50000000000000000000057 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {DEFINES_MODULE = YES; DYLIB_INSTALL_NAME_BASE = "@rpath"; ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; INSTALL_PATH = "$(LOCAL_LIBRARY_DIR)/Frameworks"; OTHER_LDFLAGS = "-lsqlite3"; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarCore; PRODUCT_NAME = ReleaseRadarCore; SKIP_INSTALL = YES; }; name = Release; };
 		A50000000000000000000059 /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Debug; };
 		A5000000000000000000005A /* Release */ = {isa = XCBuildConfiguration; buildSettings = {ENABLE_HARDENED_RUNTIME = YES; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarAgentTools; PRODUCT_NAME = ReleaseRadarAgentTools; }; name = Release; };
 		A5000000000000000000005C /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarTests; PRODUCT_NAME = ReleaseRadarTests; SKIP_INSTALL = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReleaseRadar.app/Contents/MacOS/ReleaseRadar"; }; name = Debug; };
 		A5000000000000000000005D /* Release */ = {isa = XCBuildConfiguration; buildSettings = {BUNDLE_LOADER = "$(TEST_HOST)"; GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarTests; PRODUCT_NAME = ReleaseRadarTests; SKIP_INSTALL = YES; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/ReleaseRadar.app/Contents/MacOS/ReleaseRadar"; }; name = Release; };
 		A5000000000000000000005F /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarUITests; PRODUCT_NAME = ReleaseRadarUITests; SKIP_INSTALL = YES; TEST_TARGET_NAME = ReleaseRadar; }; name = Debug; };
 		A50000000000000000000060 /* Release */ = {isa = XCBuildConfiguration; buildSettings = {GENERATE_INFOPLIST_FILE = YES; PRODUCT_BUNDLE_IDENTIFIER = com.rekonlabs.ReleaseRadarUITests; PRODUCT_NAME = ReleaseRadarUITests; SKIP_INSTALL = YES; TEST_TARGET_NAME = ReleaseRadar; }; name = Release; };
 /* End XCBuildConfiguration section */
 
 /* Begin XCConfigurationList section */
 		A50000000000000000000052 /* Build configuration list for PBXProject "ReleaseRadar" */ = {isa = XCConfigurationList; buildConfigurations = (A50000000000000000000050 /* Debug */, A50000000000000000000051 /* Release */, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
diff --git a/ReleaseRadarCore/Models/DeliveryModels.swift b/ReleaseRadarCore/Models/DeliveryModels.swift
new file mode 100644
index 0000000..a28d0c6
--- /dev/null
+++ b/ReleaseRadarCore/Models/DeliveryModels.swift
@@ -0,0 +1,54 @@
+import Foundation
+
+public protocol DeliveryRecordID: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {}
+
+public struct ProjectRootID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct PhaseID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct TicketID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct PhaseDependencyID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct TicketDependencyID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct BlockerID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct EvidenceID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct ThreadLinkID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct ThreadExclusionID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct ObservedThreadID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct ObservedGoalID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct ReviewItemID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct AuditEventID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+public struct NotificationEventID: DeliveryRecordID { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
+
+extension ProjectID: DeliveryRecordID {}
+
+public enum TicketLane: String, Codable, CaseIterable, Sendable {
+    case backlog
+    case inProgress = "in_progress"
+    case needsReview = "needs_review"
+    case blocked
+    case accepted
+}
+
+public struct DeliveryActor: Codable, Equatable, Sendable {
+    public let id: String
+    public let threadID: String?
+
+    public init(id: String, threadID: String? = nil) {
+        self.id = id
+        self.threadID = threadID
+    }
+}
+
+public struct ProjectRecord: Codable, Equatable, Sendable { public let id: ProjectID; public let name: String }
+public struct ProjectRootRecord: Codable, Equatable, Sendable { public let id: ProjectRootID; public let projectID: ProjectID; public let path: String }
+public struct PhaseRecord: Codable, Equatable, Sendable { public let id: PhaseID; public let projectID: ProjectID; public let name: String }
+public struct TicketRecord: Codable, Equatable, Sendable { public let id: TicketID; public let projectID: ProjectID; public let phaseID: PhaseID; public let outcome: String; public let lane: TicketLane }
+public struct PhaseDependencyRecord: Codable, Equatable, Sendable { public let id: PhaseDependencyID; public let projectID: ProjectID; public let phaseID: PhaseID; public let dependsOnPhaseID: PhaseID }
+public struct TicketDependencyRecord: Codable, Equatable, Sendable { public let id: TicketDependencyID; public let projectID: ProjectID; public let ticketID: TicketID; public let dependsOnTicketID: TicketID }
+public struct BlockerRecord: Codable, Equatable, Sendable { public let id: BlockerID; public let projectID: ProjectID; public let ticketID: TicketID; public let summary: String }
+public struct EvidenceRecord: Codable, Equatable, Sendable { public let id: EvidenceID; public let projectID: ProjectID; public let ticketID: TicketID?; public let path: String; public let isAvailable: Bool }
+public struct ThreadLinkRecord: Codable, Equatable, Sendable { public let id: ThreadLinkID; public let projectID: ProjectID; public let ticketID: TicketID; public let threadID: ObservedThreadID }
+public struct ThreadExclusionRecord: Codable, Equatable, Sendable { public let id: ThreadExclusionID; public let projectID: ProjectID; public let threadID: String; public let reason: String }
+public struct ObservedThreadRecord: Codable, Equatable, Sendable { public let id: ObservedThreadID; public let projectID: ProjectID; public let status: String; public let lastObservedAt: Date }
+public struct ObservedGoalRecord: Codable, Equatable, Sendable { public let id: ObservedGoalID; public let projectID: ProjectID; public let threadID: ObservedThreadID; public let status: String; public let text: String; public let lastObservedAt: Date }
+public struct ReviewItemRecord: Codable, Equatable, Sendable { public let id: ReviewItemID; public let projectID: ProjectID; public let ticketID: TicketID?; public let kind: String; public let summary: String }
+public struct AuditEventRecord: Codable, Equatable, Sendable { public let id: AuditEventID; public let actorID: String; public let threadID: String?; public let reason: String; public let createdAt: Date }
+public struct NotificationEventRecord: Codable, Equatable, Sendable { public let id: NotificationEventID; public let fingerprint: String; public let state: String; public let ticketID: TicketID?; public let goalID: ObservedGoalID? }
diff --git a/ReleaseRadarCore/Store/DeliveryStore.swift b/ReleaseRadarCore/Store/DeliveryStore.swift
new file mode 100644
index 0000000..a158837
--- /dev/null
+++ b/ReleaseRadarCore/Store/DeliveryStore.swift
@@ -0,0 +1,134 @@
+import Foundation
+
+public enum StoreError: Error, LocalizedError, Equatable, Sendable {
+    case unavailable(String)
+    case unsupportedSchemaVersion(found: Int64, supported: Int64)
+
+    public var errorDescription: String? {
+        switch self {
+        case let .unavailable(message): message
+        case let .unsupportedSchemaVersion(found, supported):
+            "Database schema version \(found) is newer than supported version \(supported)"
+        }
+    }
+}
+
+public enum StoreRecoveryFailureKind: Equatable, Sendable {
+    case corruption
+    case migration
+}
+
+public struct StoreRecoveryState: Equatable, Sendable {
+    public let kind: StoreRecoveryFailureKind
+    public let originalDatabaseURL: URL
+    public let preMigrationSnapshotURL: URL?
+    public let message: String
+}
+
+public enum DeliveryStoreAvailability: Equatable, Sendable {
+    case available
+    case unavailable(StoreRecoveryState)
+}
+
+public actor DeliveryStore {
+    private let connection: SQLiteConnection?
+    public let availability: DeliveryStoreAvailability
+
+    public init(databaseURL: URL = DeliveryStore.applicationSupportDatabaseURL()) {
+        let databaseExisted = FileManager.default.fileExists(atPath: databaseURL.path)
+        let snapshotURL = Self.preMigrationSnapshotURL(for: databaseURL)
+        let openedConnection: SQLiteConnection
+        do {
+            openedConnection = try SQLiteConnection(url: databaseURL)
+            guard try openedConnection.scalarText("PRAGMA integrity_check") == "ok" else {
+                throw StoreError.unavailable("Database integrity check failed")
+            }
+        } catch {
+            connection = nil
+            availability = .unavailable(.init(
+                kind: .corruption,
+                originalDatabaseURL: databaseURL,
+                preMigrationSnapshotURL: nil,
+                message: error.localizedDescription
+            ))
+            return
+        }
+
+        do {
+            let schemaVersion = try openedConnection.scalarInt("PRAGMA user_version") ?? 0
+            if databaseExisted, schemaVersion != StoreMigrations.currentVersion {
+                try openedConnection.createSnapshot(at: snapshotURL)
+            }
+            try StoreMigrations.migrate(openedConnection)
+            connection = openedConnection
+            availability = .available
+        } catch {
+            connection = nil
+            availability = .unavailable(.init(
+                kind: .migration,
+                originalDatabaseURL: databaseURL,
+                preMigrationSnapshotURL: FileManager.default.fileExists(atPath: snapshotURL.path) ? snapshotURL : nil,
+                message: error.localizedDescription
+            ))
+        }
+    }
+
+    public func transact<T: Sendable>(
+        actor: DeliveryActor,
+        reason: String,
+        _ body: @Sendable (SQLiteConnection) throws -> T
+    ) throws -> T {
+        let connection = try availableConnection()
+        try connection.execute("BEGIN IMMEDIATE TRANSACTION")
+        do {
+            let result = try body(connection)
+            try connection.execute(
+                "INSERT INTO audit_events (id, actor_id, thread_id, reason, created_at) VALUES (?, ?, ?, ?, ?)",
+                bindings: [
+                    .text(UUID().uuidString),
+                    .text(actor.id),
+                    actor.threadID.map(SQLiteValue.text) ?? .null,
+                    .text(reason),
+                    .text(ISO8601DateFormatter().string(from: Date())),
+                ]
+            )
+            try connection.execute("COMMIT")
+            return result
+        } catch {
+            try? connection.execute("ROLLBACK")
+            throw error
+        }
+    }
+
+    public func read<T: Sendable>(
+        _ body: @Sendable (SQLiteConnection) throws -> T
+    ) throws -> T {
+        let connection = try availableConnection()
+        return try connection.withReadOnlyAccess {
+            try body(connection)
+        }
+    }
+
+    public static func applicationSupportDatabaseURL(
+        fileManager: FileManager = .default
+    ) -> URL {
+        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
+        let directory = baseURL.appendingPathComponent("com.rekonlabs.ReleaseRadar", isDirectory: true)
+        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
+        return directory.appendingPathComponent("release-radar.sqlite")
+    }
+
+    public static func preMigrationSnapshotURL(for databaseURL: URL) -> URL {
+        databaseURL.appendingPathExtension("pre-migration")
+    }
+
+    private func availableConnection() throws -> SQLiteConnection {
+        guard let connection else {
+            if case let .unavailable(recovery) = availability {
+                throw StoreError.unavailable(recovery.message)
+            }
+            throw StoreError.unavailable("Database could not be opened")
+        }
+        return connection
+    }
+}
diff --git a/ReleaseRadarCore/Store/SQLiteConnection.swift b/ReleaseRadarCore/Store/SQLiteConnection.swift
new file mode 100644
index 0000000..53ca54c
--- /dev/null
+++ b/ReleaseRadarCore/Store/SQLiteConnection.swift
@@ -0,0 +1,176 @@
+import Foundation
+import SQLite3
+import Darwin
+
+public enum SQLiteValue: Equatable, Sendable {
+    case integer(Int64)
+    case real(Double)
+    case text(String)
+    case blob(Data)
+    case null
+}
+
+public struct SQLiteError: Error, LocalizedError, Equatable, Sendable {
+    public let code: Int32
+    public let message: String
+
+    public var errorDescription: String? { "SQLite error \(code): \(message)" }
+}
+
+public final class SQLiteConnection: @unchecked Sendable {
+    private var database: OpaquePointer?
+    private var isReadOnly = false
+
+    init(url: URL) throws {
+        let result = sqlite3_open_v2(
+            url.path,
+            &database,
+            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
+            nil
+        )
+        guard result == SQLITE_OK else {
+            let error = currentError(code: result)
+            sqlite3_close(database)
+            database = nil
+            throw error
+        }
+        do {
+            sqlite3_busy_timeout(database, 5_000)
+            try execute("PRAGMA foreign_keys = ON")
+        } catch {
+            sqlite3_close(database)
+            database = nil
+            throw error
+        }
+    }
+
+    deinit {
+        sqlite3_close(database)
+    }
+
+    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
+        guard !isReadOnly else {
+            throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
+        }
+        let statement = try prepare(sql)
+        defer { sqlite3_finalize(statement) }
+        try bind(bindings, to: statement)
+        let result = sqlite3_step(statement)
+        guard result == SQLITE_DONE else { throw currentError(code: result) }
+    }
+
+    public func row(
+        _ sql: String,
+        bindings: [SQLiteValue] = []
+    ) throws -> [String: SQLiteValue]? {
+        let statement = try prepare(sql)
+        defer { sqlite3_finalize(statement) }
+        guard !isReadOnly || sqlite3_stmt_readonly(statement) != 0 else {
+            throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
+        }
+        try bind(bindings, to: statement)
+        let result = sqlite3_step(statement)
+        if result == SQLITE_DONE { return nil }
+        guard result == SQLITE_ROW else { throw currentError(code: result) }
+
+        var resultRow: [String: SQLiteValue] = [:]
+        for index in 0..<sqlite3_column_count(statement) {
+            let name = String(cString: sqlite3_column_name(statement, index))
+            resultRow[name] = value(in: statement, at: index)
+        }
+        return resultRow
+    }
+
+    public func scalarText(
+        _ sql: String,
+        bindings: [SQLiteValue] = []
+    ) throws -> String? {
+        guard let value = try row(sql, bindings: bindings)?.values.first else { return nil }
+        if case let .text(text) = value { return text }
+        if case .null = value { return nil }
+        throw SQLiteError(code: SQLITE_MISMATCH, message: "Expected text result")
+    }
+
+    public func scalarInt(
+        _ sql: String,
+        bindings: [SQLiteValue] = []
+    ) throws -> Int64? {
+        guard let value = try row(sql, bindings: bindings)?.values.first else { return nil }
+        if case let .integer(integer) = value { return integer }
+        if case .null = value { return nil }
+        throw SQLiteError(code: SQLITE_MISMATCH, message: "Expected integer result")
+    }
+
+    func executeScript(_ sql: String) throws {
+        var errorMessage: UnsafeMutablePointer<CChar>?
+        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
+        guard result == SQLITE_OK else {
+            let message = errorMessage.map { String(cString: $0) } ?? currentError(code: result).message
+            sqlite3_free(errorMessage)
+            throw SQLiteError(code: result, message: message)
+        }
+    }
+
+    func createSnapshot(at destinationURL: URL) throws {
+        let temporaryURL = destinationURL
+            .deletingLastPathComponent()
+            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
+        defer { try? FileManager.default.removeItem(at: temporaryURL) }
+        try execute("VACUUM INTO ?", bindings: [.text(temporaryURL.path)])
+        guard rename(temporaryURL.path, destinationURL.path) == 0 else {
+            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destinationURL.path])
+        }
+    }
+
+    func withReadOnlyAccess<T>(_ body: () throws -> T) rethrows -> T {
+        isReadOnly = true
+        defer { isReadOnly = false }
+        return try body()
+    }
+
+    private func prepare(_ sql: String) throws -> OpaquePointer {
+        var statement: OpaquePointer?
+        let result = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
+        guard result == SQLITE_OK, let statement else { throw currentError(code: result) }
+        return statement
+    }
+
+    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
+        guard sqlite3_bind_parameter_count(statement) == bindings.count else {
+            throw SQLiteError(code: SQLITE_RANGE, message: "Expected \(sqlite3_bind_parameter_count(statement)) bindings, received \(bindings.count)")
+        }
+        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
+        for (offset, value) in bindings.enumerated() {
+            let index = Int32(offset + 1)
+            let result: Int32
+            switch value {
+            case let .integer(integer): result = sqlite3_bind_int64(statement, index, integer)
+            case let .real(real): result = sqlite3_bind_double(statement, index, real)
+            case let .text(text): result = sqlite3_bind_text(statement, index, text, -1, transient)
+            case let .blob(data):
+                result = data.withUnsafeBytes { bytes in
+                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
+                }
+            case .null: result = sqlite3_bind_null(statement, index)
+            }
+            guard result == SQLITE_OK else { throw currentError(code: result) }
+        }
+    }
+
+    private func value(in statement: OpaquePointer, at index: Int32) -> SQLiteValue {
+        switch sqlite3_column_type(statement, index) {
+        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(statement, index))
+        case SQLITE_FLOAT: return .real(sqlite3_column_double(statement, index))
+        case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(statement, index)))
+        case SQLITE_BLOB:
+            let count = Int(sqlite3_column_bytes(statement, index))
+            guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
+            return .blob(Data(bytes: bytes, count: count))
+        default: return .null
+        }
+    }
+
+    private func currentError(code: Int32) -> SQLiteError {
+        SQLiteError(code: code, message: database.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed")
+    }
+}
diff --git a/ReleaseRadarCore/Store/StoreMigrations.swift b/ReleaseRadarCore/Store/StoreMigrations.swift
new file mode 100644
index 0000000..01fdadb
--- /dev/null
+++ b/ReleaseRadarCore/Store/StoreMigrations.swift
@@ -0,0 +1,206 @@
+import Foundation
+
+enum StoreMigrations {
+    static let currentVersion: Int64 = 1
+
+    static func migrate(_ connection: SQLiteConnection) throws {
+        let version = try connection.scalarInt("PRAGMA user_version") ?? 0
+        guard version <= currentVersion else {
+            throw StoreError.unsupportedSchemaVersion(found: version, supported: currentVersion)
+        }
+        guard version < currentVersion else { return }
+
+        try connection.execute("BEGIN EXCLUSIVE TRANSACTION")
+        do {
+            try connection.executeScript(schemaVersion1)
+            try connection.execute("PRAGMA user_version = 1")
+            try connection.execute("COMMIT")
+        } catch {
+            try? connection.execute("ROLLBACK")
+            throw error
+        }
+    }
+
+    private static let schemaVersion1 = """
+    CREATE TABLE projects (
+        id TEXT PRIMARY KEY NOT NULL,
+        name TEXT NOT NULL
+    );
+    CREATE TABLE project_roots (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        path TEXT NOT NULL UNIQUE
+    );
+    CREATE TABLE phases (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        name TEXT NOT NULL,
+        UNIQUE(project_id, id)
+    );
+    CREATE TABLE tickets (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        phase_id TEXT NOT NULL,
+        outcome TEXT NOT NULL,
+        lane TEXT NOT NULL CHECK (lane IN ('backlog', 'in_progress', 'needs_review', 'blocked', 'accepted')),
+        UNIQUE(project_id, id),
+        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id)
+    );
+    CREATE TABLE phase_dependencies (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        phase_id TEXT NOT NULL,
+        depends_on_phase_id TEXT NOT NULL,
+        UNIQUE(phase_id, depends_on_phase_id),
+        CHECK (phase_id <> depends_on_phase_id),
+        FOREIGN KEY(project_id, phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE,
+        FOREIGN KEY(project_id, depends_on_phase_id) REFERENCES phases(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TRIGGER reject_phase_dependency_cycle_insert
+    BEFORE INSERT ON phase_dependencies
+    WHEN EXISTS (
+        WITH RECURSIVE dependency_path(phase_id) AS (
+            SELECT NEW.depends_on_phase_id
+            UNION
+            SELECT dependency.depends_on_phase_id
+            FROM phase_dependencies AS dependency
+            JOIN dependency_path ON dependency.phase_id = dependency_path.phase_id
+            WHERE dependency.project_id = NEW.project_id
+        )
+        SELECT 1 FROM dependency_path WHERE phase_id = NEW.phase_id
+    )
+    BEGIN
+        SELECT RAISE(ABORT, 'phase dependency cycle');
+    END;
+    CREATE TRIGGER reject_phase_dependency_cycle_update
+    BEFORE UPDATE OF project_id, phase_id, depends_on_phase_id ON phase_dependencies
+    WHEN EXISTS (
+        WITH RECURSIVE dependency_path(phase_id) AS (
+            SELECT NEW.depends_on_phase_id
+            UNION
+            SELECT dependency.depends_on_phase_id
+            FROM phase_dependencies AS dependency
+            JOIN dependency_path ON dependency.phase_id = dependency_path.phase_id
+            WHERE dependency.project_id = NEW.project_id AND dependency.id <> OLD.id
+        )
+        SELECT 1 FROM dependency_path WHERE phase_id = NEW.phase_id
+    )
+    BEGIN
+        SELECT RAISE(ABORT, 'phase dependency cycle');
+    END;
+    CREATE TABLE ticket_dependencies (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        ticket_id TEXT NOT NULL,
+        depends_on_ticket_id TEXT NOT NULL,
+        UNIQUE(ticket_id, depends_on_ticket_id),
+        CHECK (ticket_id <> depends_on_ticket_id),
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE,
+        FOREIGN KEY(project_id, depends_on_ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TRIGGER reject_ticket_dependency_cycle_insert
+    BEFORE INSERT ON ticket_dependencies
+    WHEN EXISTS (
+        WITH RECURSIVE dependency_path(ticket_id) AS (
+            SELECT NEW.depends_on_ticket_id
+            UNION
+            SELECT dependency.depends_on_ticket_id
+            FROM ticket_dependencies AS dependency
+            JOIN dependency_path ON dependency.ticket_id = dependency_path.ticket_id
+            WHERE dependency.project_id = NEW.project_id
+        )
+        SELECT 1 FROM dependency_path WHERE ticket_id = NEW.ticket_id
+    )
+    BEGIN
+        SELECT RAISE(ABORT, 'ticket dependency cycle');
+    END;
+    CREATE TRIGGER reject_ticket_dependency_cycle_update
+    BEFORE UPDATE OF project_id, ticket_id, depends_on_ticket_id ON ticket_dependencies
+    WHEN EXISTS (
+        WITH RECURSIVE dependency_path(ticket_id) AS (
+            SELECT NEW.depends_on_ticket_id
+            UNION
+            SELECT dependency.depends_on_ticket_id
+            FROM ticket_dependencies AS dependency
+            JOIN dependency_path ON dependency.ticket_id = dependency_path.ticket_id
+            WHERE dependency.project_id = NEW.project_id AND dependency.id <> OLD.id
+        )
+        SELECT 1 FROM dependency_path WHERE ticket_id = NEW.ticket_id
+    )
+    BEGIN
+        SELECT RAISE(ABORT, 'ticket dependency cycle');
+    END;
+    CREATE TABLE blockers (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        ticket_id TEXT NOT NULL,
+        summary TEXT NOT NULL,
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE evidence (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        ticket_id TEXT,
+        path TEXT NOT NULL,
+        is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
+        UNIQUE(project_id, path),
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE thread_exclusions (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        thread_id TEXT NOT NULL,
+        reason TEXT NOT NULL,
+        UNIQUE(project_id, thread_id)
+    );
+    CREATE TABLE observed_threads (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        status TEXT NOT NULL,
+        last_observed_at TEXT NOT NULL,
+        UNIQUE(project_id, id)
+    );
+    CREATE TABLE observed_goals (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        thread_id TEXT NOT NULL,
+        status TEXT NOT NULL,
+        text TEXT NOT NULL,
+        last_observed_at TEXT NOT NULL,
+        FOREIGN KEY(project_id, thread_id) REFERENCES observed_threads(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE thread_links (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL,
+        ticket_id TEXT NOT NULL,
+        thread_id TEXT NOT NULL,
+        UNIQUE(project_id, ticket_id, thread_id),
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE,
+        FOREIGN KEY(project_id, thread_id) REFERENCES observed_threads(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE review_items (
+        id TEXT PRIMARY KEY NOT NULL,
+        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
+        ticket_id TEXT,
+        kind TEXT NOT NULL,
+        summary TEXT NOT NULL,
+        FOREIGN KEY(project_id, ticket_id) REFERENCES tickets(project_id, id) ON DELETE CASCADE
+    );
+    CREATE TABLE audit_events (
+        id TEXT PRIMARY KEY NOT NULL,
+        actor_id TEXT NOT NULL,
+        thread_id TEXT,
+        reason TEXT NOT NULL,
+        created_at TEXT NOT NULL
+    );
+    CREATE TABLE notification_events (
+        id TEXT PRIMARY KEY NOT NULL,
+        fingerprint TEXT NOT NULL UNIQUE,
+        state TEXT NOT NULL,
+        ticket_id TEXT REFERENCES tickets(id) ON DELETE SET NULL,
+        goal_id TEXT REFERENCES observed_goals(id) ON DELETE SET NULL,
+        provider_receipt TEXT,
+        acknowledged_at TEXT
+    );
+    """
+}
diff --git a/ReleaseRadarTests/StoreAcceptanceTests.swift b/ReleaseRadarTests/StoreAcceptanceTests.swift
new file mode 100644
index 0000000..9b570be
--- /dev/null
+++ b/ReleaseRadarTests/StoreAcceptanceTests.swift
@@ -0,0 +1,299 @@
+import Foundation
+import XCTest
+@testable import ReleaseRadarCore
+
+final class StoreAcceptanceTests: XCTestCase {
+    func testSuccessfulTicketTransitionCommitsAttributedAuditEvent() async throws {
+        let databaseURL = try makeDatabaseURL()
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let projectID = ProjectID(rawValue: "project-1")
+        let phaseID = PhaseID(rawValue: "phase-1")
+        let ticketID = TicketID(rawValue: "RR-02")
+        let actor = DeliveryActor(id: "agent-implementer", threadID: "thread-42")
+
+        try await store.transact(actor: actor, reason: "Complete transactional storage") { connection in
+            try connection.execute(
+                "INSERT INTO projects (id, name) VALUES (?, ?)",
+                bindings: [.text(projectID.rawValue), .text("Release Radar")]
+            )
+            try connection.execute(
+                "INSERT INTO phases (id, project_id, name) VALUES (?, ?, ?)",
+                bindings: [.text(phaseID.rawValue), .text(projectID.rawValue), .text("MVP")]
+            )
+            try connection.execute(
+                "INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES (?, ?, ?, ?, ?)",
+                bindings: [
+                    .text(ticketID.rawValue),
+                    .text(projectID.rawValue),
+                    .text(phaseID.rawValue),
+                    .text("Persist delivery state"),
+                    .text(TicketLane.backlog.rawValue),
+                ]
+            )
+            try connection.execute(
+                "UPDATE tickets SET lane = ? WHERE id = ?",
+                bindings: [.text(TicketLane.accepted.rawValue), .text(ticketID.rawValue)]
+            )
+        }
+
+        let lane = try await store.read { connection in
+            try connection.scalarText(
+                "SELECT lane FROM tickets WHERE id = ?",
+                bindings: [.text(ticketID.rawValue)]
+            )
+        }
+        let audit = try await store.read { connection in
+            try connection.row(
+                "SELECT actor_id, thread_id, reason FROM audit_events"
+            )
+        }
+
+        XCTAssertEqual(lane, TicketLane.accepted.rawValue)
+        XCTAssertEqual(audit?["actor_id"], .text(actor.id))
+        XCTAssertEqual(audit?["thread_id"], .text(actor.threadID!))
+        XCTAssertEqual(audit?["reason"], .text("Complete transactional storage"))
+    }
+
+    func testInvalidReferenceRollsBackDeliveryAndAuditWrites() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-invalid-reference"), reason: "Add blocker") { connection in
+                try connection.execute(
+                    "UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'"
+                )
+                try connection.execute(
+                    "INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('blocker-1', 'project-1', 'missing-ticket', 'Missing ticket')"
+                )
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM blockers"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 0)
+        XCTAssertEqual(state.2, 1)
+    }
+
+    func testCrossProjectThreadLinkRollsBackDeliveryAndAuditWrites() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed second project") { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-2', 'Other')")
+            try connection.execute("INSERT INTO observed_threads (id, project_id, status, last_observed_at) VALUES ('thread-2', 'project-2', 'running', '2026-08-23T12:00:00Z')")
+        }
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-cross-project"), reason: "Link thread") { connection in
+                try connection.execute("UPDATE tickets SET lane = 'in_progress' WHERE id = 'RR-02'")
+                try connection.execute("INSERT INTO thread_links (id, project_id, ticket_id, thread_id) VALUES ('link-1', 'project-1', 'RR-02', 'thread-2')")
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM thread_links"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 0)
+        XCTAssertEqual(state.2, 2)
+    }
+
+    func testDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed dependency") { connection in
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-03', 'project-1', 'phase-1', 'Bridge', 'backlog')")
+            try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-1', 'project-1', 'RR-03', 'RR-02')")
+        }
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic dependency") { connection in
+                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
+                try connection.execute("INSERT INTO ticket_dependencies (id, project_id, ticket_id, depends_on_ticket_id) VALUES ('dependency-2', 'project-1', 'RR-02', 'RR-03')")
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM ticket_dependencies"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+        XCTAssertEqual(state.2, 2)
+    }
+
+    func testPhaseDependencyCycleRollsBackDeliveryAndAuditWrites() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed phase dependency") { connection in
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-2', 'project-1', 'Launch')")
+            try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-1', 'project-1', 'phase-2', 'phase-1')")
+        }
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent-cycle"), reason: "Add cyclic phase dependency") { connection in
+                try connection.execute("UPDATE tickets SET lane = 'blocked' WHERE id = 'RR-02'")
+                try connection.execute("INSERT INTO phase_dependencies (id, project_id, phase_id, depends_on_phase_id) VALUES ('phase-dependency-2', 'project-1', 'phase-1', 'phase-2')")
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM phase_dependencies"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+        XCTAssertEqual(state.2, 2)
+    }
+
+    func testReadProjectionCannotBypassAuditedTransactions() async throws {
+        let store = DeliveryStore(databaseURL: try makeDatabaseURL())
+        try await seedProject(store)
+
+        await XCTAssertThrowsErrorAsync {
+            try await store.read { connection in
+                try connection.execute("UPDATE tickets SET lane = 'accepted' WHERE id = 'RR-02'")
+            }
+        }
+
+        let state = try await store.read { connection in
+            (
+                try connection.scalarText("SELECT lane FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events")
+            )
+        }
+        XCTAssertEqual(state.0, TicketLane.backlog.rawValue)
+        XCTAssertEqual(state.1, 1)
+    }
+
+    func testMigrationSnapshotAndRelaunchPreserveCommittedDeliveryAndAudit() async throws {
+        let databaseURL = try makeDatabaseURL()
+        do {
+            let legacy = try SQLiteConnection(url: databaseURL)
+            try legacy.execute("CREATE TABLE legacy_marker (value TEXT NOT NULL)")
+            try legacy.execute("INSERT INTO legacy_marker (value) VALUES ('before-migration')")
+            try legacy.execute("PRAGMA user_version = 0")
+        }
+
+        var store: DeliveryStore? = DeliveryStore(databaseURL: databaseURL)
+        try await seedProject(store!)
+        await XCTAssertThrowsErrorAsync {
+            try await store!.transact(actor: .init(id: "agent-invalid"), reason: "Reject missing reference") { connection in
+                try connection.execute("INSERT INTO blockers (id, project_id, ticket_id, summary) VALUES ('rejected', 'project-1', 'missing', 'Rejected')")
+            }
+        }
+        store = nil
+
+        let relaunchedStore = DeliveryStore(databaseURL: databaseURL)
+        let persisted = try await relaunchedStore.read { connection in
+            (
+                try connection.scalarText("SELECT outcome FROM tickets WHERE id = 'RR-02'"),
+                try connection.scalarInt("SELECT COUNT(*) FROM audit_events"),
+                try connection.scalarInt("PRAGMA user_version"),
+                try connection.scalarInt("SELECT COUNT(*) FROM blockers")
+            )
+        }
+        let snapshot = try SQLiteConnection(url: DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
+
+        XCTAssertEqual(persisted.0, "Store")
+        XCTAssertEqual(persisted.1, 1)
+        XCTAssertEqual(persisted.2, 1)
+        XCTAssertEqual(persisted.3, 0)
+        XCTAssertEqual(try snapshot.scalarText("SELECT value FROM legacy_marker"), "before-migration")
+        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
+    }
+
+    func testCorruptDatabaseOpensUnavailableAndLeavesOriginalBytesIntact() async throws {
+        let databaseURL = try makeDatabaseURL()
+        let originalBytes = Data("not-a-sqlite-database".utf8)
+        try originalBytes.write(to: databaseURL)
+
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let availability = await store.availability
+
+        guard case let .unavailable(recovery) = availability else {
+            return XCTFail("Expected corrupt database to be unavailable")
+        }
+        XCTAssertEqual(recovery.kind, .corruption)
+        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
+        XCTAssertNil(recovery.preMigrationSnapshotURL)
+        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
+        await XCTAssertThrowsErrorAsync {
+            try await store.transact(actor: .init(id: "agent"), reason: "Must not reset") { _ in }
+        }
+        XCTAssertEqual(try Data(contentsOf: databaseURL), originalBytes)
+    }
+
+    func testMigrationFailureOpensUnavailableWithOriginalAndSnapshotRecoverable() async throws {
+        let databaseURL = try makeDatabaseURL()
+        do {
+            let malformedLegacy = try SQLiteConnection(url: databaseURL)
+            try malformedLegacy.execute("CREATE TABLE projects (legacy_value TEXT NOT NULL)")
+            try malformedLegacy.execute("INSERT INTO projects (legacy_value) VALUES ('authoritative-original')")
+            try malformedLegacy.execute("PRAGMA user_version = 0")
+        }
+
+        let store = DeliveryStore(databaseURL: databaseURL)
+        let availability = await store.availability
+
+        guard case let .unavailable(recovery) = availability else {
+            return XCTFail("Expected failed migration to leave the store unavailable")
+        }
+        XCTAssertEqual(recovery.kind, .migration)
+        XCTAssertEqual(recovery.originalDatabaseURL, databaseURL)
+        XCTAssertEqual(recovery.preMigrationSnapshotURL, DeliveryStore.preMigrationSnapshotURL(for: databaseURL))
+
+        let original = try SQLiteConnection(url: databaseURL)
+        let snapshot = try SQLiteConnection(url: try XCTUnwrap(recovery.preMigrationSnapshotURL))
+        XCTAssertEqual(try original.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
+        XCTAssertEqual(try snapshot.scalarText("SELECT legacy_value FROM projects"), "authoritative-original")
+        XCTAssertEqual(try original.scalarInt("PRAGMA user_version"), 0)
+        XCTAssertEqual(try snapshot.scalarInt("PRAGMA user_version"), 0)
+        XCTAssertNil(try original.scalarText("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'tickets'"))
+    }
+
+    private func seedProject(_ store: DeliveryStore) async throws {
+        try await store.transact(actor: .init(id: "agent-seed"), reason: "Seed project") { connection in
+            try connection.execute("INSERT INTO projects (id, name) VALUES ('project-1', 'Release Radar')")
+            try connection.execute("INSERT INTO phases (id, project_id, name) VALUES ('phase-1', 'project-1', 'MVP')")
+            try connection.execute("INSERT INTO tickets (id, project_id, phase_id, outcome, lane) VALUES ('RR-02', 'project-1', 'phase-1', 'Store', 'backlog')")
+        }
+    }
+
+    private func makeDatabaseURL() throws -> URL {
+        let directory = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadarStoreTests-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
+        addTeardownBlock {
+            try? FileManager.default.removeItem(at: directory)
+        }
+        return directory.appendingPathComponent("release-radar.sqlite")
+    }
+
+    private func XCTAssertThrowsErrorAsync(
+        _ expression: () async throws -> Void,
+        file: StaticString = #filePath,
+        line: UInt = #line
+    ) async {
+        do {
+            try await expression()
+            XCTFail("Expected expression to throw", file: file, line: line)
+        } catch {}
+    }
+}
diff --git a/docs/delivery/progress.md b/docs/delivery/progress.md
index 1f7a3bc..223b6fe 100644
--- a/docs/delivery/progress.md
+++ b/docs/delivery/progress.md
@@ -19,22 +19,22 @@ Deliver the signed native macOS MVP described by
 
 ## Repository
 
 - Local: `/Users/jroberts/Documents/dev/joeroberts/RekonLabs/release_radar`
 - Remote: `https://github.com/joeroberts/release-radar`
 - Branch: `codex/release-radar-mvp`
 - Pull requests: prohibited by owner direction for this goal.
 
 ## Current gate
 
-- Current task: RR-02 released by TPM and Delivery Manager.
-- Next eligible task: RR-02 transactional local delivery store.
+- Current task: RR-02 implemented; independent code, QA, architecture, and security/privacy reviews pending.
+- Next eligible task: None until RR-02 review gates accept the slice and TPM/Delivery Manager record release.
 - Open product blockers: none.
 - Open operational risks: none.
 
 ## Task ledger
 
 Each task entry records status, verification, reviews with Required/Optional/Out-of-scope classification, decisions, risks, stop-rule events, commit SHA, and the next eligible task before release.
 
 ### RR-01 — Standalone signed application foundation
 
 - Status: Accepted.
@@ -45,20 +45,33 @@ Each task entry records status, verification, reviews with Required/Optional/Out
 - Architecture: Approved; standalone namespace, target boundaries, synchronized roots, sandbox/hardened signing, scenes, and ADR are structurally suitable for successors.
 - Stop-rule event: first implementer attempt produced no files within the foundation timebox and was interrupted; a fresh bounded implementer completed the slice without expanding scope.
 - Decisions/risks: UI acceptance execution remains assigned to the later seeded UI slice; no product risk in RR-01.
 - Next eligible task: RR-02 transactional local delivery store.
 
 ### RR-02 release gate
 
 - TPM: GO; RR-01 technically accepted and RR-02 dependency-safe.
 - Delivery Manager: GO; no remaining Required blocker.
 
+### RR-02 — Transactional local delivery store
+
+- Status: Implemented; independent reviews pending. Not accepted or released.
+- Scope: Stable typed delivery records; app-owned SQLite connection and actor; versioned transactional migration; distinct delivery/runtime/audit/notification tables; attributed audit writes; read-only projections; foreign-key, uniqueness, project-boundary, and recursive phase/ticket acyclicity enforcement; explicit corruption/migration recovery state with an intact original and pre-migration snapshot.
+- Commits: `6126178` (`feat: add transactional delivery store`), `7362903` (`fix: enforce phase dependency acyclicity`).
+- TDD: Observed RED→GREEN cycles for successful audited commit, rollback on invalid/cross-project/cyclic writes, migration/relaunch persistence, corruption/migration recovery, and prevention of unaudited writes through read projections. Full command/results are recorded in `.superpowers/sdd/2026-08-23-release-radar-mvp/task-2-report.md`.
+- Verification: `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests` passed 9 of 9 with 0 failures/skips; `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` passed.
+- Reviews: Code Reviewer pending; QA pending; Architect pending; Security/privacy pending. No findings classified yet.
+- Decisions: The app remains the sole SQLite writer; all writes enter `DeliveryStore.transact` and receive an audit event; read projections are write-protected; migrations are exclusive/atomic; a consistent snapshot is preserved before changing an existing non-current database; failure produces typed unavailable/recovery state without resetting authoritative data.
+- Risks: Review gates remain open. Later bridge/tool slices must preserve the app-only writer boundary and must not expose `SQLiteConnection` or database paths to agents.
+- Stop-rule events: None.
+- Next eligible task: None until independent RR-02 reviews are recorded and TPM/Delivery Manager release the next dependency-safe task.
+
 ### RR-01 — Standalone signed application foundation
 
 - Status: Implemented; QA HOLD round 1 addressed and independent re-review pending.
 - Scope: Standalone Xcode project with app, core framework, agent-tool executable, unit-test, and UI-test targets; signed SwiftUI shell; canonical local run action; ADR-001.
 - Preimplementation gates: Planning complete; Architect approved with corrections; TPM conditional GO satisfied; QA approved with acceptance evidence; Delivery Manager GO; Security/privacy conditional pass incorporated. See the table above for the findings carried into the implementation.
 - Decisions: `com.rekonlabs.ReleaseRadar`, macOS 14.0, filesystem-synchronized source roots, five persisted lanes, app-only database authority, separate observer and typed bridge, App Sandbox and Hardened Runtime.
 - Signing identity: `Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`; certificate team `2UA854NLX4`.
 - Verification: `xcodebuild -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug build` passed; `./script/build_and_run.sh --verify` passed and found PID 10510; `xcodebuild build-for-testing -quiet -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug` passed; `codesign --verify --deep --strict` passed; app entitlements contain App Sandbox and the signature contains Hardened Runtime. After QA fix round 1, the exact focused test command completed with `** TEST SUCCEEDED **`.
 - Tests: `ReleaseRadarTests/AppRouteTests.swift` covers primary/per-project route labels and SF Symbols. `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -configuration Debug -only-testing:ReleaseRadarTests/AppRouteTests` passed 2 of 2 tests with 0 failures and 0 skips. Result bundle: `Test-ReleaseRadar-2026.08.23_22-35-39--0400.xcresult`.
 - Reviews: QA HOLD round 1 found that the focused unit-test invocation did not complete. The main scheme now excludes the still-buildable UI-test target from its TestAction, and Debug code coverage is disabled because process sampling identified post-test runtime-profile collection through a paired-device service as the remaining hang. Fix commit: `ca09ba8`. Independent Code Reviewer, QA, and Architect rechecks remain required before RR-01 acceptance.
