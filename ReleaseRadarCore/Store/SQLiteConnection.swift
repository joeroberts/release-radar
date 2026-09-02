import Foundation
import SQLite3
import Darwin
import OSLog

public enum SQLiteValue: Equatable, Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

public struct SQLiteError: Error, LocalizedError, Equatable, Sendable {
    public let code: Int32
    public let message: String

    public var errorDescription: String? { "SQLite error \(code): \(message)" }
}

public final class SQLiteConnection: @unchecked Sendable {
    private var database: OpaquePointer?
    private let root: SQLiteConnection?
    private let lease: SQLiteConnectionLease?

    init(url: URL, immutableReadOnly: Bool = false, createIfMissing: Bool = true) throws {
        root = nil
        lease = nil
        let result = sqlite3_open_v2(
            immutableReadOnly ? url.absoluteString + "?mode=ro&immutable=1" : url.path,
            &database,
            immutableReadOnly ? SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW : (createIfMissing ? SQLITE_OPEN_CREATE : SQLITE_OPEN_NOFOLLOW) | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK else {
            let error = currentError(code: result)
            sqlite3_close(database)
            database = nil
            throw error
        }
        do {
            sqlite3_busy_timeout(database, 5_000)
            if !immutableReadOnly { try execute("PRAGMA foreign_keys = ON") }
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    private init(root: SQLiteConnection, access: SQLiteConnectionAccess) {
        database = nil
        self.root = root
        lease = SQLiteConnectionLease(access: access)
    }

    deinit {
        if root == nil {
            sqlite3_close(database)
        }
    }

    public func execute(_ sql: String, bindings: [SQLiteValue] = []) throws {
        try validateLease()
        guard lease?.access != .readOnly else {
            throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
        }
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            recordSQLiteFailure(stage: .step, code: result)
            throw currentError(code: result)
        }
    }

    public func row(
        _ sql: String,
        bindings: [SQLiteValue] = []
    ) throws -> [String: SQLiteValue]? {
        try validateLease()
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard lease?.access != .readOnly || sqlite3_stmt_readonly(statement) != 0 else {
            throw SQLiteError(code: SQLITE_READONLY, message: "Writes require DeliveryStore.transact")
        }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE { return nil }
        guard result == SQLITE_ROW else {
            recordSQLiteFailure(stage: .step, code: result)
            throw currentError(code: result)
        }

        var resultRow: [String: SQLiteValue] = [:]
        for index in 0..<sqlite3_column_count(statement) {
            let name = String(cString: sqlite3_column_name(statement, index))
            resultRow[name] = value(in: statement, at: index)
        }
        return resultRow
    }

    // Fixed app projections use bounded cursor reads rather than repeated OFFSET queries.
    public func rows(_ sql: String, bindings: [SQLiteValue] = [], maximum: Int = 10_000) throws -> [[String: SQLiteValue]] {
        try validateLease()
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_stmt_readonly(statement) != 0 else {
            throw SQLiteError(code: SQLITE_READONLY, message: "Projection requires a read-only statement")
        }
        try bind(bindings, to: statement)
        var rows: [[String: SQLiteValue]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return rows }
            guard result == SQLITE_ROW else { throw currentError(code: result) }
            guard rows.count < maximum else { throw DocumentationOperationError.inventoryTooLarge }
            var row: [String: SQLiteValue] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                row[String(cString: sqlite3_column_name(statement, index))] = value(in: statement, at: index)
            }
            rows.append(row)
        }
    }

    public func scalarText(
        _ sql: String,
        bindings: [SQLiteValue] = []
    ) throws -> String? {
        guard let value = try row(sql, bindings: bindings)?.values.first else { return nil }
        if case let .text(text) = value { return text }
        if case .null = value { return nil }
        throw SQLiteError(code: SQLITE_MISMATCH, message: "Expected text result")
    }

    public func scalarInt(
        _ sql: String,
        bindings: [SQLiteValue] = []
    ) throws -> Int64? {
        guard let value = try row(sql, bindings: bindings)?.values.first else { return nil }
        if case let .integer(integer) = value { return integer }
        if case .null = value { return nil }
        throw SQLiteError(code: SQLITE_MISMATCH, message: "Expected integer result")
    }

