import Foundation
import AppKit
import XCTest
@testable import ReleaseRadarCore
@testable import ReleaseRadar

final class EvidencePreviewTests: XCTestCase {
    @MainActor
    func testAppModelPublishesCurrentPreviewAndRejectsResultAfterObservationWithdrawal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-AppPreview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let projectID = ProjectID(rawValue: "app-preview")
        let evidenceID = EvidenceID(rawValue: "e")
        let readback = EvidenceReadback(
            evidence: .init(id: evidenceID, projectID: projectID, ticketID: nil, locator: .filePath("notes.md"), isAvailable: true),
            managedDocument: nil
        )
        let payload = DocumentationObservationPayload(
            identity: .init(projectID: projectID, registration: nil, rootID: nil, rootPath: nil, binding: nil),
            checkedAt: Date(timeIntervalSince1970: 1),
            documentationState: .legacy(.unavailable),
            evidence: [readback]
        )
        let observer = DocumentationObservationCoordinator { _ in payload }
        await observer.refresh(projectID: projectID)
        let available = EvidencePreview(identity: readback.evidence.locator, path: "notes.md", status: .available,
                                        content: .text("current", isTruncated: false))
        let currentModel = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("current.sqlite")),
            externalServicesSuppressed: true,
            documentationObserver: observer,
            evidencePreviewLoader: { _, _, _ in available }
        )
        let current = await currentModel.previewEvidence(projectID: projectID, evidenceID: evidenceID)
        XCTAssertEqual(current, available)

        let loader = ControlledEvidencePreviewLoader()
        let staleModel = AppModel(
            store: DeliveryStore(databaseURL: directory.appendingPathComponent("stale.sqlite")),
            externalServicesSuppressed: true,
            documentationObserver: observer,
            evidencePreviewLoader: { _, _, _ in await loader.load() }
        )
        let task = Task { await staleModel.previewEvidence(projectID: projectID, evidenceID: evidenceID) }
        await loader.waitUntilEntered()
        observer.invalidate(projectID: projectID)
        await loader.finish(available)
        let stale = await task.value
        XCTAssertEqual(stale.status, .rejected)
        XCTAssertNil(stale.content)
    }

    @MainActor
    func testPreviewCoordinatorWithdrawsContentAndRejectsLateResultAfterObservationChange() async {
        let coordinator = EvidencePreviewCoordinator()
        let loader = ControlledEvidencePreviewLoader()
        let key = EvidencePreviewRequestKey(evidenceID: .init(rawValue: "e"), locator: .filePath("notes.md"), observationGeneration: 1)
        let task = Task { await coordinator.load(key: key) { await loader.load() } }
        await loader.waitUntilEntered()
        coordinator.invalidate()
        await loader.finish(.init(identity: .filePath("notes.md"), path: "notes.md", status: .available, content: .text("late", isTruncated: false)))
        await task.value
        XCTAssertNil(coordinator.result)
    }
    func testLegacyPreviewUsesExactAuthorizedPrimaryOrWorktreeAndDeniesExternalPath() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-LegacyPreview-\(UUID().uuidString)")
        let primary = directory.appendingPathComponent("primary")
        let worktree = primary.appendingPathComponent("saved-worktree")
        let external = directory.appendingPathComponent("external")
        for root in [primary, worktree, external] { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let primaryFile = primary.appendingPathComponent("notes.md")
        let worktreeFile = worktree.appendingPathComponent("result.txt")
        let oversizedFile = primary.appendingPathComponent("oversized.txt")
        let externalFile = external.appendingPathComponent("secret.txt")
        try Data("primary".utf8).write(to: primaryFile)
        try Data("worktree".utf8).write(to: worktreeFile)
        try Data("external".utf8).write(to: externalFile)
        XCTAssertTrue(FileManager.default.createFile(atPath: oversizedFile.path, contents: nil))
        let oversizedHandle = try FileHandle(forWritingTo: oversizedFile)
        try oversizedHandle.truncate(atOffset: UInt64(RepositoryDocumentContract.Limits().maximumFileBytes + 1))
        try oversizedHandle.close()
        let store = DeliveryStore(databaseURL: directory.appendingPathComponent("store.sqlite"))
        let projectID = ProjectID(rawValue: "legacy-preview")
        try await store.transact(actor: .init(id: "fixture"), reason: "Legacy preview fixture") { c in
            try c.execute("INSERT INTO projects (id, name) VALUES (?, 'Legacy')", bindings: [.text(projectID.rawValue)])
            try c.execute("INSERT INTO project_registrations (project_id, registration_id, request_generation, setup_state) VALUES (?, 'registration', 1, 'complete')", bindings: [.text(projectID.rawValue)])
            for (id, root) in [("primary", primary), ("worktree", worktree)] {
                try c.execute("INSERT INTO project_roots (id, project_id, path) VALUES (?, ?, ?)", bindings: [.text(id), .text(projectID.rawValue), .text(root.path)])
                try c.execute("INSERT INTO project_bookmarks (project_id, path, bookmark_data, is_stale) VALUES (?, ?, ?, 0)", bindings: [.text(projectID.rawValue), .text(root.path), .blob(Data(root.path.utf8))])
            }
            for (id, path) in [("primary-evidence", primaryFile.path), ("worktree-evidence", worktreeFile.path), ("oversized-evidence", oversizedFile.path), ("external-evidence", externalFile.path)] {
                try c.execute("INSERT INTO evidence (id, project_id, path, is_available) VALUES (?, ?, ?, 1)", bindings: [.text(id), .text(projectID.rawValue), .text(path)])
            }
        }
        let bookmarks = EvidencePreviewBookmarkStore()
        let auditBefore = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        let primaryResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "primary-evidence"), bookmarkStore: bookmarks)
        let worktreeResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "worktree-evidence"), bookmarkStore: bookmarks)
        let oversizedResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "oversized-evidence"), bookmarkStore: bookmarks)
        let externalResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "external-evidence"), bookmarkStore: bookmarks)
        XCTAssertEqual(primaryResult.content, .text("primary", isTruncated: false))
        XCTAssertEqual(worktreeResult.content, .text("worktree", isTruncated: false))
        XCTAssertEqual(oversizedResult.status, .oversized)
        XCTAssertEqual(externalResult.status, .inaccessible)
        XCTAssertEqual(externalResult.recovery, .relocateLegacyEvidence)
        XCTAssertNil(externalResult.content)
        let inaccessiblePrimary = await store.previewEvidence(
            projectID: projectID,
            evidenceID: .init(rawValue: "primary-evidence"),
            bookmarkStore: FailingEvidencePreviewBookmarkStore()
        )
        XCTAssertEqual(inaccessiblePrimary.status, .inaccessible)
        XCTAssertEqual(inaccessiblePrimary.recovery, .restorePrimary(rootID: .init(rawValue: "primary"), path: primary.path))
        let auditAfterPreviews = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(auditAfterPreviews, auditBefore)

        let accessGate = EvidencePreviewAccessGate()
        let lateTask = Task {
            await store.previewEvidence(
                projectID: projectID,
                evidenceID: .init(rawValue: "worktree-evidence"),
                bookmarkStore: BlockingEvidencePreviewBookmarkStore(gate: accessGate)
            )
        }
        await accessGate.waitUntilEntered()
        try await store.transact(actor: .init(id: "fixture"), reason: "Replace synthetic worktree grant") { c in
            try c.execute("UPDATE project_bookmarks SET bookmark_data = ? WHERE project_id = ? AND path = ?", bindings: [.blob(Data("replacement".utf8)), .text(projectID.rawValue), .text(worktree.path)])
        }
        await accessGate.release()
        let lateResult = await lateTask.value
        XCTAssertEqual(lateResult.status, .rejected)
        XCTAssertNil(lateResult.content)

        try await store.transact(actor: .init(id: "fixture"), reason: "Restore synthetic worktree grant") { c in
            try c.execute("UPDATE project_bookmarks SET bookmark_data = ? WHERE project_id = ? AND path = ?", bindings: [.blob(Data(worktree.path.utf8)), .text(projectID.rawValue), .text(worktree.path)])
        }
        try FileManager.default.removeItem(at: worktreeFile)
        let missingResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "worktree-evidence"), bookmarkStore: bookmarks)
        XCTAssertEqual(missingResult.status, .missing)
        try await store.transact(actor: .init(id: "fixture"), reason: "Lose synthetic worktree grant") { c in
            try c.execute("UPDATE project_bookmarks SET is_stale = 1 WHERE project_id = ? AND path = ?", bindings: [.text(projectID.rawValue), .text(worktree.path)])
        }
        let staleResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "worktree-evidence"), bookmarkStore: bookmarks)
        XCTAssertEqual(staleResult.status, .stale)
        XCTAssertEqual(staleResult.recovery, .reconnectWorktree(rootID: .init(rawValue: "worktree"), path: worktree.path))
        let auditAfter = try await store.read { try $0.scalarInt("SELECT COUNT(*) FROM audit_events") }
        XCTAssertEqual(auditAfter, auditBefore.map { $0 + 3 })

        try FileManager.default.removeItem(at: primaryFile)
        try FileManager.default.createSymbolicLink(at: primaryFile, withDestinationURL: externalFile)
        let unsafeResult = await store.previewEvidence(projectID: projectID, evidenceID: .init(rawValue: "primary-evidence"), bookmarkStore: bookmarks)
        XCTAssertEqual(unsafeResult.status, .rejected)
    }
    func testManagedTextPreviewUsesAcceptedIdentityAndNeverSilentlyTruncates() throws {
        let fixture = try managedFixture()
        let result = try EvidencePreviewReader().previewManaged(
            artifactID: "draft",
            binding: fixture.binding,
            root: fixture.root
        )

        XCTAssertEqual(result.identity, .managedDocument(artifactID: "draft"))
        XCTAssertEqual(result.path, "docs/plans/draft.md")
        XCTAssertEqual(result.status, .available)
        XCTAssertEqual(result.content, .text("# Proposed plan\n", isTruncated: false))
    }

    func testManagedPreviewFailsClosedWhenMutableBytesNoLongerMatchAcceptedCatalog() throws {
        let fixture = try managedFixture()
        try Data("changed".utf8).write(to: fixture.root.appendingPathComponent("docs/plans/evidence.md"))

        let result = try EvidencePreviewReader().previewManaged(
            artifactID: "evidence",
            binding: fixture.binding,
            root: fixture.root
        )

        XCTAssertEqual(result.status, .rejected)
        XCTAssertNil(result.content)
    }

    func testManagedPreviewReportsOversizedContentInsteadOfTruncatingIt() throws {
        let fixture = try managedFixture()
        try Data(repeating: 65, count: EvidencePreviewReader.maximumPreviewBytes + 1)
            .write(to: fixture.root.appendingPathComponent("docs/plans/draft.md"))

        let result = try EvidencePreviewReader().previewManaged(
            artifactID: "draft",
            binding: fixture.binding,
            root: fixture.root
        )

        XCTAssertEqual(result.status, .oversized)
        XCTAssertNil(result.content)
    }

    func testTextPreviewLabelsCharacterTruncationAndRejectsInvalidUTF8() {
        let reader = EvidencePreviewReader()
        let text = String(repeating: "x", count: EvidencePreviewReader.maximumPreviewTextCharacters + 1)
        let truncated = reader.decode(identity: .filePath("notes.txt"), path: "notes.txt", bytes: Data(text.utf8))
        guard case let .text(preview, isTruncated) = truncated.content else { return XCTFail("Expected text preview") }
        XCTAssertEqual(preview.count, EvidencePreviewReader.maximumPreviewTextCharacters)
        XCTAssertTrue(isTruncated)

        let invalid = reader.decode(identity: .filePath("notes.txt"), path: "notes.txt", bytes: Data([0xff]))
        XCTAssertEqual(invalid.status, .rejected)
        XCTAssertNil(invalid.content)
    }

    func testRasterPreviewValidatesDecodedMetadataAndRejectsMalformedBytes() throws {
        let reader = EvidencePreviewReader()
        let image = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/delivery/evidence/rr10-needs-review.png"))
        let valid = reader.decode(identity: .managedDocument(artifactID: "image"), path: "docs/evidence/image.png", bytes: image)
        XCTAssertEqual(valid.status, .available)
        guard case let .raster(_, _, width, height) = valid.content else { return XCTFail("Expected raster preview") }
        XCTAssertGreaterThan(width, 0)
        XCTAssertGreaterThan(height, 0)

        let malformed = reader.decode(identity: .managedDocument(artifactID: "image"), path: "docs/evidence/image.png", bytes: Data("not a png".utf8))
        XCTAssertEqual(malformed.status, .rejected)
        XCTAssertNil(malformed.content)

        let oversizedBitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4_097, pixelsHigh: 1,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let oversizedDimensions = try XCTUnwrap(oversizedBitmap.representation(using: .png, properties: [:]))
        XCTAssertLessThan(oversizedDimensions.count, EvidencePreviewReader.maximumPreviewBytes)
        XCTAssertEqual(reader.decode(identity: .filePath("wide.png"), path: "wide.png", bytes: oversizedDimensions).status, .rejected)

        let unsupported = reader.decode(identity: .filePath("archive.zip"), path: "archive.zip", bytes: Data([1, 2, 3]))
        XCTAssertEqual(unsupported.status, .unsupported)
        XCTAssertNil(unsupported.content)
    }

    private func managedFixture() throws -> (root: URL, binding: ProjectDocumentationBinding) {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("ReleaseRadar-Preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("repository", isDirectory: true)
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/RepositoryDocuments/valid")
        try FileManager.default.copyItem(at: source, to: root)
        try Data(RepositoryDocumentContract.managedGuidanceBlock.utf8).write(to: root.appendingPathComponent("AGENTS.md"))
        let snapshot = try RepositoryDocumentValidator().validateCurrent(authorizedRoot: root)
        return (root, try ProjectDocumentationBinding(projectID: .init(rawValue: "preview"), rootID: .init(rawValue: "root"), acceptedSnapshot: snapshot))
    }
}

