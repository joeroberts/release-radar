import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

private struct RepositoryPlanOriginalEvidenceChoice {
    let label: String
    let reference: RepositoryPlanSourceReference
}

private struct RepositoryPlanObligationDescendantEntry {
    let obligationID: String
    let reference: RepositoryPlanPhaseCompletionReference
}

struct RepositoryPlanReconstructionView: View {
    @Environment(\.dismiss) private var dismiss

    let presentation: RepositoryPlanReconstructionPresentation?
    let retry: () -> Void
    let setSourceSelected: (String, Bool) -> Void
    let startPreparation: () -> Void
    let refreshPreparation: () -> Void
    let cancelPreparation: () -> Void
    let reconcilePreparation: () -> Void
    let restartPreparation: () -> Void
    let setCorrection: (RepositoryPlanReconstructionSubject, String, Data) -> Void
    let setExclusion: (RepositoryPlanReconstructionSubject, String) -> Void
    let setTerminalEvidence: ([RepositoryPlanTerminalEvidence]) -> Void
    var setMapping: (RepositoryPlanReconstructionSubject, String?) -> Void = { _, _ in }
    var removeExclusion: (RepositoryPlanReconstructionSubject) -> Void = { _ in }
    var addOriginalEvidence: (RepositoryPlanSourceReference) -> Void = { _ in }
    var beginFreshPreparation: () -> Void = {}
    var retryAppliedRefresh: () -> Void = {}
    let setAuthorityConfirmed: (Bool) -> Void
    let save: (String) -> Void
    let approve: () -> Void
    let apply: () -> Void
    let recoverApply: () -> Void
    let openPlan: () -> Void
    let openBoard: () -> Void
    let openHistory: () -> Void

