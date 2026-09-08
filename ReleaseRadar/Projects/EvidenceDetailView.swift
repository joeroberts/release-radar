import AppKit
import Observation
import SwiftUI
import ReleaseRadarCore
import RekonDesignSystem

struct EvidenceStatusPresentation: Equatable {
    let label: String
    let path: String?
    let locator: String
    let lifecycle: String?
    let authority: String?
    let availability: String
    let recovery: String?

    init(_ evidence: EvidenceProjection, documentationStatus: DocumentationObservationStatus? = nil) {
        label = evidence.label
        path = evidence.path.isEmpty ? nil : evidence.path
        if case .checking = documentationStatus {
            availability = "Checking"
        } else {
            availability = evidence.isAvailable ? "Available" : "Unavailable"
        }
        switch evidence.locator {
        case .filePath:
            locator = "Legacy file path"; lifecycle = nil; authority = nil
            recovery = if case .checking = documentationStatus { nil }
                else { evidence.isAvailable ? nil : "Locate the original file or use exact legacy evidence relocation." }
        case let .managedDocument(id):
            locator = "Managed document · Artifact ID: \(id)"
            switch evidence.managedDocument?.lifecycle {
            case .proposed: lifecycle = "Proposed"
            case .active: lifecycle = "Current"
            case .completed: lifecycle = "Completed · Historical"
            case .superseded: lifecycle = "Superseded · Historical"
            case .archived: lifecycle = "Archived · Historical"
            case nil: lifecycle = nil
            }
            if let document = evidence.managedDocument, let level = document.authority {
                if document.isControlling { authority = "Controlling" + (document.authorityRole.map { " · \($0)" } ?? "") }
                else { authority = "Non-controlling · " + (level == .nonAuthoritative ? "Non-authoritative" : "Supporting") }
            } else { authority = "Authority unavailable" }
            if case .checking = documentationStatus {
                recovery = nil
            } else { switch evidence.managedDocument?.failure {
            case .guidanceUnavailable: recovery = "Managed v2 guidance is missing or invalid. Restore the repository guidance declaration, then reload."
            case .bindingMissing: recovery = "Repository is unaccepted. Activate its documentation binding before using managed evidence."
            case .bindingMismatch: recovery = "Repository binding does not match. Restore the accepted repository or select its relocated folder."
            case .rootNotBound: recovery = "This root is not bound to the project. Select the relocated repository and confirm its binding."
            case .rootUnavailable: recovery = "Repository folder is unavailable. Reauthorize the saved folder or select its relocated location."
            case .staleRoot: recovery = "Folder authorization is stale. Reauthorize the saved folder or select its relocated location."
            case .catalogUnaccepted: recovery = "Catalog changes are pending acceptance. Accept the validated catalog transition before using this evidence."
            case .artifactNotFound: recovery = "Artifact ID is absent from the accepted catalog. Restore its catalog entry or review its retirement."
            case .missingDocument: recovery = "Document is missing. Restore the file at its accepted catalog path, then reload."
            case .checksumInvalid: recovery = "Document checksum is invalid. Restore the verified document and checksum manifest, then reload."
            case .unsafeResolution: recovery = "Document path is unsafe. Restore regular files within the authorized repository, then reload."
            case let .catalogInvalid(code): recovery = "Catalog is invalid (\(code.rawValue)). Repair the catalog and documents, then reload."
            case nil: recovery = evidence.isAvailable ? nil : "Managed resolution is unavailable. Reload this project's evidence."
            } }
        }
    }

    var accessibilityLabel: String {
        [label, locator, path, lifecycle, authority, availability, recovery].compactMap { $0 }.joined(separator: ". ")
    }
}

struct EvidencePreviewRequestKey: Equatable, Sendable {
    let evidenceID: EvidenceID
    let locator: EvidenceLocator
    let observationGeneration: UInt64?
}

@MainActor
@Observable
final class EvidencePreviewCoordinator {
    private(set) var result: EvidencePreview?
    private var generation: UInt64 = 0
    private var key: EvidencePreviewRequestKey?

    func load(key: EvidencePreviewRequestKey, loader: @escaping () async -> EvidencePreview) async {
        generation &+= 1
        let requestGeneration = generation
        self.key = key
        result = nil
        let loaded = await loader()
        guard generation == requestGeneration, self.key == key else { return }
        result = loaded
    }

    func invalidate() {
        generation &+= 1
        key = nil
        result = nil
    }
}

