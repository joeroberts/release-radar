import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum ProjectPlanLayout {
    static func usesStackedInspector(forWidth width: CGFloat) -> Bool { width < 1_100 }
}

struct DeliveryGoalEditorSnapshot: Equatable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID
    let planRevision: Int64
    let phaseLifecycle: PhaseLifecycle
    let goalLifecycle: DeliveryGoalLifecycle?
    let draft: DeliveryGoalDraft
}

enum DeliveryGoalEditorLoadOutcome: Equatable, Sendable {
    case loaded(DeliveryGoalEditorSnapshot)
    case failed(AgentCommandError)
}

struct DeliveryGoalDraftSaveOutcome: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case confirmed(savedRevision: Int64, auditEventID: AuditEventID, readback: DeliveryGoalEditorSnapshot)
        case savedNeedsReload(savedRevision: Int64, auditEventID: AuditEventID)
        case rejected(error: AgentCommandError, refreshedEditor: DeliveryGoalEditorSnapshot?)
        case unconfirmed(error: AgentCommandError)
    }

    let attemptID: UUID
    let status: Status
}

struct DeliveryGoalDraftSaveRecovery: Equatable, Sendable {
    let attemptID: UUID
    let draft: DeliveryGoalDraft
    let expectedRevision: Int64
    let error: AgentCommandError
}

struct DeliveryGoalEditorTarget: Equatable, Sendable {
    let phaseID: PhaseID
    let goalID: DeliveryGoalID?
}

struct DeliveryGoalAssignmentEditorSnapshot: Equatable, Sendable { let projectID: ProjectID; let phaseID: PhaseID; let planRevision: Int64; let phaseLifecycle: PhaseLifecycle; let tickets: [TicketCardProjection]; let goals: [DeliveryGoalSummaryProjection]; let assignments: [DeliveryGoalAssignment] }
enum DeliveryGoalAssignmentEditorLoadOutcome: Equatable, Sendable { case loaded(DeliveryGoalAssignmentEditorSnapshot); case failed(AgentCommandError) }
struct DeliveryGoalAssignmentEdit: Equatable, Sendable { let ticketID: TicketID; let goalID: DeliveryGoalID? }
struct DeliveryGoalAssignmentSaveOutcome: Equatable, Sendable { enum Status: Equatable, Sendable { case confirmed(savedRevision: Int64, auditEventID: AuditEventID, readback: DeliveryGoalAssignmentEditorSnapshot); case savedNeedsReload(savedRevision: Int64, auditEventID: AuditEventID); case rejected(error: AgentCommandError, refreshedEditor: DeliveryGoalAssignmentEditorSnapshot?); case unconfirmed(error: AgentCommandError) }; let attemptID: UUID; let status: Status }
struct DeliveryGoalAssignmentSaveRecovery: Equatable, Sendable { let attemptID: UUID; let edits: [DeliveryGoalAssignmentEdit]; let expectedRevision: Int64; let error: AgentCommandError }

struct PhasePlanFinalizationReadback: Equatable, Sendable {
    let projectID: ProjectID
    let phaseID: PhaseID
    let revision: Int64
    let readyRevision: Int64?
    let state: PhasePlanState
}

struct PhasePlanFinalizationOutcome: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case confirmed(savedRevision: Int64, auditEventID: AuditEventID, readback: PhasePlanFinalizationReadback)
        case savedNeedsReload(savedRevision: Int64, auditEventID: AuditEventID)
        case rejected(error: AgentCommandError, readback: PhasePlanFinalizationReadback?)
        case unconfirmed(error: AgentCommandError)
    }

    let attemptID: UUID
    let status: Status
}

struct PhasePlanFinalizationRecovery: Equatable, Sendable {
    let attemptID: UUID
    let expectedRevision: Int64
    let error: AgentCommandError
}

func phasePlanFinalizationErrorMessage(_ error: AgentCommandError) -> String {
    switch error {
    case let .phasePlanIncomplete(failure):
        if failure.incompleteGoalIDs.isEmpty,
           failure.unassignedTicketIDs.isEmpty,
           failure.conflictingTicketIDs.isEmpty {
            return "This draft has no actionable Delivery Goal. Create one, then finalize the phase plan."
        }
        return "This draft is incomplete. Complete the linked Delivery Goals, assign the linked tickets, and resolve the linked conflicts before finalizing."
    case .staleProjectRegistration, .planRevisionConflict:
        "This phase plan changed. Refresh the project plan, then finalize the current revision."
    case .appUnavailable:
        "Release Radar is temporarily unavailable. The exact finalization attempt is retained; reconcile it before retrying."
    case .outcomeUnknown:
        "Release Radar could not confirm finalization. Reconcile the same saved attempt before trying again."
    case .completedPhaseReadOnly:
        "This completed phase cannot be finalized."
    default:
        "The phase plan could not be finalized. Refresh the project plan and try again."
    }
}
func deliveryGoalAssignmentDraftErrorMessage(_ error: AgentCommandError) -> String {
    switch error {
    case let .goalNotActionable(goalID):
        "Delivery Goal \(goalID.rawValue) is immutable and cannot receive ticket assignments."
    case .staleProjectRegistration, .planRevisionConflict:
        "This phase plan changed. Keep your assignment edits, refresh the plan, then save again."
    case .appUnavailable:
        "Release Radar is temporarily unavailable. Your assignment edits are still here; save again when it is available."
    case .outcomeUnknown:
        "Release Radar could not confirm that save. Reconcile the same saved attempt before making another assignment change."
    default:
        deliveryGoalDraftErrorMessage(error)
    }
}

func deliveryGoalDraftErrorMessage(_ error: AgentCommandError) -> String {
    switch error {
    case let .invalidPlanMutation(message): message
    case .planRevisionConflict:
        "This phase plan changed. Refresh the plan, keep your edits, then save again."
    case let .completedPhaseReadOnly(phaseID):
        "Phase \(phaseID.rawValue) is completed and cannot be changed."
    case let .goalNotFound(goalID):
        "Delivery Goal \(goalID.rawValue) is no longer available. Refresh the plan."
    case let .goalNotActionable(goalID):
        "Delivery Goal \(goalID.rawValue) is immutable and cannot be edited."
    case .staleProjectRegistration:
        "This project changed. Refresh it before saving the Delivery Goal."
    case .appUnavailable:
        "Release Radar is temporarily unavailable. Your edits are still here; save again when it is available."
    case .outcomeUnknown:
        "Release Radar could not confirm that save. Reconcile the same saved attempt before creating another goal."
    case .unauthorizedProjectRoot:
        "Release Radar cannot access this project. Reauthorize it, then try again."
    default:
        "The Delivery Goal could not be saved. Refresh the plan and try again."
    }
}