    @State private var selectedSubject: RepositoryPlanReconstructionSubject?
    @State private var correctionField = ""
    @State private var correctionValue = ""
    @State private var mappingDestination = ""
    @State private var exclusionReason = ""
    @State private var evidenceState = RepositoryPlanTerminalState.accepted.rawValue
    @State private var originalEvidenceSelection = ""
    @State private var phaseMembershipComplete = false
    @State private var phaseTickets = ""
    @State private var phaseGoals = ""
    @State private var phaseObligations = ""
    @State private var phaseObligationDescendants = ""
    @State private var phaseDeliveredBy = ""
    @State private var saveRationale = ""

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
                case .starting:
                    ProgressView("Capturing the authorized source snapshot…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("repository-plan-preparation-starting")
                case .failed:
                    failure
                case .reviewLoadFailed:
                    reviewLoadFailure
                case .preparing:
                    preparationStatus
                case .outcomeUnknown:
                    presentation?.review == nil ? AnyView(outcomeUnknown) : AnyView(applyOutcomeUnknown)
                case .reviewing:
                    reviewContent
                case .applying:
                    ProgressView("Applying the exact approved repository plan…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .applied:
                    appliedContent
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
        .onChange(of: presentation?.review?.comparisons) { _, comparisons in
            reconcileSelection(comparisons ?? [])
        }
        .onAppear {
            reconcileSelection(presentation?.review?.comparisons ?? [])
        }
    }

    private var reviewContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sourceSummary
                    reviewedPlanSection
                    comparisonSection
                    if geometry.size.width >= 860 {
                        HStack(alignment: .top, spacing: 18) {
                            editSection.frame(maxWidth: .infinity, alignment: .topLeading)
                            ownerActionSection.frame(width: 330, alignment: .topLeading)
                        }
                    } else {
                        editSection
                        ownerActionSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityIdentifier("repository-plan-review")
    }

    private var sourceSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Captured repository source")
                .font(RekonTypography.sectionTitle)
            if let source = presentation?.review?.source {
                Text("Project \(source.projectID.rawValue) · root \(source.rootID)")
                Text("Registration \(source.registration.registrationID) · generation \(source.registration.requestGeneration)")
                Text("Projection \(source.projectionID.uuidString.lowercased()) · revision \(source.projectionRevision)")
                Text("Catalog \(source.acceptedCatalogVersion) · \(source.acceptedCatalogDigest)")
                Text("Projection SHA-256 \(source.projectionSHA256)")
                ForEach(source.capturedSourceManifest.sources, id: \.artifactID) { item in
                    Text("\(item.path) · \(item.lifecycle.rawValue) · \(item.authority.rawValue) · \(item.contentSHA256)")
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("repository-plan-source-summary")
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review every proposed record")
                .font(RekonTypography.sectionTitle)
            ForEach(presentation?.review?.comparisons ?? [], id: \.subject) { comparison in
                Button {
                    select(comparison)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(comparison.kind.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(comparison.disposition.rawValue.capitalized)
                                .foregroundStyle(dispositionColor(comparison.disposition))
                        }
                        Text(comparison.sourceID)
                            .font(.system(.body, design: .monospaced))
                        if let parent = comparison.parentSourceID {
                            Text("Parent: \(parent)")
                        }
                        Text("Destination: \(comparison.destinationID ?? "Not selected")")
                        Text("Sources: \(sourceReferences(for: comparison))")
                        let changed = changedFields(for: comparison.subject)
                        Text("Changed fields: \(changed.isEmpty ? "None" : changed.joined(separator: ", "))")
                    }
                    .font(.caption)
                    .foregroundStyle(RekonTheme.primaryText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selectedComparison?.subject == comparison.subject
                            ? RekonTheme.accent.opacity(0.12) : RekonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "repository-plan-comparison-\(comparison.kind.rawValue)-\(comparison.sourceID)"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("repository-plan-comparisons")
    }

    private var reviewedPlanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Captured and reviewed plan content")
                .font(RekonTypography.sectionTitle)
            if let original = presentation?.review?.originalProjection,
               let reviewed = presentation?.review?.reviewedProjection {
                ForEach(original.phases, id: \.sourceID) { phase in
                    Text("Captured phase · \(phase.sourceID) · \(phase.name) · \(phase.lifecycle.rawValue) · \(phase.authorityClass.rawValue)")
                }
                ForEach(original.tickets, id: \.sourceID) { ticket in
                    Text("Captured ticket · \(ticket.sourceID) · \(ticket.outcome) · phase \(ticket.phaseSourceID ?? "None") · lane \(ticket.lane?.rawValue ?? "None")")
                    ForEach(ticket.taskPlan?.tasks ?? [], id: \.sourceID) { task in
                        Text("Captured task · \(task.sourceID) · \(task.label) · \(task.title) · order \(task.sortOrder)")
                    }
                }
                if reviewed != original {
                    RekonSeparator()
                    Text("Reviewed projection differs from the captured projection.")
                        .font(.caption.weight(.semibold))
                    ForEach(reviewed.phases, id: \.sourceID) { phase in
                        Text("Reviewed phase · \(phase.sourceID) · \(phase.name) · \(phase.lifecycle.rawValue) · \(phase.authorityClass.rawValue)")
                    }
                    ForEach(reviewed.tickets, id: \.sourceID) { ticket in
                        Text("Reviewed ticket · \(ticket.sourceID) · \(ticket.outcome) · phase \(ticket.phaseSourceID ?? "None") · lane \(ticket.lane?.rawValue ?? "None")")
                        ForEach(ticket.taskPlan?.tasks ?? [], id: \.sourceID) { task in
                            Text("Reviewed task · \(task.sourceID) · \(task.label) · \(task.title) · order \(task.sortOrder)")
                        }
                    }
                }
            }
        }
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("repository-plan-content")
    }

    private var editSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review and resolve the selected record")
                .font(RekonTypography.sectionTitle)
            if let comparison = selectedComparison {
                Text(comparison.sourceID)
                    .font(.system(.body, design: .monospaced))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Captured record").font(.caption.weight(.semibold))
                    Text(recordText(for: comparison.subject, in: presentation?.review?.originalProjection))
                    Text("Reviewed record").font(.caption.weight(.semibold))
                    Text(recordText(for: comparison.subject, in: presentation?.review?.reviewedProjection))
                    Text("Current destination").font(.caption.weight(.semibold))
                    Text(destinationText(for: comparison.subject))
                    Text("Classification: \(comparison.disposition.rawValue)")
                    Text("Changed fields: \(changedFieldsLabel(for: comparison.subject))")
                }
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .accessibilityIdentifier("repository-plan-comparison-details")

                RekonSeparator()
                TextField("Exact destination identity", text: $mappingDestination)
                    .accessibilityIdentifier("repository-plan-mapping-destination")
                HStack {
                    Button("Use exact destination") {
                        setMapping(comparison.subject, mappingDestination)
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(mappingDestination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("repository-plan-mapping-apply")
                    Button("Clear mapping") {
                        setMapping(comparison.subject, nil)
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(!hasExplicitMapping(comparison.subject))
                    .accessibilityIdentifier("repository-plan-mapping-clear")
                }

                RekonSeparator()
                Picker("Correction field", selection: $correctionField) {
                    ForEach(correctionFields(for: comparison), id: \.self) { field in
                        Text(field).tag(field)
                    }
                }
                .accessibilityIdentifier("repository-plan-correction-field")
                TextField("Reviewed value", text: $correctionValue)
                    .accessibilityIdentifier("repository-plan-correction-value")
                Button("Apply correction") {
                    guard !correctionField.isEmpty,
                          let bytes = correctionBytes(
                              comparison: comparison,
                              field: correctionField,
                              value: correctionValue
                          ) else { return }
                    setCorrection(comparison.subject, correctionField, bytes)
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(correctionField.isEmpty || correctionValue.isEmpty)
                .accessibilityIdentifier("repository-plan-correction-apply")

                RekonSeparator()
                TextField("Reason for explicit exclusion", text: $exclusionReason)
                    .accessibilityIdentifier("repository-plan-exclusion-reason")
                Button("Exclude this record") {
                    setExclusion(comparison.subject, exclusionReason)
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(exclusionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("repository-plan-exclude")
                Button("Restore this record") {
                    removeExclusion(comparison.subject)
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(!hasExclusion(comparison.subject))
                .accessibilityIdentifier("repository-plan-restore")

                RekonSeparator()
                if !originalEvidenceReferences.isEmpty {
                    Picker("Captured original evidence", selection: $originalEvidenceSelection) {
                        ForEach(originalEvidenceReferences, id: \.label) { item in
                            Text(item.label).tag(item.label)
                        }
                    }
                    .accessibilityIdentifier("repository-plan-original-evidence")
                    Button("Import captured evidence") {
                        guard let reference = originalEvidenceReferences.first(where: {
                            $0.label == originalEvidenceSelection
                        })?.reference else { return }
                        addOriginalEvidence(reference)
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(originalEvidenceSelection.isEmpty)
                } else {
                    Text("No captured state-evidence references are available.")
                        .font(.caption)
                        .accessibilityIdentifier("repository-plan-original-evidence")
                }

                Picker("Owner-attested terminal state", selection: $evidenceState) {
                    ForEach(terminalStates, id: \.rawValue) { state in
                        Text(state.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .tag(state.rawValue)
                    }
                }
                .accessibilityIdentifier("repository-plan-evidence-state")
                Group {
                    Toggle("Phase membership is complete", isOn: $phaseMembershipComplete)
                        .accessibilityIdentifier("repository-plan-phase-membership")
                    TextField("Tickets: source ID,lane[,projection,pointer | document,document ID,locator]", text: $phaseTickets, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("repository-plan-phase-tickets")
                    TextField("Goals: source ID,required,lifecycle,remaining debt", text: $phaseGoals, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("repository-plan-phase-goals")
                    TextField("Obligations: source ID,disposition", text: $phaseObligations, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("repository-plan-phase-obligations")
                    TextField("Obligation descendants: obligation ID,ticket|goal,phase ID,source ID[,proof…]", text: $phaseObligationDescendants, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("repository-plan-phase-obligation-descendants")
                    TextField("Delivered by: ticket|goal,phase ID,source ID[,proof…]", text: $phaseDeliveredBy, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("repository-plan-phase-delivered-by")
                }
                .disabled(
                    comparison.kind != .phase
                        || evidenceState != RepositoryPlanTerminalState.completed.rawValue
                )
                HStack {
                    Button("Add owner attestation") {
                        addOwnerAttestation(for: comparison)
                    }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(stateSubject(for: comparison) == nil)
                    .accessibilityIdentifier("repository-plan-evidence-add")
                }
                if let evidence = presentation?.review?.terminalEvidence, !evidence.isEmpty {
                    ForEach(Array(evidence.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top) {
                            Text(evidenceLabel(item))
                                .font(.caption)
                            Text(evidenceFacts(item))
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button("Remove") {
                                removeEvidence(at: index)
                            }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .accessibilityIdentifier("repository-plan-evidence-remove")
                        }
                    }
                } else {
                    Button("Remove evidence") {}
                        .disabled(true)
                        .accessibilityIdentifier("repository-plan-evidence-remove")
                }
                Text("Captured evidence remains read-only. Each owner attestation is retained independently and binds the exact approval decision shown below.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
        .padding(12)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var ownerActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Owner decision")
                .font(RekonTypography.sectionTitle)
            blockersSection
            remainingSetupSection
            Toggle(
                "I verified the source authority, corrections, exclusions, and evidence",
                isOn: Binding(
                    get: { presentation?.review?.authorityConfirmed == true },
                    set: { setAuthorityConfirmed($0) }
                )
            )
            .accessibilityIdentifier("repository-plan-authority-confirmed")
            TextField("Save rationale", text: $saveRationale, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityIdentifier("repository-plan-save-rationale")
            Button("Save reviewed version") { save(saveRationale) }
                .buttonStyle(RekonPrimaryButtonStyle())
                .disabled(!canSave)
                .accessibilityIdentifier("repository-plan-save")
            HStack {
                Button("Approve") { approve() }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(!canApprove)
                    .accessibilityIdentifier("repository-plan-approve")
                Button("Apply") { apply() }
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .disabled(!canApply)
                    .accessibilityIdentifier("repository-plan-apply")
            }
            if presentation?.review?.savedReadback != nil {
                Button("Start over from updated sources", action: beginFreshPreparation)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(
                        presentation?.review?.isSaving == true
                            || presentation?.review?.isUpdating == true
                            || presentation?.review?.isDeciding == true
                    )
                    .accessibilityIdentifier("repository-plan-prepare-fresh")
            }
            if let message = presentation?.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(RekonTheme.warning)
            }
        }
        .padding(12)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var blockersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Blockers").font(.caption.weight(.semibold))
            if presentation?.review?.blockers.isEmpty != false {
                Text("No blockers")
            } else {
                ForEach(presentation?.review?.blockers ?? []) { blocker in
                    Text("• \(blocker.message)")
                }
            }
        }
        .font(.caption)
        .accessibilityIdentifier("repository-plan-blockers")
    }

    private var remainingSetupSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remaining setup").font(.caption.weight(.semibold))
            if let readback = presentation?.review?.savedReadback {
                if readback.remainingSetup.isEmpty {
                    Text("Repository-wide readiness is unavailable in this reconstruction result. Inspect Project Plan and Phase Board for current setup and legacy-unassessed work.")
                } else {
                    ForEach(readback.remainingSetup, id: \.self) { Text("• \($0)") }
                }
            } else {
                Text("Save the reviewed reconstruction to calculate its reported setup items.")
            }
        }
        .font(.caption)
        .accessibilityIdentifier("repository-plan-remaining-setup")
    }

    private var applyOutcomeUnknown: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceSummary
                Label("Apply outcome unknown", systemImage: "questionmark.diamond")
                    .font(RekonTypography.sectionTitle)
                Text(presentation?.message ?? "Reconcile the exact recorded Apply attempt before continuing.")
                remainingSetupSection
                Button("Reconcile exact Apply attempt", action: recoverApply)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .accessibilityIdentifier("repository-plan-apply-recover")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var appliedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceSummary
                Label("Repository plan applied", systemImage: "checkmark.circle.fill")
                    .font(RekonTypography.sectionTitle)
                if let readback = presentation?.review?.savedReadback {
                    Text("Proposal \(readback.proposalID.rawValue) · version \(readback.version.version)")
                    Text("Decision \(readback.version.decision?.id ?? "Unavailable")")
                    Text("Application \(readback.version.application?.id ?? "Unavailable")")
                    Text("Provenance records: \(readback.provenance.count)")
                }
                if let message = presentation?.message, !message.isEmpty {
                    Text(message)
                        .foregroundStyle(
                            message.localizedCaseInsensitiveContains("failed")
                                ? RekonTheme.warning : RekonTheme.secondaryText
                        )
                }
                remainingSetupSection
                HStack {
                    Button("Project Plan", action: openPlan)
                        .accessibilityIdentifier("repository-plan-open-plan")
                    Button("Phase Board", action: openBoard)
                        .accessibilityIdentifier("repository-plan-open-board")
                    Button("History", action: openHistory)
                        .accessibilityIdentifier("repository-plan-open-history")
                }
                Button("Prepare again from updated sources", action: beginFreshPreparation)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("repository-plan-prepare-fresh")
                Button("Reload project views", action: retryAppliedRefresh)
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .accessibilityIdentifier("repository-plan-refresh-applied")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var sourceSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose repository sources")
                .font(RekonTypography.sectionTitle)
            Text("Release Radar will copy only the documents you select into a read-only preparation snapshot. Review lifecycle, authority, and digest before continuing.")
                .foregroundStyle(RekonTheme.secondaryText)
            if let target = presentation?.target {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Send selected contents to")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RekonTheme.secondaryText)
                    Text(target.destinationLabel)
                        .font(.body.weight(.medium))
                    Text("\(target.model) · \(target.effort) reasoning · context \(target.codexContextID.uuidString.lowercased())")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(RekonTheme.secondaryText)
                        .textSelection(.enabled)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("repository-plan-preparation-target")
            }
            if let message = presentation?.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(RekonTheme.warning)
            }
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
            HStack {
                Spacer()
                Button("Prepare selected sources", action: startPreparation)
                    .buttonStyle(RekonPrimaryButtonStyle())
                    .disabled(presentation?.selectedArtifactIDs.isEmpty != false)
                    .accessibilityIdentifier("repository-plan-prepare-selected")
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

    private var reviewLoadFailure: some View {
        ContentUnavailableView {
            Label("Prepared review unavailable", systemImage: "doc.badge.ellipsis")
        } description: {
            Text(presentation?.message ?? "The captured draft remains safe, but its review could not be loaded.")
        } actions: {
            HStack {
                Button("Retry exact review", action: retry)
                    .accessibilityIdentifier("repository-plan-review-retry")
                Button("Start with fresh disclosure", action: restartPreparation)
                    .accessibilityIdentifier("repository-plan-review-restart")
            }
        }
    }

    private var preparationStatus: some View {
        let state = presentation?.preparation?.state
        return VStack(alignment: .leading, spacing: 16) {
            Label(preparationTitle(state), systemImage: preparationImage(state))
                .font(RekonTypography.sectionTitle)
            Text(preparationDetail(state))
                .foregroundStyle(RekonTheme.secondaryText)
            if let message = presentation?.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(RekonTheme.warning)
            }
            HStack {
                if state == .queued || state == .running || state == .awaitingResolution {
                    Button("Cancel preparation", action: cancelPreparation)
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-cancel")
                }
                Spacer()
                if state == .failed || state == .cancelled {
                    Button("Prepare again", action: startPreparation)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-again")
                } else if state != .readyForReview {
                    Button("Refresh status", action: refreshPreparation)
                        .buttonStyle(RekonPrimaryButtonStyle())
                        .accessibilityIdentifier("repository-plan-prepare-refresh")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("repository-plan-preparation-status")
    }

    private var outcomeUnknown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Preparation outcome unknown", systemImage: "questionmark.diamond")
                .font(RekonTypography.sectionTitle)
            Text("Release Radar will not start another preparation. Reconcile the recorded attempt before continuing.")
                .foregroundStyle(RekonTheme.secondaryText)
            if let message = presentation?.message, !message.isEmpty {
                Text(message).foregroundStyle(RekonTheme.warning)
            }
            Button("End uncertain attempt and reconcile", action: reconcilePreparation)
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("repository-plan-prepare-reconcile")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("repository-plan-preparation-unknown")
    }

    private func preparationTitle(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .queued: "Preparation queued"
        case .running: "Preparing project plan"
        case .awaitingResolution: "Preparation needs resolution"
        case .readyForReview: "Prepared plan ready for review"
        case .failed: "Preparation failed"
        case .cancelled: "Preparation cancelled"
        case .outcomeUnknown: "Preparation outcome unknown"
        case nil: "Preparation status unavailable"
        }
    }

    private func preparationImage(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .readyForReview: "checkmark.circle"
        case .failed: "xmark.octagon"
        case .cancelled: "stop.circle"
        case .outcomeUnknown: "questionmark.diamond"
        case .queued, .running, .awaitingResolution, nil: "doc.badge.clock"
        }
    }

    private func preparationDetail(_ state: RepositoryPlanPreparationState?) -> String {
        switch state {
        case .queued: "The exact source snapshot is recorded and waiting for the selected Codex context."
        case .running: "The isolated read-only preparation is producing a proposed plan."
        case .awaitingResolution: "Resolve the recorded preparation condition before review can continue."
        case .readyForReview: "Review every proposed phase, ticket, dependency, task, source reference, and comparison before deciding."
        case .failed: "No plan change was applied. You may start a fresh attempt from the selected sources."
        case .cancelled: "The attempt ended without applying a plan change. You may start a fresh attempt."
        case .outcomeUnknown: "Do not start another attempt until this exact identity is reconciled."
        case nil: "Refresh the recorded attempt before continuing."
        }
    }

    private var selectedComparison: RepositoryPlanReconstructionComparison? {
        let comparisons = presentation?.review?.comparisons ?? []
        return comparisons.first { $0.subject == selectedSubject } ?? comparisons.first
    }

    private var terminalStates: [RepositoryPlanTerminalState] {
        [.accepted, .completed, .superseded, .unassessed, .upcoming, .inDelivery]
    }

    private var canSave: Bool {
        guard let review = presentation?.review else { return false }
        return review.authorityConfirmed
            && !review.isUpdating
            && !review.isSaving
            && !review.isDeciding
            && !saveRationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canApprove: Bool {
        guard let review = presentation?.review,
              let saved = review.savedReadback else { return false }
        return review.authorityConfirmed
            && !review.isUpdating
            && !review.isSaving
            && !review.isDeciding
            && review.blockers.isEmpty
            && saved.version.decision == nil
    }

    private var canApply: Bool {
        guard let review = presentation?.review,
              let saved = review.savedReadback else { return false }
        return review.authorityConfirmed
            && review.blockers.isEmpty
            && saved.version.decision?.disposition == .approved
            && saved.version.application == nil
    }

    private func reconcileSelection(_ comparisons: [RepositoryPlanReconstructionComparison]) {
        guard comparisons.contains(where: { $0.subject == selectedSubject }) else {
            if let first = comparisons.first {
                select(first)
            } else {
                selectedSubject = nil
            }
            return
        }
    }

    private func select(_ comparison: RepositoryPlanReconstructionComparison) {
        selectedSubject = comparison.subject
        let fields = correctionFields(for: comparison)
        correctionField = fields.first ?? ""
        correctionValue = ""
        mappingDestination = presentation?.review?.explicitMappings.first {
            $0.subject == comparison.subject
        }?.destinationID ?? comparison.destinationID ?? ""
        exclusionReason = presentation?.review?.exclusions.first {
            $0.subject == comparison.subject
        }?.reason ?? ""
        if !originalEvidenceReferences.contains(where: { $0.label == originalEvidenceSelection }) {
            originalEvidenceSelection = originalEvidenceReferences.first?.label ?? ""
        }
    }

    private func correctionFields(
        for comparison: RepositoryPlanReconstructionComparison
    ) -> [String] {
        switch comparison.kind {
        case .phase: ["name", "lifecycle", "authorityClass"]
        case .ticket: ["outcome", "phaseSourceID", "lane", "authorityClass"]
        case .task: ["title", "label", "sortOrder", "completion", "lifecycle", "authorityClass"]
        case .phaseDependency, .ticketDependency: ["subjectSourceID", "dependsOnSourceID"]
        }
    }

    private func sourceReferences(
        for comparison: RepositoryPlanReconstructionComparison
    ) -> String {
        guard let projection = presentation?.review?.reviewedProjection else { return "Unavailable" }
        let references: [RepositoryPlanSourceReference]
        switch comparison.kind {
        case .phase:
            references = projection.phases.first { $0.sourceID == comparison.sourceID }?.sourceRefs ?? []
        case .ticket:
            references = projection.tickets.first { $0.sourceID == comparison.sourceID }?.sourceRefs ?? []
        case .task:
            references = projection.tickets.first { $0.sourceID == comparison.parentSourceID }?
                .taskPlan?.tasks.first { $0.sourceID == comparison.sourceID }?.sourceRefs ?? []
        case .phaseDependency:
            references = projection.phaseDependencies.first { $0.sourceID == comparison.sourceID }?.sourceRefs ?? []
        case .ticketDependency:
            references = projection.ticketDependencies.first { $0.sourceID == comparison.sourceID }?.sourceRefs ?? []
        }
        return references.map(sourceReferenceLabel).joined(separator: ", ")
    }

    private func recordText(
        for subject: RepositoryPlanReconstructionSubject,
        in projection: RepositoryPlanProjection?
    ) -> String {
        guard let projection else { return "Unavailable" }
        switch subject.kind {
        case .phase:
            return encodedRecord(projection.phases.first { $0.sourceID == subject.sourceID })
        case .ticket:
            return encodedRecord(projection.tickets.first { $0.sourceID == subject.sourceID })
        case .task:
            return encodedRecord(projection.tickets.first { $0.sourceID == subject.parentSourceID }?
                .taskPlan?.tasks.first { $0.sourceID == subject.sourceID })
        case .phaseDependency:
            return encodedRecord(projection.phaseDependencies.first { $0.sourceID == subject.sourceID })
        case .ticketDependency:
            return encodedRecord(projection.ticketDependencies.first { $0.sourceID == subject.sourceID })
        }
    }

    private func encodedRecord<T: Encodable>(_ record: T?) -> String {
        guard let record else { return "Unavailable" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(record),
              let text = String(data: data, encoding: .utf8) else { return "Unavailable" }
        return text
    }

    private func changedFields(
        for subject: RepositoryPlanReconstructionSubject
    ) -> [String] {
        (presentation?.review?.corrections ?? [])
            .filter { $0.subject == subject }
            .map(\.field)
            .sorted { Data($0.utf8).lexicographicallyPrecedes(Data($1.utf8)) }
    }

    private func destinationText(
        for subject: RepositoryPlanReconstructionSubject
    ) -> String {
        guard let snapshot = presentation?.review?.destinationSnapshots.first(where: {
            $0.subject == subject
        }) else { return "No current destination record" }
        guard let object = try? JSONSerialization.jsonObject(with: snapshot.fields),
              JSONSerialization.isValidJSONObject(object),
              let formatted = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ), let text = String(data: formatted, encoding: .utf8) else {
            return "Destination \(snapshot.destinationID) · fields unavailable"
        }
        return "Destination \(snapshot.destinationID)\n\(text)"
    }

    private func changedFieldsLabel(
        for subject: RepositoryPlanReconstructionSubject
    ) -> String {
        let fields = changedFields(for: subject)
        return fields.isEmpty ? "None" : fields.joined(separator: ", ")
    }

    private func hasExplicitMapping(_ subject: RepositoryPlanReconstructionSubject) -> Bool {
        presentation?.review?.explicitMappings.contains { $0.subject == subject } == true
    }

    private func hasExclusion(_ subject: RepositoryPlanReconstructionSubject) -> Bool {
        presentation?.review?.exclusions.contains { $0.subject == subject } == true
    }

    private func correctionBytes(
        comparison: RepositoryPlanReconstructionComparison,
        field: String,
        value: String
    ) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if field == "sortOrder" {
            guard let integer = Int(trimmed) else { return nil }
            return try? JSONEncoder().encode(integer)
        }
        if comparison.kind == .ticket,
           field == "phaseSourceID" || field == "lane",
           trimmed.isEmpty || trimmed.lowercased() == "null" {
            return Data("null".utf8)
        }
        guard !trimmed.isEmpty else { return nil }
        return try? JSONEncoder().encode(trimmed)
    }

    private var originalEvidenceReferences: [RepositoryPlanOriginalEvidenceChoice] {
        guard let projection = presentation?.review?.originalProjection else { return [] }
        var references = projection.phases.flatMap(\.stateEvidence)
        references.append(contentsOf: projection.tickets.flatMap(\.stateEvidence))
        references.append(contentsOf: projection.tickets.flatMap {
            $0.taskPlan?.tasks.flatMap(\.stateEvidence) ?? []
        })
        var unique: [RepositoryPlanSourceReference] = []
        for reference in references
            where isCapturedDocumentReference(reference) && !unique.contains(reference) {
            unique.append(reference)
        }
        return unique.map {
            RepositoryPlanOriginalEvidenceChoice(
                label: sourceReferenceLabel($0),
                reference: $0
            )
        }
    }

    private func isCapturedDocumentReference(_ reference: RepositoryPlanSourceReference) -> Bool {
        if case .document = reference { return true }
        return false
    }

    private func sourceReferenceLabel(_ reference: RepositoryPlanSourceReference) -> String {
        switch reference {
        case let .projection(pointer): pointer
        case let .document(documentID, locator): "\(documentID):\(locator)"
        }
    }

    private func dispositionColor(
        _ disposition: RepositoryPlanReconstructionComparisonDisposition
    ) -> Color {
        switch disposition {
        case .new, .unchanged: RekonTheme.success
        case .conflicting, .blocked: RekonTheme.warning
        case .excluded: RekonTheme.secondaryText
        }
    }

    private func stateSubject(
        for comparison: RepositoryPlanReconstructionComparison
    ) -> RepositoryPlanStateSubject? {
        guard let projection = presentation?.review?.reviewedProjection else { return nil }
        switch comparison.kind {
        case .phase:
            guard let phase = projection.phases.first(where: { $0.sourceID == comparison.sourceID }) else {
                return nil
            }
            return .phase(.init(sourceID: phase.sourceID, name: phase.name))
        case .ticket:
            guard let ticket = projection.tickets.first(where: { $0.sourceID == comparison.sourceID }) else {
                return nil
            }
            return .ticket(.init(
                sourceID: ticket.sourceID,
                outcome: ticket.outcome,
                phaseSourceID: ticket.phaseSourceID,
                taskPlan: ticket.taskPlan.map { plan in
                    .init(
                        sourceRevision: plan.sourceRevision,
                        tasks: plan.tasks.map {
                            .init(
                                sourceID: $0.sourceID,
                                label: $0.label,
                                title: $0.title,
                                sortOrder: $0.sortOrder,
                                completion: $0.completion,
                                lifecycle: $0.lifecycle
                            )
                        }
                    )
                }
            ))
        case .task:
            guard let parent = comparison.parentSourceID,
                  let task = projection.tickets.first(where: { $0.sourceID == parent })?
                    .taskPlan?.tasks.first(where: { $0.sourceID == comparison.sourceID }) else {
                return nil
            }
            return .task(.init(
                ticketSourceID: parent,
                sourceID: task.sourceID,
                label: task.label,
                title: task.title,
                sortOrder: task.sortOrder
            ))
        case .phaseDependency, .ticketDependency:
            return nil
        }
    }

    private func addOwnerAttestation(
        for comparison: RepositoryPlanReconstructionComparison
    ) {
        guard let review = presentation?.review,
              let subject = stateSubject(for: comparison),
              let state = RepositoryPlanTerminalState(rawValue: evidenceState) else { return }
        let phaseCompletion: RepositoryPlanPhaseCompletionCertificate?
        if case .phase = subject, state == .completed {
            guard let certificate = phaseCompletionCertificate() else { return }
            phaseCompletion = certificate
        } else {
            phaseCompletion = nil
        }
        var evidence = review.terminalEvidence
        evidence.append(.ownerAttestation(.init(
            id: "attestation-\(UUID().uuidString.lowercased())",
            subject: subject,
            state: state,
            phaseCompletion: phaseCompletion,
            decisionID: review.decisionID,
            attestedAt: Date(),
            originalOccurredAt: nil,
            originalActorID: nil
        )))
        setTerminalEvidence(evidence)
    }

    private func removeEvidence(at index: Int) {
        guard var evidence = presentation?.review?.terminalEvidence,
              evidence.indices.contains(index) else { return }
        evidence.remove(at: index)
        setTerminalEvidence(evidence)
    }

    private func evidenceLabel(_ evidence: RepositoryPlanTerminalEvidence) -> String {
        switch evidence {
        case let .original(sourceRef, record):
            return "Original · \(record.state.rawValue) · \(sourceReferenceLabel(sourceRef)) · \(record.recordID)"
        case let .ownerAttestation(attestation):
            return "Owner attestation · \(attestation.state.rawValue) · \(attestation.id)"
        }
    }

    private func evidenceFacts(_ evidence: RepositoryPlanTerminalEvidence) -> String {
        let certificate: RepositoryPlanPhaseCompletionCertificate?
        switch evidence {
        case let .original(_, record): certificate = record.phaseCompletion
        case let .ownerAttestation(attestation): certificate = attestation.phaseCompletion
        }
        guard let certificate else { return "No phase-completion certificate" }
        let obligations = certificate.obligations.map { obligation in
            let descendants = obligation.descendants.map(completionReferenceLabel).joined(separator: "; ")
            return "\(obligation.sourceObligationID)=\(obligation.disposition.rawValue)[\(descendants)]"
        }.joined(separator: ", ")
        return "membershipComplete=\(certificate.membershipComplete); tickets=\(certificate.tickets.count); goals=\(certificate.goals.count); deliveredBy=\(certificate.deliveredBy.map(completionReferenceLabel).joined(separator: "; ")); obligations=\(obligations)"
    }

    private func phaseCompletionCertificate() -> RepositoryPlanPhaseCompletionCertificate? {
        guard let descendantEntries: [RepositoryPlanObligationDescendantEntry] = parseLines(
            phaseObligationDescendants,
            transform: { columns in
                guard columns.count >= 4,
                      let reference = completionReference(columns, offset: 1) else { return nil }
                return .init(obligationID: columns[0], reference: reference)
            }
        ) else { return nil }
        let descendants = Dictionary(grouping: descendantEntries, by: \.obligationID)
        guard let tickets: [RepositoryPlanPhaseCompletionTicket] = parseLines(phaseTickets, transform: { columns in
            guard columns.count >= 2,
                  let lane = TicketLane(rawValue: columns[1]),
                  let proof = proofReference(columns, offset: 2) else { return nil }
            return RepositoryPlanPhaseCompletionTicket(
                sourceTicketID: columns[0],
                lane: lane,
                acceptanceProof: proof
            )
        }), let goals: [RepositoryPlanPhaseCompletionGoal] = parseLines(phaseGoals, transform: { columns in
            guard columns.count == 4,
                  let required = Bool(columns[1]),
                  let lifecycle = RepositoryPlanPhaseCompletionGoal.Lifecycle(rawValue: columns[2]),
                  let remainingDebt = Bool(columns[3]) else { return nil }
            return RepositoryPlanPhaseCompletionGoal(
                sourceGoalID: columns[0],
                required: required,
                lifecycle: lifecycle,
                remainingDebt: remainingDebt
            )
        }), let obligations: [RepositoryPlanPhaseCompletionObligation] = parseLines(phaseObligations, transform: { columns in
            guard columns.count == 2,
                  let disposition = RepositoryPlanPhaseCompletionObligation.Disposition(
                      rawValue: columns[1]
                  ) else { return nil }
            return RepositoryPlanPhaseCompletionObligation(
                sourceObligationID: columns[0],
                disposition: disposition,
                descendants: descendants[columns[0]]?.map(\.reference) ?? []
            )
        }), let deliveredBy: [RepositoryPlanPhaseCompletionReference] = parseLines(phaseDeliveredBy, transform: { columns in
            completionReference(columns, offset: 0)
        }) else { return nil }
        return .init(
            membershipComplete: phaseMembershipComplete,
            tickets: tickets,
            goals: goals,
            obligations: obligations,
            deliveredBy: deliveredBy
        )
    }

    private func parseLines<T>(
        _ value: String,
        transform: ([String]) -> T?
    ) -> [T]? {
        let lines = value.split(whereSeparator: { $0.isNewline }).map(String.init)
        var result: [T] = []
        for line in lines {
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard columns.allSatisfy({ !$0.isEmpty }), let item = transform(columns) else {
                return nil
            }
            result.append(item)
        }
        return result
    }

    private func completionReference(
        _ columns: [String],
        offset: Int
    ) -> RepositoryPlanPhaseCompletionReference? {
        guard columns.count >= offset + 3,
              let kind = RepositoryPlanPhaseCompletionReference.Kind(
                rawValue: columns[offset]
              ), let proof = proofReference(columns, offset: offset + 3) else { return nil }
        return .init(
            kind: kind,
            phaseSourceID: columns[offset + 1],
            sourceID: columns[offset + 2],
            proofRef: proof
        )
    }

    private func proofReference(
        _ columns: [String],
        offset: Int
    ) -> RepositoryPlanSourceReference?? {
        guard columns.count >= offset else { return nil }
        if columns.count == offset { return .some(nil) }
        switch columns[offset] {
        case "projection":
            guard columns.count == offset + 2 else { return nil }
            return .some(.projection(pointer: columns[offset + 1]))
        case "document":
            guard columns.count == offset + 3 else { return nil }
            return .some(.document(
                documentID: columns[offset + 1],
                locator: columns[offset + 2]
            ))
        default:
            return nil
        }
    }

    private func completionReferenceLabel(
        _ reference: RepositoryPlanPhaseCompletionReference
    ) -> String {
        let proof = reference.proofRef.map(sourceReferenceLabel) ?? "no proof"
        return "\(reference.kind.rawValue):\(reference.phaseSourceID):\(reference.sourceID):\(proof)"
    }
}