    func executeScript(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? currentError(code: result).message
            sqlite3_free(errorMessage)
            throw SQLiteError(code: result, message: message)
        }
    }

    func createSnapshot(at destinationURL: URL) throws {
        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try execute("VACUUM INTO ?", bindings: [.text(temporaryURL.path)])
        guard rename(temporaryURL.path, destinationURL.path) == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: destinationURL.path])
        }
    }

    func makeScopedConnection(access: SQLiteConnectionAccess) -> SQLiteConnection {
        SQLiteConnection(root: root ?? self, access: access)
    }

    func invalidate() {
        lease?.invalidate()
    }

    func withTransactionCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
        let authorizerContext = SQLiteAuthorizerContext(isInTransaction: isInTransaction)
        let context = Unmanaged.passUnretained(authorizerContext).toOpaque()
        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreTransactionAuthorizer, context)
        guard result == SQLITE_OK else { throw currentError(code: result) }
        defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
        return try withExtendedLifetime(authorizerContext) { try body() }
    }

    func withReadCallbackRestrictions<T>(_ body: () throws -> T) throws -> T {
        let authorizerContext = SQLiteAuthorizerContext(isInTransaction: isInTransaction)
        let context = Unmanaged.passUnretained(authorizerContext).toOpaque()
        let result = sqlite3_set_authorizer(databaseHandle, deliveryStoreReadAuthorizer, context)
        guard result == SQLITE_OK else { throw currentError(code: result) }
        defer { sqlite3_set_authorizer(databaseHandle, nil, nil) }
        return try withExtendedLifetime(authorizerContext) { try body() }
    }

    var isInTransaction: Bool {
        sqlite3_get_autocommit(databaseHandle) == 0
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(databaseHandle, sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            recordSQLiteFailure(stage: .prepare, code: result)
            throw currentError(code: result)
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
        guard sqlite3_bind_parameter_count(statement) == bindings.count else {
            throw SQLiteError(code: SQLITE_RANGE, message: "Expected \(sqlite3_bind_parameter_count(statement)) bindings, received \(bindings.count)")
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case let .integer(integer): result = sqlite3_bind_int64(statement, index, integer)
            case let .real(real): result = sqlite3_bind_double(statement, index, real)
            case let .text(text): result = sqlite3_bind_text(statement, index, text, -1, transient)
            case let .blob(data):
                result = data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
                }
            case .null: result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw currentError(code: result) }
        }
    }

    private func value(in statement: OpaquePointer, at index: Int32) -> SQLiteValue {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: return .integer(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT: return .real(sqlite3_column_double(statement, index))
        case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(statement, index)))
        case SQLITE_BLOB:
            let count = Int(sqlite3_column_bytes(statement, index))
            guard count > 0, let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
            return .blob(Data(bytes: bytes, count: count))
        default: return .null
        }
    }

    private func currentError(code: Int32) -> SQLiteError {
        SQLiteError(code: code, message: databaseHandle.map { String(cString: sqlite3_errmsg($0)) } ?? "Database is closed")
    }

    private func recordSQLiteFailure(stage: SQLiteDiagnosticStage, code: Int32) {
        let extendedCode: Int32
        if let databaseHandle {
            extendedCode = sqlite3_extended_errcode(databaseHandle)
        } else {
            extendedCode = code
        }
        SQLiteDiagnostics.recordFailure(
            stage: stage,
            code: code,
            extendedCode: extendedCode,
            isInTransaction: isInTransaction
        )
    }

    private var databaseHandle: OpaquePointer? {
        root?.database ?? database
    }

    private func validateLease() throws {
        try lease?.validate()
    }
}

private final class SQLiteAuthorizerContext {
    let isInTransaction: Bool

    init(isInTransaction: Bool) {
        self.isInTransaction = isInTransaction
    }
}

private func deliveryStoreTransactionAuthorizer(
    context: UnsafeMutableRawPointer?,
    action: Int32,
    firstArgument: UnsafePointer<CChar>?,
    secondArgument: UnsafePointer<CChar>?,
    databaseName: UnsafePointer<CChar>?,
    triggerName: UnsafePointer<CChar>?
) -> Int32 {
    let transactionControlResult = deliveryStoreTransactionControlAuthorizer(
        context,
        action: action,
        firstArgument,
        secondArgument,
        databaseName,
        triggerName
    )
    guard transactionControlResult == SQLITE_OK else {
        recordAuthorizerDenial(
            context: context,
            action: action,
            protectedTable: "none",
            protectedColumn: "none"
        )
        return transactionControlResult
    }

    let protectedTable = "audit_events"
    let firstName = firstArgument.map { String(cString: $0) }
    let secondName = secondArgument.map { String(cString: $0) }
    if firstName?.caseInsensitiveCompare(protectedTable) == .orderedSame
        || secondName?.caseInsensitiveCompare(protectedTable) == .orderedSame {
        if action == SQLITE_READ {
            return SQLITE_OK
        }
        recordAuthorizerDenial(
            context: context,
            action: action,
            protectedTable: protectedTable,
            protectedColumn: sanitizedProtectedColumn(firstName, secondName)
        )
        return SQLITE_DENY
    }

    return SQLITE_OK
}

