import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

struct RepositoryPlanReconstructionView: View {
    @Environment(\.dismiss) private var dismiss

    let presentation: RepositoryPlanReconstructionPresentation?
    let retry: () -> Void
    let setSourceSelected: (String, Bool) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch presentation?.stage {
                case nil, .loadingSources:
                    ProgressView("Reading the accepted documentation catalog…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("repository-plan-source-loading")
                case .selectingSources:
                    sourceSelection
                case .failed:
                    failure
                case .preparing, .reviewing, .applying, .outcomeUnknown, .applied:
                    ProgressView("Preparing repository plan review…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(24)
            .frame(minWidth: 540, minHeight: 480)
            .background(RekonTheme.background)
            .navigationTitle("Prepare Project Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("repository-plan-reconstruction")
    }

    private var sourceSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose repository sources")
                .font(RekonTypography.sectionTitle)
            Text("Release Radar will copy only the documents you select into a read-only preparation snapshot. Review lifecycle, authority, and digest before continuing.")
                .foregroundStyle(RekonTheme.secondaryText)
            if presentation?.sources.isEmpty == true {
                ContentUnavailableView(
                    "No accepted sources",
                    systemImage: "doc.badge.questionmark",
                    description: Text("Accept a managed documentation catalog with at least one source, then retry.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(presentation?.sources ?? []) { source in
                            sourceRow(source)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sourceRow(_ source: RepositoryPlanSourceOption) -> some View {
        let selected = presentation?.selectedArtifactIDs.contains(source.artifactID) == true
        return Button {
            setSourceSelected(source.artifactID, !selected)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? RekonTheme.accent : RekonTheme.secondaryText)
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.path)
                        .font(.body.weight(.medium))
                        .foregroundStyle(RekonTheme.primaryText)
                    Text("\(source.lifecycle.rawValue) · \(source.authority.rawValue)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                    Text(source.contentSHA256)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? RekonTheme.accent : RekonTheme.border)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("repository-plan-source-\(source.artifactID)")
        .accessibilityLabel("\(source.path), \(source.lifecycle.rawValue), \(source.authority.rawValue)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var failure: some View {
        ContentUnavailableView {
            Label("Repository sources unavailable", systemImage: "doc.badge.ellipsis")
        } description: {
            Text(presentation?.message ?? "Release Radar could not read the accepted repository sources.")
        } actions: {
            Button("Retry", action: retry)
                .accessibilityIdentifier("repository-plan-source-retry")
        }
    }
}