struct EvidenceDetailView: View {
    let evidence: EvidenceProjection
    var documentationStatus: DocumentationObservationStatus? = nil
    var restoreFolderAccess: (() -> Void)? = nil
    var loadPreview: (() async -> EvidencePreview)? = nil
    var initialPreview: EvidencePreview? = nil
    @State private var previewCoordinator = EvidencePreviewCoordinator()
    var body: some View {
        let presentation = EvidenceStatusPresentation(evidence, documentationStatus: documentationStatus)
        VStack(alignment: .leading, spacing: 5) {
            Text(presentation.label).font(.subheadline.weight(.medium))
            Text(presentation.locator).font(.caption).foregroundStyle(.secondary)
            if let path = presentation.path { Text(path).font(.caption.monospaced()).foregroundStyle(.secondary) }
            if let lifecycle = presentation.lifecycle { Text(lifecycle).font(.caption) }
            if let authority = presentation.authority { Text(authority).font(.caption).foregroundStyle(.secondary) }
            Label(presentation.availability, systemImage: presentation.availability == "Checking" ? "arrow.triangle.2.circlepath" : evidence.isAvailable ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(presentation.availability == "Checking" ? Color.secondary : evidence.isAvailable ? Color.green : Color.orange)
            if let recovery = presentation.recovery { Text(recovery).font(.caption).foregroundStyle(.secondary) }
            previewSection
            if canRestoreFolderAccess, let restoreFolderAccess {
                Button("Restore folder access", action: restoreFolderAccess)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("evidence-restore-folder-\(evidence.id.rawValue)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        .accessibilityElement(children: restoreFolderAccess == nil && loadPreview == nil ? .ignore : .contain)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("evidence-\(evidence.id.rawValue)")
        .onChange(of: documentationStatus) { _, _ in
            previewCoordinator.invalidate()
        }
        .onChange(of: evidence) { _, _ in
            previewCoordinator.invalidate()
        }
    }

    private var canRestoreFolderAccess: Bool {
        if case .checking = documentationStatus { return false }
        return switch evidence.managedDocument?.failure {
        case .rootUnavailable, .staleRoot: true
        default: false
        }
    }

    @ViewBuilder private var previewSection: some View {
        if let loadPreview {
        if previewCoordinator.result == nil && initialPreview == nil {
            Button("Preview") {
                Task {
                    await previewCoordinator.load(
                        key: .init(evidenceID: evidence.id, locator: evidence.locator,
                                   observationGeneration: documentationStatus?.generation),
                        loader: loadPreview
                    )
                }
            }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityIdentifier("evidence-preview-\(evidence.id.rawValue)")
            .disabled(isChecking)
        } else if let loadedPreview = previewCoordinator.result ?? initialPreview {
            switch loadedPreview.status {
            case .available:
                if case let .text(text, isTruncated) = loadedPreview.content {
                    ScrollView(.vertical) {
                        Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 260, alignment: .topLeading)
                        .accessibilityIdentifier("evidence-preview-text-\(evidence.id.rawValue)")
                    if isTruncated { Text("Preview truncated at 131,072 characters.").font(.caption).foregroundStyle(.secondary) }
                } else if case let .raster(bytes, _, width, height) = loadedPreview.content, let image = NSImage(data: bytes) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 300)
                        .accessibilityLabel("Evidence image preview, \(width) by \(height) pixels")
                        .accessibilityIdentifier("evidence-preview-image-\(evidence.id.rawValue)")
                }
            case .unsupported: Text("This file format cannot be previewed safely.").font(.caption).foregroundStyle(.secondary)
            case .oversized: Text("This file exceeds the 1 MiB preview limit.").font(.caption).foregroundStyle(.secondary)
            case .rejected: Text("Preview unavailable because the current authorized content could not be verified.").font(.caption).foregroundStyle(.secondary)
            case .inaccessible: Text("Preview unavailable outside authorized project folders. Restore primary folder access or reconnect the exact saved worktree, then retry.").font(.caption).foregroundStyle(.secondary)
            case .missing: Text("The evidence file is missing from its saved location.").font(.caption).foregroundStyle(.secondary)
            case .stale: Text("The saved folder authorization is stale. Restore or reconnect that exact folder, then retry.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Refresh preview") { previewCoordinator.invalidate() }.buttonStyle(RekonSecondaryButtonStyle())
        }
        }
    }

    private var isChecking: Bool {
        if case .checking = documentationStatus { return true }
        return false
    }
}

private extension DocumentationObservationStatus {
    var generation: UInt64 {
        switch self {
        case let .checking(_, generation): generation
        case let .observed(observation): observation.generation
        }
    }
}
