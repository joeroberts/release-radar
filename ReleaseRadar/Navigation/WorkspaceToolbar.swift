import SwiftUI
import RekonDesignSystem

enum WorkspaceShellLayout {
    static let forcedCompactWidth: CGFloat = 940

    static func isForcedCompact(width: CGFloat) -> Bool {
        width < forcedCompactWidth
    }

    static func isCompact(width: CGFloat, userCollapsed: Bool) -> Bool {
        userCollapsed || isForcedCompact(width: width)
    }
}

struct WorkspaceToolbarSaveState: Equatable {
    var name = ""
    var failure: String?

    mutating func reset() {
        name = ""
        failure = nil
    }

    mutating func beginAttempt() {
        failure = nil
    }

    mutating func resolve(_ outcome: WorkspaceSearchSaveOutcome) -> Bool {
        switch outcome {
        case .saved:
            failure = nil
            return true
        case let .failed(message):
            failure = message
            return false
        }
    }
}

struct WorkspaceToolbar: View {
    @Bindable var model: AppModel
    let isCompact: Bool
    let isSidebarForcedCompact: Bool
    let toggleSidebar: () -> Void

    @State private var isSearchFocused = false
    @State private var isSavePresented = false
    @State private var saveState = WorkspaceToolbarSaveState()

