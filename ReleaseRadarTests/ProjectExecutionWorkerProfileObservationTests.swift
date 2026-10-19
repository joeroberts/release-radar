import Foundation
import XCTest
@testable import ReleaseRadar
@testable import ReleaseRadarCore

final class ProjectExecutionWorkerProfileObservationTests: XCTestCase {
    private actor ReadbackProbe {
        private(set) var count = 0
        func mark() { count += 1 }
    }

    func testObservationReturnsOnlyBoundedCandidateProfilesForCurrentProjectContext() async throws {
        let fixture = try await Fixture()
        let observation = ProjectExecutionWorkerProfileObservation(selectedCodexContextID: fixture.contextID,
            configurationVersion: "v1", observedAt: Date(timeIntervalSinceReferenceDate: 1), entries: [
                .init(profileID: "rr-delivery-one", observedDefinition: fixture.definition),
                .init(profileID: "rr-project-ro", observedDefinition: fixture.definition),
                .init(profileID: "unrelated-profile", observedDefinition: fixture.definition),
            ])
        await fixture.configuration.setObservation(observation)

        let result = try await fixture.coordinator.observeWorkerProfiles(project: fixture.project)

        XCTAssertEqual(result.selectedCodexContextID, fixture.contextID)
        XCTAssertEqual(result.configurationVersion, "v1")
        XCTAssertEqual(result.entries.map(\.profileID), ["rr-delivery-one", "rr-project-ro"])
    }

    func testObservationFailsClosedForContextDriftAndUnavailableAdapter() async throws {
        let fixture = try await Fixture()
        await fixture.configuration.setObservation(.init(selectedCodexContextID: fixture.contextID,
            configurationVersion: "v1", observedAt: Date(), entries: []))
        await fixture.configuration.driftTo(UUID())
        await XCTAssertThrowsErrorAsync(try await fixture.coordinator.observeWorkerProfiles(project: fixture.project))

        let unavailable = try await Fixture()
        await unavailable.configuration.setFailure(ProjectExecutionError.unavailable)
        await XCTAssertThrowsErrorAsync(try await unavailable.coordinator.observeWorkerProfiles(project: unavailable.project))
    }

    func testObservationClosesItsDedicatedConfigurationConnectionOnSuccessAndFailure() async throws {
        let success = try await Fixture()
        await success.configuration.setObservation(.init(selectedCodexContextID: success.contextID,
            configurationVersion: "v1", observedAt: Date(), entries: []))
        _ = try await success.coordinator.observeWorkerProfiles(project: success.project)
        let successFinishCount = await success.configuration.finishCount
        XCTAssertEqual(successFinishCount, 1)

        let readFailure = try await Fixture()
        await readFailure.configuration.setFailure(ProjectExecutionError.unavailable)
        await XCTAssertThrowsErrorAsync(try await readFailure.coordinator.observeWorkerProfiles(project: readFailure.project))
        let readFailureFinishCount = await readFailure.configuration.finishCount
        XCTAssertEqual(readFailureFinishCount, 1)

        let cleanupFailure = try await Fixture()
        await cleanupFailure.configuration.setObservation(.init(selectedCodexContextID: cleanupFailure.contextID,
            configurationVersion: "v1", observedAt: Date(), entries: []))
        await cleanupFailure.configuration.setFinishFailure(ProjectExecutionError.unavailable)
        await XCTAssertThrowsErrorAsync(try await cleanupFailure.coordinator.observeWorkerProfiles(project: cleanupFailure.project))
        let cleanupFailureFinishCount = await cleanupFailure.configuration.finishCount
        XCTAssertEqual(cleanupFailureFinishCount, 1)
    }

    func testObservationRejectsMalformedDuplicateAndOverBoundEntries() async throws {
        for entries in [
            [ProjectExecutionWorkerProfileObservation.Entry(profileID: "bad/profile", observedDefinition: Data("{}".utf8))],
            [
                .init(profileID: "rr-delivery-one", observedDefinition: Data("{}".utf8)),
                .init(profileID: "rr-delivery-one", observedDefinition: Data("{}".utf8)),
            ],
        ] {
            let fixture = try await Fixture()
            await fixture.configuration.setObservation(.init(selectedCodexContextID: fixture.contextID,
                configurationVersion: "v1", observedAt: Date(), entries: entries))
            await XCTAssertThrowsErrorAsync(try await fixture.coordinator.observeWorkerProfiles(project: fixture.project))
        }
    }

