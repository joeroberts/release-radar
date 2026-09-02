import SwiftUI
import ReleaseRadarCore

struct EvidenceStatusPresentation: Equatable {
    let label: String
    let path: String?
    let locator: String
    let lifecycle: String?
    let authority: String?
    let availability: String
    let recovery: String?

    init(_ evidence: EvidenceProjection) {
        label = evidence.label
        path = evidence.path.isEmpty ? nil : evidence.path
        availability = evidence.isAvailable ? "Available" : "Unavailable"
        switch evidence.locator {
        case .filePath:
            locator = "Legacy file path"; lifecycle = nil; authority = nil
            recovery = evidence.isAvailable ? nil : "Locate the original file or use exact legacy evidence relocation."
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
            switch evidence.managedDocument?.failure {
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
            }
        }
    }

    var accessibilityLabel: String {
        [label, locator, path, lifecycle, authority, availability, recovery].compactMap { $0 }.joined(separator: ". ")
    }
}

struct EvidenceDetailView: View {
    let evidence: EvidenceProjection
    var body: some View {
        let presentation = EvidenceStatusPresentation(evidence)
        VStack(alignment: .leading, spacing: 5) {
            Text(presentation.label).font(.subheadline.weight(.medium))
            Text(presentation.locator).font(.caption).foregroundStyle(.secondary)
            if let path = presentation.path { Text(path).font(.caption.monospaced()).foregroundStyle(.secondary) }
            if let lifecycle = presentation.lifecycle { Text(lifecycle).font(.caption) }
            if let authority = presentation.authority { Text(authority).font(.caption).foregroundStyle(.secondary) }
            Label(presentation.availability, systemImage: evidence.isAvailable ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.caption).foregroundStyle(evidence.isAvailable ? Color.green : Color.orange)
            if let recovery = presentation.recovery { Text(recovery).font(.caption).foregroundStyle(.secondary) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("evidence-\(evidence.id.rawValue)")
    }
}