    var body: some View {
        RekonToolbar {
            HStack(spacing: RekonTheme.Spacing.micro) {
                sidebarToggle
                NavigationHistoryControls(model: model)
            }
        } center: {
            searchField.frame(minWidth: isCompact ? 180 : 280, maxWidth: isCompact ? 320 : 440)
        } trailing: {
            HStack(spacing: RekonTheme.Spacing.micro) {
                saveButton
                iconButton("Help", systemImage: "questionmark.circle", identifier: "workspace-toolbar-help") {
                    Task { await model.navigate(to: .help) }
                }
                iconButton("Settings", systemImage: "gearshape", identifier: "workspace-toolbar-settings") {
                    Task { await model.navigate(to: .settings) }
                }
                notificationsButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace toolbar")
        .accessibilityIdentifier("workspace-toolbar")
        .task(id: model.navigationFocus) {
            await Task.yield()
            if model.navigationFocus == .workspaceSearchField {
                isSearchFocused = true
            }
        }
    }

    private var searchField: some View {
        RekonSearchField(
            text: Binding(
                get: { model.workspaceSearchDraft },
                set: { model.setWorkspaceSearchText($0) }
            ),
            accessibilityLabel: "Search workspace",
            externalFocus: $isSearchFocused,
            accessibilityIdentifier: "workspace-search-field",
            iconAccessibilityIdentifier: "workspace-search-run",
            clearButtonAccessibilityIdentifier: "workspace-search-clear",
            prompt: "Search workspace…",
            onSubmit: submitSearch
        )
        .disabled(searchIsDisabled)
        .help(searchHelp)
    }

    private var sidebarToggle: some View {
        let label = isCompact ? "Expand navigation sidebar" : "Collapse navigation sidebar"
        return iconButton(
            label,
            systemImage: "sidebar.left",
            identifier: "workspace-toolbar-sidebar-toggle",
            isEnabled: !isSidebarForcedCompact,
            help: isSidebarForcedCompact ? "Make the window wider to expand the navigation sidebar." : label,
            action: toggleSidebar
        )
    }

    @ViewBuilder private var saveButton: some View {
        if isCompact {
            iconButton("Save query", systemImage: "bookmark", identifier: "workspace-search-save") {
                presentSave()
            }
            .disabled(saveIsDisabled)
            .help(saveHelp)
            .popover(isPresented: $isSavePresented) { savePopover }
        } else {
            Button("Save query") { presentSave() }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(saveIsDisabled)
                .help(saveHelp)
                .accessibilityIdentifier("workspace-search-save")
                .popover(isPresented: $isSavePresented) { savePopover }
        }
    }

    private var notificationsButton: some View {
        Button {
            Task { await model.navigate(to: .notifications) }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .accessibilityHidden(true)
                if model.notificationCount > 0 {
                    Circle()
                        .fill(RekonTheme.danger)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(RekonBorderlessIconButtonStyle())
        .accessibilityLabel(notificationLabel)
        .accessibilityIdentifier("workspace-toolbar-notifications")
        .help(notificationLabel)
    }

    private var savePopover: some View {
        WorkspaceSaveQueryPopover(
            name: $saveState.name,
            failure: saveState.failure,
            onCancel: dismissSave,
            onSave: saveQuery
        )
    }

    private var saveIsDisabled: Bool {
        model.workspaceSearchPreferenceIsUnsupported || model.workspaceSearchNeedsScopeReselection
    }

    private var searchIsDisabled: Bool {
        model.workspaceSearchIsLoading || saveIsDisabled
    }

    private var searchHelp: String {
        if model.workspaceSearchPreferenceIsUnsupported {
            return "Reset the unsupported working search or open a supported saved query before searching."
        }
        if model.workspaceSearchNeedsScopeReselection {
            return "Choose the exact current project scope on Search before searching."
        }
        if model.workspaceSearchIsLoading {
            return "Search is running."
        }
        return "Search workspace"
    }

    private var saveHelp: String {
        if model.workspaceSearchPreferenceIsUnsupported {
            return "Reset the unsupported working search or open a supported saved query before saving."
        }
        if model.workspaceSearchNeedsScopeReselection {
            return "Choose the exact current project scope on Search before saving."
        }
        return "Save the visible query and options"
    }

    private var notificationLabel: String {
        guard model.notificationCount > 0 else { return "Notifications" }
        return "Notifications, \(model.notificationCount) items"
    }

    private func submitSearch() {
        Task { await model.runWorkspaceSearch() }
    }

    private func presentSave() {
        saveState.reset()
        isSavePresented = true
    }

    private func dismissSave() {
        saveState.reset()
        isSavePresented = false
        isSearchFocused = true
    }

    private func saveQuery() {
        let name = saveState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        saveState.beginAttempt()
        Task {
            if saveState.resolve(await model.saveCurrentWorkspaceSearch(name: name)) {
                dismissSave()
            }
        }
    }

    private func iconButton(
        _ label: String,
        systemImage: String,
        identifier: String,
        isEnabled: Bool = true,
        help: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .buttonStyle(RekonBorderlessIconButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .help(help ?? label)
    }
}

struct WorkspaceSaveQueryPopover: View {
    @Binding var name: String
    let failure: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save query")
                .font(RekonTypography.compactTitle)
            Text("Save the visible query with its current scope, record types and sort.")
                .font(RekonTypography.metadata)
                .foregroundStyle(RekonTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Query name", text: $name)
                .textFieldStyle(RekonQuietTextFieldStyle())
                .focused($isNameFocused)
                .onSubmit(onSave)
                .accessibilityIdentifier("workspace-search-save-name")
            if let failure {
                RekonCallout(tone: .danger, systemImage: "exclamationmark.triangle") {
                    Text("Query not saved").font(.headline)
                    Text(failure)
                    Text("Correct the name or restore storage access, then try again.")
                }
                .accessibilityIdentifier("workspace-search-save-error")
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("workspace-search-save-confirm")
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(RekonTheme.backgroundRaised)
        .onAppear { isNameFocused = true }
        .onChange(of: failure) { _, newFailure in
            if newFailure != nil { isNameFocused = true }
        }
        .onExitCommand(perform: onCancel)
    }
}

struct ReleaseRadarLogoMark: View {
    private let violet = Color(red: 0.50, green: 0.36, blue: 0.98)
    private let cyan = Color(red: 0.28, green: 0.95, blue: 1.00)

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.04, to: 0.93)
                .stroke(violet, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [10, 6]))
                .rotationEffect(.degrees(-92))

            RadarBeamShape()
                .fill(LinearGradient(colors: [violet.opacity(0.2), cyan.opacity(0.58)], startPoint: .bottomLeading, endPoint: .topTrailing))

            logoTile(x: 0.22, y: 0.23, color: violet)
            logoTile(x: 0.76, y: 0.22, color: cyan)
            logoTile(x: 0.82, y: 0.66, color: violet)
            logoTile(x: 0.50, y: 0.84, color: violet)
            logoTile(x: 0.16, y: 0.66, color: violet)

            Circle().fill(RekonTheme.backgroundRaised).frame(width: 10, height: 10)
            Circle().stroke(violet, lineWidth: 3).frame(width: 10, height: 10)
        }
        .frame(width: 58, height: 58)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Release Radar")
        .accessibilityIdentifier("sidebar-logo")
    }

    private func logoTile(x: CGFloat, y: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3.5)
            .fill(color.opacity(color == cyan ? 0.85 : 0.24))
            .overlay(RoundedRectangle(cornerRadius: 3.5).stroke(color, lineWidth: 2.2))
            .frame(width: 12, height: 12)
            .position(x: 58 * x, y: 58 * y)
    }
}

private struct RadarBeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.28))
        path.closeSubpath()
        return path
    }
}