    func testSetupClientParsesSyntheticUserLayerReadbackWithoutLaunchingAnAppServer() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let probe = ReadbackProbe()
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { context, files in
                try CodexExecutionContextLease(context: context, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, workerProfileObservationReadback: { primaryRoot, readback in
                await probe.mark()
                XCTAssertEqual(primaryRoot, "/synthetic/project")
                XCTAssertTrue(readback)
                return userLayerResponse(home: root, version: "user-layer-v1", permissions: [
                    "rr-delivery-one": ["filesystem": [:], "network": ["enabled": false]],
                    "unrelated-profile": ["filesystem": [:], "network": ["enabled": false]],
                ])
            })

        let selectedContext = try await client.selectedCodexContextID()
        XCTAssertEqual(selectedContext, context.id)
        let observation = try await client.observeWorkerProfiles(primaryRoot: "/synthetic/project")
        XCTAssertEqual(observation.selectedCodexContextID, context.id)
        XCTAssertEqual(observation.configurationVersion, "user-layer-v1")
        XCTAssertEqual(observation.entries.map(\.profileID), ["rr-delivery-one"])
        let readbackCount = await probe.count
        XCTAssertEqual(readbackCount, 1)
    }

    func testSetupClientRejectsMismatchedSyntheticReadbackContext() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { context, files in
                try CodexExecutionContextLease(context: context, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, workerProfileObservationReadback: { _, _ in
                let changed = try CodexExecutionContext(home: root, bookmark: Data([2]))
                try store.saveCodexContext(changed, expected: context)
                return userLayerResponse(home: root, version: "user-layer-v1", permissions: [:])
            })

        let selectedContext = try await client.selectedCodexContextID()
        XCTAssertEqual(selectedContext, context.id)
        await XCTAssertThrowsErrorAsync(try await client.observeWorkerProfiles(primaryRoot: "/synthetic/project"))
    }

    func testSetupClientRejectsMalformedUserLayerVersionAndPermissions() async throws {
        for invalid in ["version", "permissions"] {
            let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
            let store = try ProjectExecutionFileStore(root: root, create: true)
            let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
            try store.saveCodexContext(context, expected: nil)
            let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
                contextAccessFactory: { context, files in
                    try CodexExecutionContextLease(context: context, current: { try files.codexContext() },
                        resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
                }, workerProfileObservationReadback: { _, _ in
                    if invalid == "version" {
                        return userLayerResponse(home: root, version: "", permissions: [:])
                    }
                    return ["layers": [["name": ["type": "user", "file": root.appendingPathComponent("config.toml").path],
                                         "version": "v1", "config": ["permissions": "not-an-object"]]]]
                })
            let selectedContext = try await client.selectedCodexContextID()
            XCTAssertEqual(selectedContext, context.id)
            await XCTAssertThrowsErrorAsync(try await client.observeWorkerProfiles(primaryRoot: "/synthetic/project"))
        }
    }

    func testSetupClientRejectsMoreThan256ReleaseRadarCandidatesInsteadOfTruncating() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { context, files in
                try CodexExecutionContextLease(context: context, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, workerProfileObservationReadback: { _, _ in
                let permissions = Dictionary(uniqueKeysWithValues: (0 ... 256).map { index in
                    ("rr-delivery-\(index)", ["filesystem": [:], "network": ["enabled": false]] as [String: Any])
                })
                return userLayerResponse(home: root, version: "user-layer-v1", permissions: permissions)
            })

        let selectedContext = try await client.selectedCodexContextID()
        XCTAssertEqual(selectedContext, context.id)
        await XCTAssertThrowsErrorAsync(try await client.observeWorkerProfiles(primaryRoot: "/synthetic/project"))
    }