private func deliveryStoreTransactionControlAuthorizer(
    _: UnsafeMutableRawPointer?,
    action: Int32,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?
) -> Int32 {
    action == SQLITE_TRANSACTION || action == SQLITE_SAVEPOINT ? SQLITE_DENY : SQLITE_OK
}

private func deliveryStoreReadAuthorizer(
    context: UnsafeMutableRawPointer?,
    action: Int32,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?,
    _: UnsafePointer<CChar>?
) -> Int32 {
    switch action {
    case SQLITE_SELECT, SQLITE_READ, SQLITE_FUNCTION:
        return SQLITE_OK
    default:
        recordAuthorizerDenial(
            context: context,
            action: action,
            protectedTable: "none",
            protectedColumn: "none"
        )
        return SQLITE_DENY
    }
}

private func recordAuthorizerDenial(
    context: UnsafeMutableRawPointer?,
    action: Int32,
    protectedTable: String,
    protectedColumn: String
) {
    let isInTransaction = context.map {
        Unmanaged<SQLiteAuthorizerContext>.fromOpaque($0).takeUnretainedValue().isInTransaction
    } ?? false
    SQLiteDiagnostics.recordAuthorizerDenial(
        action: action,
        protectedTable: protectedTable,
        protectedColumn: protectedColumn,
        isInTransaction: isInTransaction
    )
}

private func sanitizedProtectedColumn(_ firstName: String?, _ secondName: String?) -> String {
    [firstName, secondName].contains {
        $0?.caseInsensitiveCompare("project_id") == .orderedSame
    } ? "project_id" : "none"
}

enum SQLiteDiagnosticStage: String {
    case authorizer
    case prepare
    case step
}

