# RR-R9C XCTest-host isolation correction — review package after fix round 1

- Controlling brief: `docs/delivery/task-briefs/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-brief.md`
- Brief SHA-256: `2d4c855adecab3c20da618f8147f60aa42d8da903ea000e5675e58eb3f7571de`
- Implementer report: `.superpowers/sdd/2026-08-29-release-radar-active-phase-selection/task-3-test-host-isolation-correction-report.md`
- Accepted pre-correction blobs: `916e18c67469f60079fc8b829bdfbe6582de203b`, `cd926cbdadaa49902d8282bd79dcd1bf401a013d`
- Current post-fix blobs: `e0965e340b0c6e49451ecdcf31188c301cf9b8ba`, `e0206a8c3fef481c75603d324904a279aabeba06`
- Branch/HEAD: `codex/release-radar-mvp` / `bcd108f3d1a95be7733a39f42d8b68c98748a30e`
- This full current correction diff supersedes the first review package. Intermediate uncommitted blobs were not written to the object database; reviewers must scope re-review to the four prior Required findings and detect new breakage in this current two-file correction.

```diff
--- a/ReleaseRadar/App/ReleaseRadarApp.swift
+++ b/ReleaseRadar/App/ReleaseRadarApp.swift
@@ -1,9 +1,77 @@
 import AppKit
+import Darwin
 import OSLog
 import ReleaseRadarCore
 import SwiftUI
 
+enum AppHostMode: Equatable {
+    case application
+    case xctestHost(databaseURL: URL)
+    case xctestHostUnavailable(databaseURL: URL)
+
+}
+
+enum XCTestHostPreparation {
+    case application
+    case xctestHost(databaseURL: URL, store: DeliveryStore)
+    case xctestHostUnavailable(databaseURL: URL)
+}
+
 enum AppLaunchConfiguration {
+    static func isXCTestHost(environment: [String: String]) -> Bool {
+        environment["XCTestConfigurationFilePath"] != nil
+    }
+
+    static func hostMode(
+        environment: [String: String],
+        temporaryDirectory: URL,
+        processIdentifier: Int32,
+        fileManager: FileManager = .default
+    ) -> AppHostMode {
+        switch prepareXCTestHost(
+            environment: environment,
+            temporaryDirectory: temporaryDirectory,
+            processIdentifier: processIdentifier,
+            fileManager: fileManager
+        ) {
+        case .application:
+            .application
+        case let .xctestHost(databaseURL, _):
+            .xctestHost(databaseURL: databaseURL)
+        case let .xctestHostUnavailable(databaseURL):
+            .xctestHostUnavailable(databaseURL: databaseURL)
+        }
+    }
+
+    static func prepareXCTestHost(
+        environment: [String: String],
+        temporaryDirectory: URL,
+        processIdentifier: Int32,
+        fileManager _: FileManager = .default,
+        storeFactory: (URL) -> DeliveryStore = { DeliveryStore(databaseURL: $0) }
+    ) -> XCTestHostPreparation {
+        guard isXCTestHost(environment: environment) else { return .application }
+
+        let hostDirectory = temporaryDirectory.standardizedFileURL
+            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
+            .standardizedFileURL
+        let databaseURL = hostDirectory
+            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
+            .standardizedFileURL
+        guard exclusiveCreateDirectory(at: hostDirectory) else {
+            return .xctestHostUnavailable(databaseURL: databaseURL)
+        }
+
+        return .xctestHost(databaseURL: databaseURL, store: storeFactory(databaseURL))
+    }
+
+    private static func exclusiveCreateDirectory(at url: URL) -> Bool {
+        url.withUnsafeFileSystemRepresentation { path in
+            guard let path else { return false }
+            return mkdir(path, S_IRWXU) == 0
+        }
+    }
+
     static func externalServicesSuppressed(arguments: [String], isDebugBuild: Bool) -> Bool {
         isDebugBuild && arguments.contains("--rr10-capture")
     }
@@ -39,6 +107,9 @@
     private var agentBridgeHost: AgentBridgeApplicationHost?
 
     func applicationDidFinishLaunching(_ notification: Notification) {
+        guard !AppLaunchConfiguration.isXCTestHost(environment: ProcessInfo.processInfo.environment) else {
+            return
+        }
         NSApp.setActivationPolicy(.regular)
         NSApp.activate(ignoringOtherApps: true)
 #if DEBUG
@@ -49,9 +120,6 @@
             return
         }
 #endif
-        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
-            return
-        }
         Task { [weak self] in
             do {
                 let services = ReleaseRadarAppServices.shared
@@ -99,9 +167,38 @@
 @main
 struct ReleaseRadarApp: App {
     @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
-    @State private var model: AppModel
+    @State private var model: AppModel?
+    private let xctestHostStore: DeliveryStore?
 
     init() {
+        let processInfo = ProcessInfo.processInfo
+        let hostPreparation = AppLaunchConfiguration.prepareXCTestHost(
+            environment: processInfo.environment,
+            temporaryDirectory: FileManager.default.temporaryDirectory,
+            processIdentifier: processInfo.processIdentifier
+        )
+        let xctestLogger = Logger(subsystem: "com.rekonlabs.ReleaseRadar", category: "XCTestHostIsolation")
+
+        switch hostPreparation {
+        case let .xctestHost(databaseURL, store):
+            xctestHostStore = store
+            _model = State(initialValue: nil)
+            xctestLogger.notice(
+                "Using isolated XCTest host database \(databaseURL.path, privacy: .public) for PID \(processInfo.processIdentifier)"
+            )
+            return
+        case let .xctestHostUnavailable(databaseURL):
+            xctestHostStore = nil
+            _model = State(initialValue: nil)
+            xctestLogger.error(
+                "XCTest host directory preparation unavailable for \(databaseURL.path, privacy: .public) for PID \(processInfo.processIdentifier); rendering inert host"
+            )
+            return
+        case .application:
+            xctestHostStore = nil
+            break
+        }
+
         let services = ReleaseRadarAppServices.shared
 #if DEBUG
         let isDebugBuild = true
@@ -147,8 +244,12 @@
 
     var body: some Scene {
         WindowGroup("Release Radar", id: "main") {
-            SidebarView(model: model)
-                .frame(minWidth: 760, minHeight: 520)
+            if let model {
+                SidebarView(model: model)
+                    .frame(minWidth: 760, minHeight: 520)
+            } else {
+                Text("Release Radar XCTest host is isolated")
+            }
         }
         .defaultSize(width: 1600, height: 820)
         .commands {
@@ -162,18 +263,30 @@
         }
 
         Window("Add Project", id: "add-project") {
-            AddProjectWindowView(model: model)
-                .frame(minWidth: 680, minHeight: 500)
+            if let model {
+                AddProjectWindowView(model: model)
+                    .frame(minWidth: 680, minHeight: 500)
+            } else {
+                Text("Release Radar XCTest host is isolated")
+            }
         }
         .defaultSize(width: 760, height: 560)
         .windowResizability(.contentMinSize)
 
         MenuBarExtra("Release Radar", systemImage: "dot.radiowaves.left.and.right") {
-            MenuBarContent(model: model)
+            if let model {
+                MenuBarContent(model: model)
+            } else {
+                Text("Release Radar XCTest host is isolated")
+            }
         }
 
         Settings {
-            SettingsView(model: model)
+            if let model {
+                SettingsView(model: model)
+            } else {
+                Text("Release Radar XCTest host is isolated")
+            }
         }
     }
 }
--- a/ReleaseRadarTests/AppRouteTests.swift
+++ b/ReleaseRadarTests/AppRouteTests.swift
@@ -40,6 +40,159 @@
         ))
     }
 
+    func testXCTestHostPreparationCreatesFreshPIDScopedStoreAndOverridesCapture() throws {
+        let root = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-XCTestHostPreparation-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
+        let xctestEnvironment = ["XCTestConfigurationFilePath": "/tmp/ReleaseRadarTests.xctestconfiguration"]
+        let emptyXCTestEnvironment = ["XCTestConfigurationFilePath": ""]
+        let firstPID: Int32 = 4_201
+        let secondPID: Int32 = 4_202
+        let expectedFirstURL = root.standardizedFileURL
+            .appendingPathComponent("ReleaseRadar-XCTestHost-\(firstPID)", isDirectory: true)
+            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
+            .standardizedFileURL
+
+        XCTAssertEqual(
+            AppLaunchConfiguration.hostMode(
+                environment: [:],
+                temporaryDirectory: root,
+                processIdentifier: firstPID
+            ),
+            .application
+        )
+        guard case let .xctestHost(databaseURL: firstDatabaseURL, store: _) = AppLaunchConfiguration.prepareXCTestHost(
+            environment: xctestEnvironment,
+            temporaryDirectory: root,
+            processIdentifier: firstPID
+        ) else {
+            return XCTFail("Expected the fresh XCTest host store")
+        }
+        guard case let .xctestHost(databaseURL: secondDatabaseURL, store: _) = AppLaunchConfiguration.prepareXCTestHost(
+            environment: emptyXCTestEnvironment,
+            temporaryDirectory: root,
+            processIdentifier: secondPID
+        ) else {
+            return XCTFail("Expected the empty XCTest value to create an isolated store")
+        }
+        XCTAssertEqual(firstDatabaseURL, expectedFirstURL)
+        XCTAssertNotEqual(firstDatabaseURL.deletingLastPathComponent(), root)
+        XCTAssertNotEqual(firstDatabaseURL, secondDatabaseURL)
+        XCTAssertEqual(secondDatabaseURL.deletingLastPathComponent().lastPathComponent, "ReleaseRadar-XCTestHost-\(secondPID)")
+        XCTAssertEqual(expectedFirstURL.lastPathComponent, "release-radar.sqlite")
+        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFirstURL.deletingLastPathComponent().path))
+        XCTAssertTrue(AppLaunchConfiguration.isXCTestHost(environment: xctestEnvironment))
+        XCTAssertTrue(AppLaunchConfiguration.isXCTestHost(environment: emptyXCTestEnvironment))
+        XCTAssertFalse(AppLaunchConfiguration.isXCTestHost(environment: [:]))
+        XCTAssertTrue(AppLaunchConfiguration.externalServicesSuppressed(
+            arguments: ["--rr10-capture", "--rr10-empty-store"],
+            isDebugBuild: true
+        ))
+    }
+
+    func testXCTestHostPreparationRejectsExistingDirectoryWithoutInvokingStoreFactory() throws {
+        let root = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-XCTestHostExistingDirectory-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
+        let processIdentifier: Int32 = 8_451
+        let pidDirectory = root.standardizedFileURL
+            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
+        try FileManager.default.createDirectory(at: pidDirectory, withIntermediateDirectories: true)
+        let staleSentinel = pidDirectory.appendingPathComponent("stale-sentinel")
+        let sentinelContents = Data("stale XCTest state".utf8)
+        try sentinelContents.write(to: staleSentinel)
+        let expectedURL = pidDirectory
+            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
+            .standardizedFileURL
+
+        let preparation = AppLaunchConfiguration.prepareXCTestHost(
+            environment: ["XCTestConfigurationFilePath": "present"],
+            temporaryDirectory: root,
+            processIdentifier: processIdentifier,
+            storeFactory: { _ in
+                XCTFail("The store factory must not run for a pre-existing PID directory")
+                fatalError("Unexpected store factory invocation")
+            }
+        )
+
+        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
+            return XCTFail("Expected the existing PID directory to keep the host unavailable")
+        }
+        XCTAssertEqual(databaseURL, expectedURL)
+        XCTAssertEqual(expectedURL.lastPathComponent, "release-radar.sqlite")
+        XCTAssertEqual(try Data(contentsOf: staleSentinel), sentinelContents)
+        XCTAssertTrue(FileManager.default.fileExists(atPath: pidDirectory.path))
+    }
+
+    func testXCTestHostPreparationRejectsExistingFileWithoutInvokingStoreFactory() throws {
+        let root = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-XCTestHostExistingFile-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
+        let processIdentifier: Int32 = 8_452
+        let pidEntry = root.standardizedFileURL
+            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
+        let fileContents = Data("PID entry is a file".utf8)
+        try fileContents.write(to: pidEntry)
+        let expectedURL = pidEntry
+            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
+            .standardizedFileURL
+
+        let preparation = AppLaunchConfiguration.prepareXCTestHost(
+            environment: ["XCTestConfigurationFilePath": "present"],
+            temporaryDirectory: root,
+            processIdentifier: processIdentifier,
+            storeFactory: { _ in
+                XCTFail("The store factory must not run for a pre-existing PID file")
+                fatalError("Unexpected store factory invocation")
+            }
+        )
+
+        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
+            return XCTFail("Expected the existing PID file to keep the host unavailable")
+        }
+        XCTAssertEqual(databaseURL, expectedURL)
+        XCTAssertEqual(try Data(contentsOf: pidEntry), fileContents)
+    }
+
+    func testXCTestHostPreparationRejectsExistingSymlinkWithoutInvokingStoreFactory() throws {
+        let root = FileManager.default.temporaryDirectory
+            .appendingPathComponent("ReleaseRadar-XCTestHostSymlink-\(UUID().uuidString)", isDirectory: true)
+        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
+        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
+        let processIdentifier: Int32 = 8_453
+        let targetDirectory = root.appendingPathComponent("symlink-target", isDirectory: true)
+        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
+        let targetSentinel = targetDirectory.appendingPathComponent("target-sentinel")
+        let targetContents = Data("symlink target remains untouched".utf8)
+        try targetContents.write(to: targetSentinel)
+        let pidDirectory = root.standardizedFileURL
+            .appendingPathComponent("ReleaseRadar-XCTestHost-\(processIdentifier)", isDirectory: true)
+        try FileManager.default.createSymbolicLink(at: pidDirectory, withDestinationURL: targetDirectory)
+        let expectedURL = pidDirectory
+            .appendingPathComponent("release-radar.sqlite", isDirectory: false)
+            .standardizedFileURL
+
+        let preparation = AppLaunchConfiguration.prepareXCTestHost(
+            environment: ["XCTestConfigurationFilePath": "present"],
+            temporaryDirectory: root,
+            processIdentifier: processIdentifier,
+            storeFactory: { _ in
+                XCTFail("The store factory must not run for a pre-existing PID symlink")
+                fatalError("Unexpected store factory invocation")
+            }
+        )
+
+        guard case let .xctestHostUnavailable(databaseURL) = preparation else {
+            return XCTFail("Expected the existing PID symlink to keep the host unavailable")
+        }
+        XCTAssertEqual(databaseURL, expectedURL)
+        XCTAssertEqual(try Data(contentsOf: targetSentinel), targetContents)
+        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: pidDirectory.path), targetDirectory.path)
+    }
+
     @MainActor
     func testSuppressedCaptureLoadLeavesQueuedNotificationUntouched() async throws {
         let directory = FileManager.default.temporaryDirectory
```