    func testSetupClientRejectsOversizeReleaseRadarDefinitionInsteadOfTruncating() async throws {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
        let store = try ProjectExecutionFileStore(root: root, create: true)
        let context = try CodexExecutionContext(home: root, bookmark: Data([1]))
        try store.saveCodexContext(context, expected: nil)
        let client = ProjectExecutionSetupClient(plugin: nil, executionRoot: { root },
            contextAccessFactory: { context, files in
                try CodexExecutionContextLease(context: context, current: { try files.codexContext() },
                    resolve: { _ in .init(url: root, isStale: false) }, start: { _ in true }, stop: { _ in })
            }, workerProfileObservationReadback: { _, _ in
                userLayerResponse(home: root, version: "user-layer-v1", permissions: [
                    "rr-delivery-oversize": ["filesystem": ["paths": String(repeating: "x", count: 32_768)],
                                               "network": ["enabled": false]],
                ])
            })

        let selectedContext = try await client.selectedCodexContextID()
        XCTAssertEqual(selectedContext, context.id)
        await XCTAssertThrowsErrorAsync(try await client.observeWorkerProfiles(primaryRoot: "/synthetic/project"))
    }

    private actor Configuration: ProjectExecutionConfiguring {
        var contextID: UUID?
        var observation: ProjectExecutionWorkerProfileObservation?
        var failure: Error?
        var drift: UUID?
        var finishFailure: Error?
        private(set) var finishCount = 0

        func selectedCodexContextID() async throws -> UUID? { contextID }
        func useCodexContext(_ expected: UUID?) async throws { guard expected == contextID else { throw CodexExecutionContextError.changed } }
        func validateInstallation(handlerPath: String) async throws {}
        func sharedExecutionSkill() async throws -> ProjectExecutionSharedExecutionSkill {
            try .init(skillFile: "/selected/shared-execution/SKILL.md", pluginVersion: "1", packageDigest: String(repeating: "a", count: 64))
        }
        func validateHandlerIdentity(handlerPath: String) async throws {}
        func hookStorage(primaryRoot: String) async throws -> ProjectExecutionHookStorage { .projectFile }
        func saveInlineHook(primaryRoot: String, data: Data, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func verifyHook(primaryRoot: String, checkout: String, command: String, permitOwnedTrust: Bool, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func finishConfiguration() async throws {
            finishCount += 1
            if let finishFailure { throw finishFailure }
        }
        func recoverConfigurationConnection() async throws {}
        func prepareWorkerProfile(primaryRoot: String, profile: ProjectExecutionPermissionProfile) async throws {}
        func workerProfileExists(primaryRoot: String, profileID: String) async throws -> Bool { false }
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data) async throws {}
        func removeWorkerProfile(primaryRoot: String, profileID: String, expected: Data, beforeWrite: @Sendable () async throws -> Void) async throws { try await beforeWrite() }
        func observeWorkerProfiles(primaryRoot: String) async throws -> ProjectExecutionWorkerProfileObservation {
            if let failure { throw failure }
            let value = try XCTUnwrap(observation)
            if let drift { contextID = drift }
            return value
        }
        func setContext(_ value: UUID) { contextID = value }
        func setObservation(_ value: ProjectExecutionWorkerProfileObservation) { observation = value }
        func setFailure(_ value: Error) { failure = value }
        func driftTo(_ value: UUID) { drift = value }
        func setFinishFailure(_ value: Error) { finishFailure = value }
        func resetFinishCount() { finishCount = 0 }
    }

    private struct Fixture {
        let root: URL
        let project: AuthorizedProject
        let contextID: UUID
        let definition = Data(#"{"filesystem":{},"network":{"enabled":false}}"#.utf8)
        let configuration: Configuration
        let coordinator: ProjectExecutionSetupCoordinator

        init() async throws {
            let fixtureRoot = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
            root = fixtureRoot
            let repository = fixtureRoot.appendingPathComponent("Repository")
            try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
            let registration = ProjectRegistration(projectID: .init(rawValue: "project-one"), registrationID: "registration-one", requestGeneration: 1)
            project = .init(registration: registration, canonicalRoot: repository, authorizedRoots: [repository])
            contextID = UUID(); configuration = Configuration(); await configuration.setContext(contextID)
            coordinator = .init(root: { fixtureRoot.appendingPathComponent("Execution") }, configuration: configuration, handlerPath: "/RR/handler")
            try await coordinator.prepare(project: project)
            await configuration.resetFinishCount()
        }
    }
}

private func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T,
                                          file: StaticString = #filePath, line: UInt = #line) async {
    do { _ = try await expression(); XCTFail("Expected error", file: file, line: line) } catch {}
}

private func userLayerResponse(home: URL, version: String, permissions: [String: Any]) -> [String: Any] {
    ["layers": [["name": ["type": "user", "file": home.appendingPathComponent("config.toml").path],
                 "version": version, "config": ["permissions": permissions]]]]
}
