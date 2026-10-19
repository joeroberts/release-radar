import SwiftUI

@main
@MainActor
struct ReleaseRadarPhoneApp: App {
    @StateObject private var store: CompanionReaderStore

    init() {
        _store = StateObject(wrappedValue: CompanionReaderStore())
    }

    var body: some Scene {
        WindowGroup {
            CompanionReaderRootView(store: store)
        }
    }
}