private struct EvidencePreviewBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
    }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        try await body(resolve(bookmark))
    }
}

private struct FailingEvidencePreviewBookmarkStore: ProjectBookmarkStoring {
    func makeBookmark(for url: URL) throws -> Data { Data() }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark { throw CocoaError(.fileReadNoPermission) }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        throw CocoaError(.fileReadNoPermission)
    }
}

private struct BlockingEvidencePreviewBookmarkStore: ProjectBookmarkStoring {
    let gate: EvidencePreviewAccessGate
    func makeBookmark(for url: URL) throws -> Data { Data(url.path.utf8) }
    func resolve(_ bookmark: Data) throws -> ResolvedProjectBookmark {
        .init(url: URL(fileURLWithPath: String(decoding: bookmark, as: UTF8.self)), isStale: false)
    }
    func withSecurityScopedAccess<T: Sendable>(bookmark: Data, _ body: @Sendable (ResolvedProjectBookmark) async throws -> T) async throws -> T {
        await gate.pause()
        return try await body(resolve(bookmark))
    }
}

private actor EvidencePreviewAccessGate {
    private var entered = false
    private var released = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    func pause() async {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        guard !released else { return }
        await withCheckedContinuation { releaseContinuations.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private actor ControlledEvidencePreviewLoader {
    private var entered = false
    private var enteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var resultContinuation: CheckedContinuation<EvidencePreview, Never>?
    func load() async -> EvidencePreview {
        entered = true
        enteredContinuations.forEach { $0.resume() }
        enteredContinuations.removeAll()
        return await withCheckedContinuation { resultContinuation = $0 }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredContinuations.append($0) }
    }
    func finish(_ result: EvidencePreview) { resultContinuation?.resume(returning: result); resultContinuation = nil }
}