enum SQLiteDiagnostics {
    private static let logger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "SQLite")
    private static let capture = SQLiteDiagnosticCapture()

    static func resetForTesting() {
        capture.reset()
    }

    static func recentPayloadsForTesting() -> [String] {
        capture.snapshot()
    }

    static func recordAuthorizerDenial(
        action: Int32,
        protectedTable: String,
        protectedColumn: String,
        isInTransaction: Bool
    ) {
        record(
            event: "release_radar_sqlite_authorizer_denied",
            stage: .authorizer,
            code: SQLITE_AUTH,
            extendedCode: SQLITE_AUTH,
            authorizerAction: action,
            protectedTable: protectedTable,
            protectedColumn: protectedColumn,
            isInTransaction: isInTransaction
        )
    }

    static func recordFailure(
        stage: SQLiteDiagnosticStage,
        code: Int32,
        extendedCode: Int32,
        isInTransaction: Bool
    ) {
        record(
            event: "release_radar_sqlite_failure",
            stage: stage,
            code: code,
            extendedCode: extendedCode,
            authorizerAction: nil,
            protectedTable: "none",
            protectedColumn: "none",
            isInTransaction: isInTransaction
        )
    }

    private static func record(
        event: String,
        stage: SQLiteDiagnosticStage,
        code: Int32,
        extendedCode: Int32,
        authorizerAction: Int32?,
        protectedTable: String,
        protectedColumn: String,
        isInTransaction: Bool
    ) {
        let primaryCode = code & 0xFF
        let payload = [
            "event=\(event)",
            "stage=\(stage.rawValue)",
            "primary_result=\(primaryCode)",
            "extended_result=\(extendedCode)",
            "authorizer_action=\(authorizerAction.map(String.init) ?? "none")",
            "authorizer_action_name=\(authorizerAction.map(authorizerActionName) ?? "none")",
            "protected_table=\(protectedTable)",
            "protected_column=\(protectedColumn)",
            "in_transaction=\(isInTransaction)",
        ].joined(separator: " ")
        logger.error("\(payload, privacy: .public)")
        capture.append(payload)
    }

    private static func authorizerActionName(_ action: Int32) -> String {
        switch action {
        case SQLITE_CREATE_INDEX: "SQLITE_CREATE_INDEX"
        case SQLITE_CREATE_TABLE: "SQLITE_CREATE_TABLE"
        case SQLITE_CREATE_TEMP_INDEX: "SQLITE_CREATE_TEMP_INDEX"
        case SQLITE_CREATE_TEMP_TABLE: "SQLITE_CREATE_TEMP_TABLE"
        case SQLITE_CREATE_TEMP_TRIGGER: "SQLITE_CREATE_TEMP_TRIGGER"
        case SQLITE_CREATE_TEMP_VIEW: "SQLITE_CREATE_TEMP_VIEW"
        case SQLITE_CREATE_TRIGGER: "SQLITE_CREATE_TRIGGER"
        case SQLITE_CREATE_VIEW: "SQLITE_CREATE_VIEW"
        case SQLITE_DELETE: "SQLITE_DELETE"
        case SQLITE_DROP_INDEX: "SQLITE_DROP_INDEX"
        case SQLITE_DROP_TABLE: "SQLITE_DROP_TABLE"
        case SQLITE_DROP_TEMP_INDEX: "SQLITE_DROP_TEMP_INDEX"
        case SQLITE_DROP_TEMP_TABLE: "SQLITE_DROP_TEMP_TABLE"
        case SQLITE_DROP_TEMP_TRIGGER: "SQLITE_DROP_TEMP_TRIGGER"
        case SQLITE_DROP_TEMP_VIEW: "SQLITE_DROP_TEMP_VIEW"
        case SQLITE_DROP_TRIGGER: "SQLITE_DROP_TRIGGER"
        case SQLITE_DROP_VIEW: "SQLITE_DROP_VIEW"
        case SQLITE_INSERT: "SQLITE_INSERT"
        case SQLITE_PRAGMA: "SQLITE_PRAGMA"
        case SQLITE_READ: "SQLITE_READ"
        case SQLITE_SELECT: "SQLITE_SELECT"
        case SQLITE_TRANSACTION: "SQLITE_TRANSACTION"
        case SQLITE_UPDATE: "SQLITE_UPDATE"
        case SQLITE_ATTACH: "SQLITE_ATTACH"
        case SQLITE_DETACH: "SQLITE_DETACH"
        case SQLITE_ALTER_TABLE: "SQLITE_ALTER_TABLE"
        case SQLITE_REINDEX: "SQLITE_REINDEX"
        case SQLITE_ANALYZE: "SQLITE_ANALYZE"
        case SQLITE_CREATE_VTABLE: "SQLITE_CREATE_VTABLE"
        case SQLITE_DROP_VTABLE: "SQLITE_DROP_VTABLE"
        case SQLITE_FUNCTION: "SQLITE_FUNCTION"
        case SQLITE_SAVEPOINT: "SQLITE_SAVEPOINT"
        case SQLITE_RECURSIVE: "SQLITE_RECURSIVE"
        default: "SQLITE_OTHER"
        }
    }
}

private final class SQLiteDiagnosticCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var payloads: [String] = []

    func reset() {
        lock.withLock { payloads.removeAll() }
    }

    func append(_ payload: String) {
        lock.withLock {
            payloads.append(payload)
            if payloads.count > 32 {
                payloads.removeFirst(payloads.count - 32)
            }
        }
    }

    func snapshot() -> [String] {
        lock.withLock { payloads }
    }
}

enum SQLiteConnectionAccess {
    case transaction
    case readOnly
}

private final class SQLiteConnectionLease: @unchecked Sendable {
    let access: SQLiteConnectionAccess

    private let lock = NSLock()
    private let ownerThreadID: UInt64
    private var isActive = true

    init(access: SQLiteConnectionAccess) {
        self.access = access
        ownerThreadID = Self.currentThreadID()
    }

    func validate() throws {
        lock.lock()
        let isActive = self.isActive
        lock.unlock()

        guard isActive else {
            throw SQLiteError(code: SQLITE_MISUSE, message: "SQLite callback scope has ended")
        }
        guard Self.currentThreadID() == ownerThreadID else {
            throw SQLiteError(code: SQLITE_MISUSE, message: "SQLite callback connection cannot cross execution contexts")
        }
    }

    func invalidate() {
        lock.lock()
        isActive = false
        lock.unlock()
    }

    private static func currentThreadID() -> UInt64 {
        var identifier: UInt64 = 0
        pthread_threadid_np(nil, &identifier)
        return identifier
    }
}
