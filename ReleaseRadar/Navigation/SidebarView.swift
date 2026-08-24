import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    private var sidebarWidth: CGFloat {
        model.isSidebarCompact ? 96 : 220
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Section {
                    ForEach(AppRoute.primaryRoutes.filter { $0 != .settings }, id: \.self) { route in
                        routeLabel(route)
                            .tag(route)
                    }

                    Button {
                        openSettings()
                    } label: {
                        routeLabel(.settings)
                    }
                    .buttonStyle(.plain)
                }

                Section("Current Project") {
                    ForEach(AppRoute.projectRoutes(for: model.currentProjectID), id: \.self) { route in
                        routeLabel(route)
                            .tag(route)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: sidebarWidth,
                ideal: sidebarWidth,
                max: sidebarWidth
            )
            .toolbar {
                ToolbarItem {
                    Button {
                        model.isSidebarCompact.toggle()
                    } label: {
                        Label(
                            model.isSidebarCompact ? "Expand Sidebar" : "Collapse Sidebar",
                            systemImage: model.isSidebarCompact
                                ? "sidebar.left"
                                : "sidebar.left"
                        )
                    }
                    .help(model.isSidebarCompact ? "Expand Sidebar" : "Collapse Sidebar")
                }
            }
        } detail: {
            DetailPlaceholderView(route: model.selection)
        }
    }

    @ViewBuilder
    private func routeLabel(_ route: AppRoute) -> some View {
        if model.isSidebarCompact {
            Image(systemName: route.systemImage)
                .font(.system(size: 16, weight: .light))
                .frame(maxWidth: .infinity)
                .accessibilityLabel(route.title)
        } else {
            Label(route.title, systemImage: route.systemImage)
                .symbolRenderingMode(.monochrome)
                .fontWeight(.light)
                .accessibilityLabel(route.title)
        }
    }
}

private struct DetailPlaceholderView: View {
    let route: AppRoute

    var body: some View {
        if route == .projects {
            OnboardingView()
        } else {
        ContentUnavailableView(
            route.title,
            systemImage: route.systemImage,
            description: Text("This section is ready for its delivery slice.")
        )
        .navigationTitle(route.title)
        }
    }
}
