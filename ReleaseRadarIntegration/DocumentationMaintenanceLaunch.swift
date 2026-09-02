import Foundation
import ReleaseRadarCore

enum DocumentationMaintenanceMode: String { case readOnly = "read-only", commands }

enum DocumentationMaintenanceLaunch: Equatable {
    case application
    case invalid
    case maintenance(mode: DocumentationMaintenanceMode, databaseURL: URL)

    static func parse(arguments: [String], environment: [String: String]) -> Self {
        guard environment["XCTestConfigurationFilePath"] == nil else { return .application }
        let flags = arguments.filter { $0.hasPrefix("--documentation-maintenance") }
        guard !flags.isEmpty else { return .application }
        let modePrefix = "--documentation-maintenance="
        let storePrefix = "--documentation-maintenance-store="
        let modes = flags.filter { $0.hasPrefix(modePrefix) }
        let stores = flags.filter { $0.hasPrefix(storePrefix) }
        guard modes.count == 1, stores.count <= 1, modes.count + stores.count == flags.count,
              let mode = DocumentationMaintenanceMode(rawValue: String(modes[0].dropFirst(modePrefix.count))) else { return .invalid }
        let databaseURL: URL
        if let store = stores.first {
            let path = String(store.dropFirst(storePrefix.count))
            guard path.hasPrefix("/"), !path.utf8.contains(0), path.utf8.count <= 4096,
                  path == URL(fileURLWithPath: path).standardizedFileURL.path else { return .invalid }
            databaseURL = URL(fileURLWithPath: path)
        } else { databaseURL = DeliveryStore.existingApplicationSupportDatabaseURL() }
        return .maintenance(mode: mode, databaseURL: databaseURL)
    }
}
