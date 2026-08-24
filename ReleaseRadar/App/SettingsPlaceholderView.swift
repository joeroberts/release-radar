import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        Form {
            Section("Release Radar By Rekon Labs") {
                Text("Settings will appear here as integrations are configured.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 220)
        .scenePadding()
    }
}