struct ProjectPlanView: View {
    let plan: ProjectPlanProjection
    @Binding var selectedTicketID: TicketID
    let openAllPhases: () -> Void
    let openPhase: (PhaseID) -> Void
    var documentationStatus: DocumentationObservationStatus? = nil
    var loadEvidencePreview: ((EvidenceID) async -> EvidencePreview)? = nil
    var loadTicketReferences: ((TicketID) async -> ReferenceLoadResult<TicketReferenceSet>)? = nil
    var loadTicketDeliveryEvidence: ((TicketID) async -> ReferenceLoadResult<TicketDeliveryEvidence>)? = nil
    var openReferenceSource: ((TicketID, String, Int64) -> Void)? = nil
    var decideProposal: ((PlanChangeProposalID, Int64, String, PlanChangeDecisionDisposition) async -> AgentCommandResult)? = nil
    var applyProposal: ((PlanChangeProposalID, Int64, String, String) async -> AgentCommandResult)? = nil
    var refreshProposal: ((PlanChangeProposalID, Int64, String, [PlanChangeOperation]) async -> AgentCommandResult)? = nil
    var transitionPhaseLifecycle: ((PhaseID, Int64, PhaseLifecycleAction, String?, String) async -> AgentCommandResult)? = nil
    var reloadPhaseLifecycle: (() async -> Void)? = nil
    var loadDeliveryGoalEditor: ((PhaseID, DeliveryGoalID?) async -> DeliveryGoalEditorLoadOutcome)? = nil
    var saveDeliveryGoalDraft: ((PhaseID, Int64, DeliveryGoalDraft) async -> DeliveryGoalDraftSaveOutcome)? = nil
    var reconcileDeliveryGoalDraftSave: ((UUID) async -> DeliveryGoalDraftSaveOutcome)? = nil
    var deliveryGoalDraftSaveRecovery: ((PhaseID) -> DeliveryGoalDraftSaveRecovery?)? = nil
    var requestedDeliveryGoalEditor: DeliveryGoalEditorTarget? = nil
    var loadDeliveryGoalAssignmentEditor: ((PhaseID) async -> DeliveryGoalAssignmentEditorLoadOutcome)? = nil
    var saveDeliveryGoalAssignmentDraft: ((PhaseID, Int64, [DeliveryGoalAssignmentEdit]) async -> DeliveryGoalAssignmentSaveOutcome)? = nil
    var reconcileDeliveryGoalAssignmentDraftSave: ((UUID) async -> DeliveryGoalAssignmentSaveOutcome)? = nil
    var deliveryGoalAssignmentDraftSaveRecovery: ((PhaseID) -> DeliveryGoalAssignmentSaveRecovery?)? = nil
    var finalizePhasePlan: ((PhaseID, Int64) async -> PhasePlanFinalizationOutcome)? = nil
    var reconcilePhasePlanFinalization: ((UUID) async -> PhasePlanFinalizationOutcome)? = nil
    var phasePlanFinalizationRecovery: ((PhaseID) -> PhasePlanFinalizationRecovery?)? = nil
    var repositoryPlanReconstruction: RepositoryPlanReconstructionPresentation? = nil
    var openRepositoryPlanReconstruction: (() -> Void)? = nil
    var setRepositoryPlanSourceSelected: ((String, Bool) -> Void)? = nil
    var startRepositoryPlanPreparation: (() -> Void)? = nil
    var refreshRepositoryPlanPreparation: (() -> Void)? = nil
    var cancelRepositoryPlanPreparation: (() -> Void)? = nil
    var reconcileRepositoryPlanPreparation: (() -> Void)? = nil
    var restartRepositoryPlanPreparation: (() -> Void)? = nil
    var setRepositoryPlanCorrection: ((RepositoryPlanReconstructionSubject, String, Data) -> Void)? = nil
    var setRepositoryPlanExclusion: ((RepositoryPlanReconstructionSubject, String) -> Void)? = nil
    var setRepositoryPlanTerminalEvidence: (([RepositoryPlanTerminalEvidence]) -> Void)? = nil
    var setRepositoryPlanMapping: ((RepositoryPlanReconstructionSubject, String?) -> Void)? = nil
    var removeRepositoryPlanExclusion: ((RepositoryPlanReconstructionSubject) -> Void)? = nil
    var addRepositoryPlanOriginalEvidence: ((RepositoryPlanSourceReference) -> Void)? = nil
    var beginFreshRepositoryPlanPreparation: (() -> Void)? = nil
    var retryRepositoryPlanProjectionRefresh: (() -> Void)? = nil
    var setRepositoryPlanAuthorityConfirmed: ((Bool) -> Void)? = nil
    var saveRepositoryPlanReconstruction: ((String) -> Void)? = nil
    var approveRepositoryPlanReconstruction: (() -> Void)? = nil
    var applyRepositoryPlanReconstruction: (() -> Void)? = nil
    var recoverRepositoryPlanReconstructionApply: (() -> Void)? = nil
    var openRepositoryPlanBoard: (() -> Void)? = nil
    var openRepositoryPlanHistory: (() -> Void)? = nil
    var referenceQueryContextIdentity: String? = nil
    var isReferenceQueryReady = false
    var requestedFocus: NavigationFocus? = nil
    var focusChanged: (NavigationFocus?) -> Void = { _ in }
    @State private var selectedProposalID: Data?
    @State private var selectedProposalVersion: Int64?
    @State private var proposalActionFailure: FailureStatePresentation?
    @State private var proposalNeedsRefresh = false
    @State private var isPerformingProposalAction = false
    @FocusState private var focusedProposal: ProposalFocus?
    @AccessibilityFocusState private var accessibilityFocusedProposal: ProposalFocus?
    @FocusState private var focusedTicketID: TicketID?
    @AccessibilityFocusState private var accessibilityFocusedTicketID: TicketID?
    @State private var showsRepositoryPlanReconstruction = false
    @State private var showsDeliveryGoalEditor = false
    @State private var deliveryGoalEditor: DeliveryGoalEditorSnapshot?
    @State private var deliveryGoalTitle = ""
    @State private var deliveryGoalOutcome = ""
    @State private var deliveryGoalCriteria = ""
    @State private var deliveryGoalEditorMessage: String?
    @State private var isSavingDeliveryGoal = false
    @State private var showsDeliveryGoalAssignmentEditor = false
    @State private var deliveryGoalAssignmentEditor: DeliveryGoalAssignmentEditorSnapshot?
    @State private var deliveryGoalAssignmentEditorPhaseID: PhaseID?
    @State private var deliveryGoalAssignmentSelections: [TicketID: String] = [:]
    @State private var deliveryGoalAssignmentEditorMessage: String?
    @State private var isSavingDeliveryGoalAssignments = false
    @State private var phasePlanFinalizationPhaseID: PhaseID?
    @State private var phasePlanFinalizationMessage: String?
    @State private var phasePlanFinalizationFailure: PhasePlanReadinessFailure?
    @State private var phasePlanFinalizationNeedsReload = false
    @State private var isFinalizingPhasePlan = false

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if !ProjectPlanLayout.usesStackedInspector(forWidth: geometry.size.width) {
                            HStack(alignment: .top, spacing: 18) {
                                planContent.frame(maxWidth: .infinity, alignment: .topLeading)
                                RekonSeparator(.vertical)
                                inspector.frame(width: 340, alignment: .top).frame(minHeight: 500, alignment: .top)
                            }
                        } else {
                            planContent
                            RekonSeparator()
                            inspector.frame(minHeight: 420, alignment: .top)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: navigationScrollTargetID(forWidth: geometry.size.width), initial: true) { _, targetID in
                    guard let targetID else { return }
                    proxy.scrollTo(targetID, anchor: .center)
                    applyRequestedFocus()
                }
            }
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan")
        .onChange(of: plan.proposals) { _, _ in reconcileProposalSelection() }
        .onChange(of: requestedFocus) { _, _ in applyRequestedFocus() }
        .task {
            reconcileProposalSelection()
            applyRequestedFocus()
            if let target = requestedDeliveryGoalEditor {
                openDeliveryGoalEditor(target.phaseID, goalID: target.goalID)
            }
        }
        .sheet(isPresented: $showsRepositoryPlanReconstruction) {
            RepositoryPlanReconstructionView(
                presentation: repositoryPlanReconstruction,
                retry: { openRepositoryPlanReconstruction?() },
                setSourceSelected: { artifactID, selected in
                    setRepositoryPlanSourceSelected?(artifactID, selected)
                },
                startPreparation: { startRepositoryPlanPreparation?() },
                refreshPreparation: { refreshRepositoryPlanPreparation?() },
                cancelPreparation: { cancelRepositoryPlanPreparation?() },
                reconcilePreparation: { reconcileRepositoryPlanPreparation?() },
                restartPreparation: { restartRepositoryPlanPreparation?() },
                setCorrection: { subject, field, value in
                    setRepositoryPlanCorrection?(subject, field, value)
                },
                setExclusion: { subject, reason in
                    setRepositoryPlanExclusion?(subject, reason)
                },
                setTerminalEvidence: { evidence in
                    setRepositoryPlanTerminalEvidence?(evidence)
                },
                setMapping: { subject, destinationID in
                    setRepositoryPlanMapping?(subject, destinationID)
                },
                removeExclusion: { subject in
                    removeRepositoryPlanExclusion?(subject)
                },
                addOriginalEvidence: { sourceRef in
                    addRepositoryPlanOriginalEvidence?(sourceRef)
                },
                beginFreshPreparation: {
                    beginFreshRepositoryPlanPreparation?()
                },
                retryAppliedRefresh: {
                    retryRepositoryPlanProjectionRefresh?()
                },
                setAuthorityConfirmed: { confirmed in
                    setRepositoryPlanAuthorityConfirmed?(confirmed)
                },
                save: { rationale in saveRepositoryPlanReconstruction?(rationale) },
                approve: { approveRepositoryPlanReconstruction?() },
                apply: { applyRepositoryPlanReconstruction?() },
                recoverApply: { recoverRepositoryPlanReconstructionApply?() },
                openPlan: { showsRepositoryPlanReconstruction = false },
                openBoard: {
                    showsRepositoryPlanReconstruction = false
                    openRepositoryPlanBoard?()
                },
                openHistory: {
                    showsRepositoryPlanReconstruction = false
                    openRepositoryPlanHistory?()
                }
            )
        }
        .sheet(isPresented: $showsDeliveryGoalEditor) { deliveryGoalEditorSheet }
        .sheet(isPresented: $showsDeliveryGoalAssignmentEditor) { deliveryGoalAssignmentEditorSheet }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) { heading; Spacer(); headerActions }
            VStack(alignment: .leading, spacing: 12) { heading; headerActions }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            if openRepositoryPlanReconstruction != nil {
                Button("Prepare from repository") {
                    showsRepositoryPlanReconstruction = true
                    openRepositoryPlanReconstruction?()
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("prepare-repository-plan")
            }
            allPhasesButton
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.project.name)
                .font(RekonTypography.metadata.weight(.medium))
                .foregroundStyle(RekonTheme.secondaryText)
            Text("Project Plan")
                .font(RekonTypography.screenTitle)
            Text("\(plan.recordedTicketCount) recorded tickets · \(plan.phases.count) phases · \(plan.unassignedTickets.count) not placed")
                .font(.subheadline)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("project-plan-counts")
        }
    }

    private var allPhasesButton: some View {
        Button("Open all-phase board", action: openAllPhases)
            .buttonStyle(RekonPrimaryButtonStyle())
            .accessibilityIdentifier("open-all-phase-board")
    }

    private var planContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Plan-change proposals", count: plan.proposals.count)
            Text("Review a saved version before deciding. Approval never changes the plan; Apply is a separate deliberate action.")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            if plan.proposals.isEmpty {
                Text("No saved proposals")
                    .foregroundStyle(RekonTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(plan.proposals) { proposal in
                        proposalRow(proposal)
                    }
                }
            }

            RekonSeparator()
            sectionHeading("Recorded phases", count: plan.phases.count)
            if plan.phases.isEmpty {
                ContentUnavailableView("No phases recorded", systemImage: "list.bullet.rectangle")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(plan.phases) { phase in phaseCard(phase) }
                }
            }
            sectionHeading("Retired originals", count: plan.retiredTickets.count)
            Text("Retired tickets remain read-only with their disposition, rationale, and successor lineage. They do not appear on active boards.")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            if plan.retiredTickets.isEmpty {
                Text("No retired tickets")
                    .foregroundStyle(RekonTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(plan.retiredTickets) { ticket in
                        retiredTicketRow(ticket)
                    }
                }
            }
            sectionHeading("Not placed", count: plan.unassignedTickets.count)
            Text("Planning content is retained here. Execution and completion begin only after first placement into a phase Backlog.")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            if plan.unassignedTickets.isEmpty {
                Text("No unassigned recorded tickets")
                    .foregroundStyle(RekonTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(plan.unassignedTickets) { card in
                        TicketCardView(card: card, presentation: .fullOutcome,
                                       isSelected: selectedTicketID == card.id) {
                            selectedProposalID = nil
                            selectedProposalVersion = nil
                            selectedTicketID = card.id
                            focusChanged(.ticket(card.id))
                        }
                        .focusable()
                        .focused($focusedTicketID, equals: card.id)
                        .accessibilityFocused($accessibilityFocusedTicketID, equals: card.id)
                        .id("project-plan-ticket-scroll-\(card.id.rawValue)")
                        .onAppear {
                            guard requestedFocus == .ticket(card.id) else { return }
                            focusedTicketID = card.id
                            accessibilityFocusedTicketID = card.id
                        }
                    }
                }
            }
        }
    }

    private func proposalRow(_ proposal: PlanChangeProposalRecord) -> some View {
        let current = proposal.versions.first { $0.version == proposal.currentVersion }
        let proposalKey = Data(proposal.id.rawValue.utf8)
        let selected = selectedProposalID == proposalKey
        return Button {
            selectedProposalID = proposalKey
            selectedProposalVersion = proposal.currentVersion
            proposalActionFailure = nil
            proposalNeedsRefresh = false
            focusedProposal = .proposal(proposalKey)
            accessibilityFocusedProposal = .proposal(proposalKey)
            focusChanged(.planChangeProposal(
                proposalID: proposal.id.rawValue,
                version: proposal.currentVersion,
                ticketID: nil
            ))
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "doc.badge.clock")
                    .foregroundStyle(RekonTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(proposal.id.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text("Version \(proposal.currentVersion) · \(proposalState(current))")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                    if let rationale = current?.rationale {
                        Text(rationale)
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(selected ? RekonTheme.accent : RekonTheme.secondaryText)
            }
            .padding(12)
            .background(selected ? RekonTheme.elevatedSurface : RekonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? RekonTheme.accent : RekonTheme.border, lineWidth: RekonBorder.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedProposal, equals: .proposal(proposalKey))
        .accessibilityFocused($accessibilityFocusedProposal, equals: .proposal(proposalKey))
        .accessibilityIdentifier("plan-change-proposal-\(proposal.id.rawValue)")
    }

    private func phaseCard(_ phase: ProjectPlanPhaseProjection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.name).font(.headline)
                    Text(phase.id.rawValue).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open board") { openPhase(phase.id) }
                    .accessibilityLabel("Open \(phase.name) phase board")
                if phase.lifecycle.lifecycle != .completed, loadDeliveryGoalEditor != nil {
                    Button("Create Delivery Goal") { openDeliveryGoalEditor(phase.id, goalID: nil) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("create-delivery-goal-\(phase.id.rawValue)")
                }
                if phase.lifecycle.lifecycle != .completed, loadDeliveryGoalAssignmentEditor != nil {
                    Button("Edit assignments") { openDeliveryGoalAssignmentEditor(phase.id) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("edit-delivery-goal-assignments-\(phase.id.rawValue)")
                }
                if let finalizePhasePlan {
                    let eligible = phase.lifecycle.lifecycle != .completed && phase.readiness.state == .draft
                    Button("Finalize plan") { beginPhasePlanFinalization(phase) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .disabled(!eligible || isFinalizingPhasePlan)
                        .accessibilityLabel(eligible
                            ? "Finalize \(phase.name) plan at revision \(phase.readiness.revision)"
                            : "Finalize \(phase.name) plan unavailable: \(phase.lifecycle.lifecycle == .completed ? "the phase is completed" : "the plan is already Ready")")
                        .accessibilityIdentifier("finalize-phase-plan-\(phase.id.rawValue)")
                }
            }
            Text(readinessSummary(phase.readiness))
                .font(.subheadline)
                .foregroundStyle(phase.readiness.state == .ready ? RekonTheme.success : RekonTheme.warning)
            Text("Lifecycle: \(phase.lifecycle.lifecycle.displayName) · revision \(phase.lifecycle.revision)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RekonTheme.primaryText)
                .accessibilityIdentifier("project-plan-phase-lifecycle-\(phase.id.rawValue)")
            Text("\(phase.ticketCount) tickets · \(phase.deliveryGoals.count) Delivery Goals")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            if phasePlanFinalizationPhaseID == phase.id,
               let message = phasePlanFinalizationMessage {
                phasePlanFinalizationFeedback(phase: phase, message: message)
            }
            if phase.deliveryGoals.isEmpty {
                Text("No Delivery Goals recorded").font(.caption).foregroundStyle(.tertiary)
            } else {
                ForEach(phase.deliveryGoals) { goal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target").foregroundStyle(RekonTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title).font(.subheadline.weight(.medium))
                            Text("\(goal.lifecycle.displayName) · \(goal.ticketIDs.count) tickets")
                                .font(.caption).foregroundStyle(.secondary)
                            if let coverage = goal.coverage {
                                Text(coverageSummary(coverage))
                                    .font(.caption)
                                    .foregroundStyle(coverage.isAcceptanceEligible ? RekonTheme.success : RekonTheme.secondaryText)
                                    .accessibilityIdentifier("delivery-goal-coverage-\(goal.goalID.rawValue)")
                                ForEach(coverage.obligations) { obligation in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(obligation.key.ticketID.rawValue) · \(coverageStateName(obligation.state))")
                                            .font(.caption.weight(.medium))
                                        Text(obligation.scope)
                                            .font(.caption2)
                                            .foregroundStyle(RekonTheme.secondaryText)
                                        if let reason = obligation.reason {
                                            Text(reason)
                                                .font(.caption2)
                                                .foregroundStyle(RekonTheme.secondaryText)
                                        }
                                    }
                                    .accessibilityIdentifier("goal-obligation-\(obligation.key.ticketID.rawValue)")
                                }
                            }
                        }
                        Spacer(minLength: 8)
                        if goal.lifecycle != .accepted, goal.lifecycle != .superseded,
                           phase.lifecycle.lifecycle != .completed, loadDeliveryGoalEditor != nil {
                            Button("Edit") { openDeliveryGoalEditor(phase.id, goalID: goal.goalID) }
                                .buttonStyle(RekonSecondaryButtonStyle())
                                .accessibilityIdentifier("edit-delivery-goal-\(goal.goalID.rawValue)")
                        }
                    }
                }
            }
            if let transitionPhaseLifecycle, let reloadPhaseLifecycle {
                PhaseLifecycleControls(
                    phase: phase,
                    transition: { action, baseline, reason in
                        await transitionPhaseLifecycle(
                            phase.id, phase.lifecycle.revision, action, baseline, reason)
                    },
                    reload: reloadPhaseLifecycle
                )
            }
        }
        .padding(14)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(RekonTheme.border, lineWidth: RekonBorder.hairline) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan-phase-\(phase.id.rawValue)")
    }

    private func beginPhasePlanFinalization(_ phase: ProjectPlanPhaseProjection) {
        guard let finalizePhasePlan,
              phase.lifecycle.lifecycle != .completed,
              phase.readiness.state == .draft,
              !isFinalizingPhasePlan else { return }
        phasePlanFinalizationPhaseID = phase.id
        phasePlanFinalizationMessage = nil
        phasePlanFinalizationFailure = nil
        phasePlanFinalizationNeedsReload = false
        isFinalizingPhasePlan = true
        Task {
            handlePhasePlanFinalizationOutcome(
                await finalizePhasePlan(phase.id, phase.readiness.revision)
            )
        }
    }

    private func reconcilePhasePlanFinalization(_ attemptID: UUID) {
        guard let reconcilePhasePlanFinalization, !isFinalizingPhasePlan else { return }
        isFinalizingPhasePlan = true
        Task { handlePhasePlanFinalizationOutcome(await reconcilePhasePlanFinalization(attemptID)) }
    }

    private func handlePhasePlanFinalizationOutcome(_ outcome: PhasePlanFinalizationOutcome) {
        isFinalizingPhasePlan = false
        switch outcome.status {
        case let .confirmed(savedRevision, _, readback):
            phasePlanFinalizationPhaseID = readback.phaseID
            phasePlanFinalizationFailure = nil
            phasePlanFinalizationNeedsReload = false
            phasePlanFinalizationMessage = "Phase plan is Ready at revision \(savedRevision)."
        case let .savedNeedsReload(savedRevision, _):
            phasePlanFinalizationFailure = nil
            phasePlanFinalizationNeedsReload = true
            phasePlanFinalizationMessage = "Finalization was saved at revision \(savedRevision). Reload the project plan; do not repeat the finalization."
        case let .rejected(error, readback):
            phasePlanFinalizationFailure = if case let .phasePlanIncomplete(failure) = error { failure } else { nil }
            phasePlanFinalizationNeedsReload = readback == nil && finalizationRequiresReload(error)
            phasePlanFinalizationMessage = phasePlanFinalizationErrorMessage(error)
        case let .unconfirmed(error):
            phasePlanFinalizationFailure = nil
            phasePlanFinalizationNeedsReload = false
            phasePlanFinalizationMessage = phasePlanFinalizationErrorMessage(error)
        }
    }

    private func focusFinalizationTicket(_ ticketID: TicketID) {
        selectedTicketID = ticketID
        focusChanged(.ticket(ticketID))
        focusedTicketID = ticketID
        accessibilityFocusedTicketID = ticketID
    }

    private func finalizationRequiresReload(_ error: AgentCommandError) -> Bool {
        switch error {
        case .planRevisionConflict, .staleProjectRegistration: true
        default: false
        }
    }

    @ViewBuilder private func phasePlanFinalizationFeedback(
        phase: ProjectPlanPhaseProjection,
        message: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.caption)
                .foregroundStyle(RekonTheme.danger)
                .accessibilityIdentifier("phase-plan-finalization-message")
            if let failure = phasePlanFinalizationFailure {
                if failure.incompleteGoalIDs.isEmpty,
                   failure.unassignedTicketIDs.isEmpty,
                   failure.conflictingTicketIDs.isEmpty {
                    Button("Create a Delivery Goal") { openDeliveryGoalEditor(phase.id, goalID: nil) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .accessibilityIdentifier("create-delivery-goal-for-finalization-\(phase.id.rawValue)")
                }
                ForEach(failure.incompleteGoalIDs, id: \.self) { goalID in
                    Button("Complete Delivery Goal \(goalID.rawValue)") {
                        openDeliveryGoalEditor(phase.id, goalID: goalID)
                    }
                    .buttonStyle(.link)
                    .accessibilityIdentifier("phase-plan-incomplete-goal-\(goalID.rawValue)")
                }
                ForEach(failure.unassignedTicketIDs, id: \.self) { ticketID in
                    Button("Assign ticket \(ticketID.rawValue)") { focusFinalizationTicket(ticketID) }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("phase-plan-uncovered-ticket-\(ticketID.rawValue)")
                }
                ForEach(failure.conflictingTicketIDs, id: \.self) { ticketID in
                    Button("Resolve ticket \(ticketID.rawValue) conflict") { focusFinalizationTicket(ticketID) }
                        .buttonStyle(.link)
                        .accessibilityIdentifier("phase-plan-conflicting-ticket-\(ticketID.rawValue)")
                }
            }
            if let recovery = phasePlanFinalizationRecovery?(phase.id) {
                Button("Reconcile saved finalization") { reconcilePhasePlanFinalization(recovery.attemptID) }
                    .buttonStyle(RekonSecondaryButtonStyle())
                    .disabled(isFinalizingPhasePlan)
                    .accessibilityIdentifier("reconcile-phase-plan-finalization")
            }
            if phasePlanFinalizationNeedsReload {
                Button("Reload project plan") {
                    Task { await reloadPhaseLifecycle?() }
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("reload-phase-plan-finalization")
            }
        }
    }

    @ViewBuilder private var deliveryGoalEditorSheet: some View {
        NavigationStack {
            Form {
                if let editor = deliveryGoalEditor {
                    Section {
                        Text("Plan revision \(editor.planRevision)")
                        Text(editor.goalLifecycle == nil ? "New Delivery Goal" : "Edit Delivery Goal")
                    }
                    Section("Goal") {
                        TextField("Title", text: $deliveryGoalTitle)
                        TextField("Intended outcome", text: $deliveryGoalOutcome, axis: .vertical)
                        TextField("Done criteria, one per line", text: $deliveryGoalCriteria, axis: .vertical)
                    }
                    if let message = deliveryGoalEditorMessage {
                        Text(message).foregroundStyle(RekonTheme.danger)
                            .accessibilityIdentifier("delivery-goal-editor-message")
                    }
                    if let recovery = deliveryGoalDraftSaveRecovery?(editor.phaseID) {
                        Button("Reconcile saved attempt") { reconcileDeliveryGoalDraftSave(recovery.attemptID) }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .disabled(isSavingDeliveryGoal)
                            .accessibilityIdentifier("reconcile-delivery-goal-save")
                    }
                } else {
                    ProgressView("Loading Delivery Goal editor")
                }
            }
            .navigationTitle("Delivery Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsDeliveryGoalEditor = false }
                        .disabled(isSavingDeliveryGoal)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCurrentDeliveryGoal() }
                        .disabled(deliveryGoalEditor == nil || isSavingDeliveryGoal)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
    }

    private func openDeliveryGoalEditor(_ phaseID: PhaseID, goalID: DeliveryGoalID?) {
        guard let loadDeliveryGoalEditor else { return }
        deliveryGoalEditor = nil
        deliveryGoalEditorMessage = nil
        showsDeliveryGoalEditor = true
        Task {
            switch await loadDeliveryGoalEditor(phaseID, goalID) {
            case let .loaded(editor):
                deliveryGoalEditor = editor
                deliveryGoalTitle = editor.draft.title
                deliveryGoalOutcome = editor.draft.outcome
                deliveryGoalCriteria = editor.draft.doneCriteria.joined(separator: "\n")
            case let .failed(error):
                deliveryGoalEditorMessage = deliveryGoalDraftErrorMessage(error)
            }
        }
    }

    @ViewBuilder private var deliveryGoalAssignmentEditorSheet: some View {
        NavigationStack { Form {
            if let editor = deliveryGoalAssignmentEditor {
                Section { Text("Plan revision \(editor.planRevision)"); Text("Covered and uncovered work") }
                Section("Eligible tickets") { ForEach(editor.tickets) { ticket in
                    Picker(ticket.id.rawValue, selection: Binding(get: { deliveryGoalAssignmentSelections[ticket.id] ?? currentGoal(ticket.id, editor: editor)?.rawValue ?? "" }, set: { deliveryGoalAssignmentSelections[ticket.id] = $0 })) {
                        Text("Unassigned").tag("")
                        ForEach(editor.goals.filter { $0.lifecycle != .accepted && $0.lifecycle != .superseded }) { Text($0.title).tag($0.goalID.rawValue) }
                    }
                }}
                if let message = deliveryGoalAssignmentEditorMessage {
                    Text(message).foregroundStyle(RekonTheme.danger)
                        .accessibilityIdentifier("delivery-goal-assignment-editor-message")
                }
                if let recovery = deliveryGoalAssignmentDraftSaveRecovery?(editor.phaseID) {
                    Button("Reconcile saved attempt") { reconcileDeliveryGoalAssignments(recovery.attemptID) }
                        .buttonStyle(RekonSecondaryButtonStyle())
                        .disabled(isSavingDeliveryGoalAssignments)
                        .accessibilityIdentifier("reconcile-delivery-goal-assignment-save")
                }
            } else if let message = deliveryGoalAssignmentEditorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(RekonTheme.danger)
                        .accessibilityIdentifier("delivery-goal-assignment-editor-message")
                    if let phaseID = deliveryGoalAssignmentEditorPhaseID {
                        Button("Retry") { openDeliveryGoalAssignmentEditor(phaseID) }
                            .buttonStyle(RekonSecondaryButtonStyle())
                            .accessibilityIdentifier("retry-delivery-goal-assignment-load")
                    }
                }
            } else { ProgressView("Loading ticket assignments") }
        }.navigationTitle("Assign Delivery Goal Tickets").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsDeliveryGoalAssignmentEditor = false }.disabled(isSavingDeliveryGoalAssignments) }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { saveDeliveryGoalAssignments() }.disabled(deliveryGoalAssignmentEditor == nil || isSavingDeliveryGoalAssignments) }
        }}
        .frame(minWidth: 520, minHeight: 400)
        .accessibilityElement(children: .contain)
    }
    private func currentGoal(_ ticketID: TicketID, editor: DeliveryGoalAssignmentEditorSnapshot) -> DeliveryGoalID? { editor.assignments.first { $0.ticketID == ticketID }?.goalID }
    private func openDeliveryGoalAssignmentEditor(_ phaseID: PhaseID) {
        guard let loadDeliveryGoalAssignmentEditor else { return }
        deliveryGoalAssignmentEditorPhaseID = phaseID
        deliveryGoalAssignmentEditor = nil
        deliveryGoalAssignmentSelections = [:]
        deliveryGoalAssignmentEditorMessage = nil
        showsDeliveryGoalAssignmentEditor = true
        Task {
            switch await loadDeliveryGoalAssignmentEditor(phaseID) {
            case let .loaded(editor): deliveryGoalAssignmentEditor = editor
            case let .failed(error): deliveryGoalAssignmentEditorMessage = deliveryGoalAssignmentDraftErrorMessage(error)
            }
        }
    }
    private func saveDeliveryGoalAssignments() {
        guard let editor = deliveryGoalAssignmentEditor, let saveDeliveryGoalAssignmentDraft else { return }
        let edits = editor.tickets.compactMap { ticket -> DeliveryGoalAssignmentEdit? in
            let raw = deliveryGoalAssignmentSelections[ticket.id] ?? currentGoal(ticket.id, editor: editor)?.rawValue ?? ""
            let goal = raw.isEmpty ? nil : DeliveryGoalID(rawValue: raw)
            return goal == currentGoal(ticket.id, editor: editor) ? nil : .init(ticketID: ticket.id, goalID: goal)
        }
        isSavingDeliveryGoalAssignments = true
        Task { handleDeliveryGoalAssignmentOutcome(await saveDeliveryGoalAssignmentDraft(editor.phaseID, editor.planRevision, edits)) }
    }
    private func reconcileDeliveryGoalAssignments(_ attemptID: UUID) {
        guard let reconcileDeliveryGoalAssignmentDraftSave else { return }
        isSavingDeliveryGoalAssignments = true
        Task { handleDeliveryGoalAssignmentOutcome(await reconcileDeliveryGoalAssignmentDraftSave(attemptID)) }
    }
    private func handleDeliveryGoalAssignmentOutcome(_ outcome: DeliveryGoalAssignmentSaveOutcome) {
        isSavingDeliveryGoalAssignments = false
        switch outcome.status {
        case .confirmed: showsDeliveryGoalAssignmentEditor = false
        case .savedNeedsReload: deliveryGoalAssignmentEditorMessage = "Saved. Reload the project plan before editing assignments again."
        case let .rejected(error, refreshedEditor):
            deliveryGoalAssignmentEditorMessage = deliveryGoalAssignmentDraftErrorMessage(error)
            if let refreshedEditor { deliveryGoalAssignmentEditor = refreshedEditor }
        case .unconfirmed: deliveryGoalAssignmentEditorMessage = "Save outcome is uncertain. Reconcile the same saved attempt before editing assignments again."
        }
    }

    private func saveCurrentDeliveryGoal() {
        guard let editor = deliveryGoalEditor, let saveDeliveryGoalDraft else { return }
        isSavingDeliveryGoal = true
        let draft = DeliveryGoalDraft(
            id: editor.draft.id, title: deliveryGoalTitle, outcome: deliveryGoalOutcome,
            doneCriteria: deliveryGoalCriteria.components(separatedBy: .newlines), sortOrder: editor.draft.sortOrder
        )
        Task {
            let outcome = await saveDeliveryGoalDraft(editor.phaseID, editor.planRevision, draft)
            isSavingDeliveryGoal = false
            switch outcome.status {
            case .confirmed:
                showsDeliveryGoalEditor = false
            case .savedNeedsReload:
                deliveryGoalEditorMessage = "Saved. Reload the project plan before editing again."
            case let .rejected(error, refreshedEditor):
                deliveryGoalEditorMessage = deliveryGoalDraftErrorMessage(error)
                if let refreshedEditor { deliveryGoalEditor = refreshedEditor }
            case .unconfirmed:
                deliveryGoalEditorMessage = "Save outcome is uncertain. Reopen this editor after the saved attempt is reconciled."
            }
        }
    }

    private func reconcileDeliveryGoalDraftSave(_ attemptID: UUID) {
        guard let reconcileDeliveryGoalDraftSave else { return }
        isSavingDeliveryGoal = true
        Task {
            let outcome = await reconcileDeliveryGoalDraftSave(attemptID)
            isSavingDeliveryGoal = false
            switch outcome.status {
            case .confirmed:
                showsDeliveryGoalEditor = false
            case .savedNeedsReload:
                deliveryGoalEditorMessage = "Saved. Reload the project plan before editing again."
            case let .rejected(error, refreshedEditor):
                deliveryGoalEditorMessage = deliveryGoalDraftErrorMessage(error)
                if let refreshedEditor { deliveryGoalEditor = refreshedEditor }
            case .unconfirmed:
                deliveryGoalEditorMessage = "Save outcome is still uncertain. Reconcile the same saved attempt again later."
            }
        }
    }

    private func retiredTicketRow(_ ticket: RetiredTicketProjection) -> some View {
        Button {
            selectedProposalID = nil
            selectedProposalVersion = nil
            selectedTicketID = ticket.id
            focusChanged(.ticket(ticket.id))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ticket.id.rawValue).font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    Spacer()
                    Text(ticket.disposition.rawValue.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RekonTheme.warning)
                }
                Text(ticket.outcome).font(.subheadline)
                Text(ticket.reason).font(.caption).foregroundStyle(RekonTheme.secondaryText)
                if let phaseID = ticket.lastPhaseID, let lane = ticket.lastLane {
                    Text("Last placement: \(phaseID.rawValue) · \(lane.dashboardTitle)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                } else if let phaseID = ticket.lastPhaseID {
                    Text("Last phase: \(phaseID.rawValue)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                } else if let lane = ticket.lastLane {
                    Text("Last lane: \(lane.dashboardTitle)")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                if !ticket.successorTicketIDs.isEmpty {
                    Text("Successors: \(ticket.successorTicketIDs.map(\.rawValue).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.accent)
                }
            }
            .padding(12)
            .background(selectedTicketID == ticket.id ? RekonTheme.elevatedSurface : RekonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(
                selectedTicketID == ticket.id ? RekonTheme.accent : RekonTheme.border,
                lineWidth: RekonBorder.hairline
            ) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedTicketID, equals: ticket.id)
        .accessibilityFocused($accessibilityFocusedTicketID, equals: ticket.id)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("retired-ticket-\(ticket.id.rawValue)")
        .id("project-plan-ticket-scroll-\(ticket.id.rawValue)")
    }

    private func coverageSummary(_ coverage: DeliveryGoalCoverageAssessment) -> String {
        if coverage.obligations.contains(where: { $0.state == .unassessed }) {
            return "Coverage needs assessment"
        }
        if coverage.isAcceptanceEligible {
            return "Coverage resolved · \(coverage.deliveredLeafCount) delivered"
        }
        return "Coverage open · \(coverage.deliveredLeafCount) of \(coverage.requiredLeafCount) delivered"
    }

    private func coverageStateName(_ state: DeliveryGoalObligationCoverageState) -> String {
        switch state {
        case .required: "Required"
        case .uncovered: "Uncovered"
        case .carried: "Carried"
        case .dropped: "Dropped"
        case .delivered: "Delivered"
        case .unassessed: "Needs assessment"
        }
    }

    private func sectionHeading(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Text("\(count)").font(.caption.weight(.medium)).monospacedDigit()
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(RekonTheme.elevatedSurface, in: Capsule())
        }
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var inspector: some View {
        if let selection = selectedProposal {
            proposalInspector(proposal: selection.proposal, version: selection.version)
        } else if let detail = plan.detail(for: selectedTicketID) ?? plan.unassignedDetails.values.sorted(by: { $0.id.rawValue < $1.id.rawValue }).first {
            TicketDetailView(
                detail: detail,
                documentationStatus: documentationStatus,
                loadEvidencePreview: loadEvidencePreview,
                loadReferences: loadTicketReferences.map { loader in
                    { await loader(detail.id) }
                },
                loadDeliveryEvidence: loadTicketDeliveryEvidence.map { loader in
                    { await loader(detail.id) }
                },
                openReferenceSource: openReferenceSource.map { opener in
                    { linkID, version in opener(detail.id, linkID, version) }
                },
                referenceQueryContextIdentity: referenceQueryContextIdentity,
                isReferenceQueryReady: isReferenceQueryReady
            )
                .accessibilityIdentifier("project-plan-inspector")
        } else {
            ContentUnavailableView("Select an unassigned ticket", systemImage: "rectangle.on.rectangle")
        }
    }

    private var selectedProposal: (proposal: PlanChangeProposalRecord, version: PlanChangeProposalVersionRecord)? {
        guard let selectedProposalID,
              let proposal = plan.proposals.first(where: { Data($0.id.rawValue.utf8) == selectedProposalID }),
              let version = proposal.versions.first(where: { $0.version == (selectedProposalVersion ?? proposal.currentVersion) }) else {
            return nil
        }
        return (proposal, version)
    }

    private func proposalInspector(
        proposal: PlanChangeProposalRecord,
        version: PlanChangeProposalVersionRecord
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.id.rawValue)
                    .font(RekonTypography.sectionTitle)
                Text("Version \(version.version) of \(proposal.currentVersion)")
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
                Text("Baseline \(version.baselineDigest.prefix(12))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(RekonTheme.secondaryText)
            }

            proposalVersionPicker(proposal)

            VStack(alignment: .leading, spacing: 5) {
                Text("Rationale").font(.headline)
                Text(version.rationale).font(.subheadline)
            }

            ForEach(version.diff.groups, id: \.kind) { group in
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.kind.displayName)
                        .font(.headline)
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        Label(item.summary, systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Recorded source impacts").font(.headline)
                if version.sourceImpacts.isEmpty {
                    Text("No linked requirement or decision versions were recorded for affected tickets.")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                } else {
                    ForEach(version.sourceImpacts) { impact in
                        Button {
                            openReferenceSource?(impact.ticketID, impact.linkID, impact.version)
                            focusChanged(.planChangeProposal(
                                proposalID: proposal.id.rawValue,
                                version: version.version,
                                ticketID: impact.ticketID
                            ))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(impact.ticketID.rawValue) · \(impact.artifactID)")
                                    .font(.caption.weight(.medium))
                                Text("Recorded v\(impact.version) · \(impact.observedLifecycle.rawValue) · \(impact.observedAuthority.rawValue)")
                                    .font(.caption2)
                                    .foregroundStyle(RekonTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)
                        .focusable()
                        .focused($focusedProposal, equals: .sourceImpact(impact.id))
                        .accessibilityFocused($accessibilityFocusedProposal, equals: .sourceImpact(impact.id))
                        .accessibilityLabel("Recorded source impact for \(impact.ticketID.rawValue)")
                        .accessibilityValue("\(impact.artifactID), recorded version \(impact.version), \(impact.observedLifecycle.rawValue), \(impact.observedAuthority.rawValue)")
                        .accessibilityIdentifier("proposal-source-impact-\(impact.id)")
                        .id("proposal-source-impact-scroll-\(impact.id)")
                        .onAppear {
                            guard requestedFocus == .planChangeProposal(
                                proposalID: proposal.id.rawValue,
                                version: version.version,
                                ticketID: impact.ticketID
                            ) else { return }
                            focusedProposal = .sourceImpact(impact.id)
                            accessibilityFocusedProposal = .sourceImpact(impact.id)
                        }
                    }
                }
            }

            proposalStateView(version)

            if let proposalActionFailure {
                FailureStateView(presentation: proposalActionFailure, style: .inline)
            }

            proposalActions(proposal: proposal, version: version)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(RekonTheme.border, lineWidth: RekonBorder.hairline)
        }
    }

    private func proposalVersionPicker(_ proposal: PlanChangeProposalRecord) -> some View {
        Picker("Proposal version", selection: Binding(
            get: { selectedProposalVersion ?? proposal.currentVersion },
            set: { version in
                selectedProposalVersion = version
                proposalActionFailure = nil
                proposalNeedsRefresh = false
                focusChanged(.planChangeProposal(
                    proposalID: proposal.id.rawValue,
                    version: version,
                    ticketID: nil
                ))
            }
        )) {
            ForEach(proposal.versions) { version in
                Text("Version \(version.version)").tag(version.version)
            }
        }
        .accessibilityIdentifier("plan-change-proposal-version")
    }

    @ViewBuilder
    private func proposalStateView(_ version: PlanChangeProposalVersionRecord) -> some View {
        if let application = version.application {
            Label("Applied · \(application.appliedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.seal.fill")
                .foregroundStyle(RekonTheme.success)
        } else if let decision = version.decision {
            Label(
                decision.disposition == .approved ? "Approved" : "Rejected",
                systemImage: decision.disposition == .approved ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(decision.disposition == .approved ? RekonTheme.success : RekonTheme.danger)
        } else {
            Label("Awaiting owner decision", systemImage: "person.crop.circle.badge.questionmark")
                .foregroundStyle(RekonTheme.warning)
        }
    }

    @ViewBuilder
    private func proposalActions(
        proposal: PlanChangeProposalRecord,
        version: PlanChangeProposalVersionRecord
    ) -> some View {
        let isCurrent = version.version == proposal.currentVersion
        if version.application == nil, version.decision == nil, isCurrent, !proposalNeedsRefresh,
           let decideProposal {
            HStack(spacing: 10) {
                Button("Reject") {
                    performProposalAction {
                        await decideProposal(proposal.id, version.version, version.baselineDigest, .rejected)
                    }
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .accessibilityIdentifier("reject-plan-change-proposal")
                Button("Approve") {
                    performProposalAction {
                        await decideProposal(proposal.id, version.version, version.baselineDigest, .approved)
                    }
                }
                .buttonStyle(RekonPrimaryButtonStyle())
                .accessibilityIdentifier("approve-plan-change-proposal")
            }
            .disabled(isPerformingProposalAction)
        }
        if version.application == nil,
           version.decision?.disposition == .approved,
           isCurrent, !proposalNeedsRefresh,
           let applyProposal,
           let decisionID = version.decision?.id {
            Button("Apply approved version") {
                performProposalAction {
                    await applyProposal(proposal.id, version.version, version.baselineDigest, decisionID)
                }
            }
            .buttonStyle(RekonPrimaryButtonStyle())
            .disabled(isPerformingProposalAction)
            .accessibilityIdentifier("apply-plan-change-proposal")
        }
        if version.application == nil, isCurrent, let refreshProposal {
            Button("Refresh proposal") {
                performProposalAction(
                    {
                        await refreshProposal(proposal.id, version.version, version.rationale, version.operations)
                    },
                    onSuccess: { result in
                        guard let refreshedVersion = result.planChangeProposalVersion else { return }
                        selectedProposalID = Data(proposal.id.rawValue.utf8)
                        selectedProposalVersion = refreshedVersion
                        proposalNeedsRefresh = false
                        focusChanged(.planChangeProposal(
                            proposalID: proposal.id.rawValue,
                            version: refreshedVersion,
                            ticketID: nil
                        ))
                    }
                )
            }
            .buttonStyle(RekonSecondaryButtonStyle())
            .disabled(isPerformingProposalAction)
            .accessibilityIdentifier("refresh-plan-change-proposal")
        }
    }

    private func performProposalAction(
        _ action: @escaping () async -> AgentCommandResult,
        onSuccess: @escaping (AgentCommandResult) -> Void = { _ in }
    ) {
        guard !isPerformingProposalAction else { return }
        isPerformingProposalAction = true
        proposalActionFailure = nil
        Task { @MainActor in
            let result = await action()
            isPerformingProposalAction = false
            if let error = result.error {
                proposalActionFailure = FailureStatePresentation(agentError: error)
                if case .planChangeProposalStale = error { proposalNeedsRefresh = true }
            } else {
                onSuccess(result)
            }
        }
    }

    private func readinessSummary(_ readiness: PhasePlanProjection) -> String {
        let state = switch readiness.state {
        case .legacyUnassessed: "Legacy unassessed"
        case .draft: "Draft"
        case .ready: "Ready"
        }
        return "\(state) · revision \(readiness.revision) · \(readiness.coveredUpcomingCount)/\(readiness.upcomingCount) covered"
    }

    private func applyRequestedFocus() {
        switch requestedFocus {
        case let .ticket(ticketID):
            guard plan.detail(for: ticketID) != nil else { return }
            selectedProposalID = nil
            selectedProposalVersion = nil
            focusedProposal = nil
            accessibilityFocusedProposal = nil
            focusedTicketID = ticketID
            accessibilityFocusedTicketID = ticketID
        case let .planChangeProposal(proposalID, version, ticketID):
            guard let proposal = plan.proposals.first(where: {
                Data($0.id.rawValue.utf8) == Data(proposalID.utf8)
            }), let selectedVersion = proposal.versions.first(where: { $0.version == version }) else { return }
            selectedProposalID = Data(proposalID.utf8)
            selectedProposalVersion = version
            proposalActionFailure = nil
            proposalNeedsRefresh = false
            let impactID = ticketID.flatMap { selectedTicketID in
                selectedVersion.sourceImpacts.first(where: { $0.ticketID == selectedTicketID })?.id
            }
            if let impactID {
                focusedProposal = .sourceImpact(impactID)
                accessibilityFocusedProposal = .sourceImpact(impactID)
            } else {
                let proposalKey = Data(proposalID.utf8)
                focusedProposal = .proposal(proposalKey)
                accessibilityFocusedProposal = .proposal(proposalKey)
            }
        default:
            break
        }
    }

    private func reconcileProposalSelection() {
        if let selectedProposalID,
           let proposal = plan.proposals.first(where: { Data($0.id.rawValue.utf8) == selectedProposalID }),
           proposal.versions.contains(where: { $0.version == selectedProposalVersion }) {
            return
        }
        guard let proposal = plan.proposals.first,
              let version = proposal.versions.first(where: { $0.version == proposal.currentVersion }) else {
            selectedProposalID = nil
            selectedProposalVersion = nil
            return
        }
        selectedProposalID = Data(proposal.id.rawValue.utf8)
        selectedProposalVersion = version.version
        proposalActionFailure = nil
        proposalNeedsRefresh = false
    }

    private func proposalState(_ version: PlanChangeProposalVersionRecord?) -> String {
        guard let version else { return "Unavailable" }
        if version.application != nil { return "Applied" }
        switch version.decision?.disposition {
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case nil: return "Awaiting decision"
        }
    }

    private func navigationScrollTargetID(forWidth width: CGFloat) -> String? {
        if case let .ticket(ticketID)? = requestedFocus,
           plan.retiredTickets.contains(where: { $0.id == ticketID })
            || plan.unassignedTickets.contains(where: { $0.id == ticketID }) {
            return "project-plan-ticket-scroll-\(ticketID.rawValue)"
        }
        guard ProjectPlanLayout.usesStackedInspector(forWidth: width) else { return nil }
        guard case let .planChangeProposal(proposalID, version, ticketID)? = requestedFocus,
              let ticketID,
              selectedProposalID == Data(proposalID.utf8),
              selectedProposalVersion == version,
              let proposal = plan.proposals.first(where: { $0.id.rawValue == proposalID }),
              let selectedVersion = proposal.versions.first(where: { $0.version == version }),
              let impact = selectedVersion.sourceImpacts.first(where: { $0.ticketID == ticketID }) else {
            return nil
        }
        return "proposal-source-impact-scroll-\(impact.id)"
    }
}

private enum ProposalFocus: Hashable {
    case proposal(Data)
    case sourceImpact(String)
}

private extension PlanChangeDiffKind {
    var displayName: String {
        switch self {
        case .phases: "Phases"
        case .goals: "Delivery Goals"
        case .tickets: "Tickets"
        case .tasks: "Tasks"
        case .assignments: "Assignments"
        case .dependencies: "Dependencies"
        }
    }
}
