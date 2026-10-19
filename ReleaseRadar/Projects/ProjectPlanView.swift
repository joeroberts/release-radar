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
        return "This phase plan changed. Refresh the project plan, then finalize the current revision."
    case .appUnavailable:
        return "Release Radar is temporarily unavailable. No finalization was sent; try again when it is available."
    case .outcomeUnknown:
        return "Release Radar could not confirm finalization. Reconcile the same saved attempt before trying again."
    case .completedPhaseReadOnly:
        return "This completed phase cannot be finalized."
    default:
        return "The phase plan could not be finalized. Refresh the project plan and try again."
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
    var roadmapLoadError: String? = nil
    var reloadRoadmap: (() async -> Void)? = nil
    var openDependencies: ((TicketID?) -> Void)? = nil
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
    @FocusState private var focusedPhaseID: PhaseID?
    @AccessibilityFocusState private var accessibilityFocusedPhaseID: PhaseID?
    @FocusState private var phaseDetailHeadingFocused: Bool
    @AccessibilityFocusState private var accessibilityPhaseDetailHeadingFocused: Bool
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
    @State private var selectedPhaseID: PhaseID?
    @State private var selectedPlanTicketID: TicketID?
    @State private var showsCompactPhaseDetail = false
    @State private var showsUnplacedWork = false
    @State private var showsRetiredOriginals = false
    @State private var showsPlanChanges = false
    @State private var showsTechnicalRecord = false
    @State private var showsPhaseTickets = false
    @State private var usesCompactLayout = false
    @State private var roadmapScrollPosition: String?
    @State private var roadmapScrollRestorePosition: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                Group {
                    if ProjectPlanLayout.usesStackedInspector(forWidth: geometry.size.width) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                if showsCompactPhaseDetail, let phase = selectedPhase {
                                    compactPhaseDetail(phase)
                                } else {
                                    header
                                    roadmapFreshness
                                    planContent
                                }
                            }
                        }
                        .scrollPosition(id: $roadmapScrollPosition)
                        .accessibilityIdentifier("project-plan-roadmap-scroll")
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            roadmapFreshness
                            HStack(alignment: .top, spacing: 18) {
                                ScrollView {
                                    planContent
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .scrollPosition(id: $roadmapScrollPosition)
                                .accessibilityIdentifier("project-plan-roadmap-scroll")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                RekonSeparator(.vertical)
                                ScrollView {
                                    inspector
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                }
                                .accessibilityIdentifier("project-plan-inspector-scroll")
                                .frame(width: min(520, max(440, geometry.size.width * 0.38)))
                                .frame(maxHeight: .infinity, alignment: .top)
                            }
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onAppear {
                    usesCompactLayout = ProjectPlanLayout.usesStackedInspector(forWidth: geometry.size.width)
                }
                .onChange(of: geometry.size.width) { _, width in
                    usesCompactLayout = ProjectPlanLayout.usesStackedInspector(forWidth: width)
                    if !usesCompactLayout { showsCompactPhaseDetail = false }
                }
                .onChange(of: requestedFocus, initial: true) { _, _ in
                    applyRequestedFocus(
                        usesCompactLayout: ProjectPlanLayout.usesStackedInspector(forWidth: geometry.size.width)
                    )
                }
                .onChange(of: navigationScrollTargetID(forWidth: geometry.size.width), initial: true) { _, targetID in
                    guard let targetID else { return }
                    Task { @MainActor in
                        await Task.yield()
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
                .onChange(of: showsCompactPhaseDetail) { _, showsDetail in
                    guard !showsDetail, let selectedPhaseID else { return }
                    Task { @MainActor in
                        await Task.yield()
                        roadmapScrollPosition = roadmapScrollRestorePosition ?? phaseScrollID(selectedPhaseID)
                        await Task.yield()
                        focusedPhaseID = selectedPhaseID
                        accessibilityFocusedPhaseID = selectedPhaseID
                    }
                }
            }
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan")
        .onChange(of: plan.proposals) { _, _ in reconcileProposalSelection() }
        .onChange(of: plan.phases) { _, _ in reconcilePhaseSelection() }
        .task {
            reconcilePhaseSelection()
            reconcileProposalSelection()
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
                .disabled(roadmapLoadError != nil)
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
            Text("\(plan.phases.count) phase\(plan.phases.count == 1 ? "" : "s")")
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

    @ViewBuilder private var roadmapFreshness: some View {
        if let roadmapLoadError {
            FailureStateView(
                presentation: .init(
                    title: "Project plan may be out of date",
                    detail: "The last successful roadmap is still shown. Editing and finalization are paused until refresh succeeds. \(roadmapLoadError)",
                    systemImage: "arrow.clockwise.circle",
                    tone: .warning,
                    accessibilityID: "project-plan-data-stale"
                ),
                style: .inline,
                actionTitle: "Retry",
                action: { Task { await reloadRoadmap?() } }
            )
        }
    }

    private var planContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !plan.unassignedTickets.isEmpty { unplacedWork }

            if plan.phases.isEmpty {
                ContentUnavailableView(
                    "No phases yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Prepare the repository plan to create a roadmap from recorded planning evidence.")
                )
                if !plan.proposals.isEmpty { planChanges }
            } else {
                ForEach(phaseLifecycleOrder, id: \.rawValue) { lifecycle in
                    let phases = orderedPhases.filter { $0.lifecycle.lifecycle == lifecycle }
                    if !phases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeading(lifecycle.displayName, count: phases.count)
                            LazyVStack(spacing: 8) {
                                ForEach(phases) { phase in phaseRow(phase) }
                            }
                            .scrollTargetLayout()
                        }
                    }
                }
            }

            if !plan.retiredTickets.isEmpty { retiredWork }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan-roadmap")
    }

    private var unplacedWork: some View {
        DisclosureGroup(isExpanded: $showsUnplacedWork) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Planning content remains here until its first placement into a phase backlog.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                ForEach(plan.unassignedTickets) { card in
                    TicketCardView(
                        card: card,
                        presentation: .fullOutcome,
                        isSelected: selectedPlanTicketID == card.id
                    ) { selectTicket(card.id) }
                    .focusable()
                    .focused($focusedTicketID, equals: card.id)
                    .accessibilityFocused($accessibilityFocusedTicketID, equals: card.id)
                    .id("project-plan-ticket-scroll-\(card.id.rawValue)")
                }
                if let selectedPlanTicketID,
                   plan.unassignedTickets.contains(where: { $0.id == selectedPlanTicketID }),
                   let detail = plan.detail(for: selectedPlanTicketID) {
                    ticketDetail(detail)
                }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Not placed", count: plan.unassignedTickets.count)
        }
        .accessibilityIdentifier("project-plan-unplaced-work")
    }

    private var retiredWork: some View {
        DisclosureGroup(isExpanded: $showsRetiredOriginals) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Retired originals remain read-only with their disposition, rationale, and successor lineage.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                ForEach(plan.retiredTickets) { ticket in retiredTicketRow(ticket) }
                if let selectedPlanTicketID,
                   plan.retiredTickets.contains(where: { $0.id == selectedPlanTicketID }),
                   let detail = plan.detail(for: selectedPlanTicketID) {
                    ticketDetail(detail)
                }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Retired originals", count: plan.retiredTickets.count)
        }
        .accessibilityIdentifier("project-plan-retired-work")
    }

    private func phaseRow(_ phase: ProjectPlanPhaseProjection) -> some View {
        let selected = selectedPhaseID == phase.id
        return Button { selectPhase(phase.id) } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(phase.name)
                            .font(.headline)
                            .foregroundStyle(RekonTheme.primaryText)
                        Text(readinessName(phase.readiness.state))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(phase.readiness.state == .ready ? RekonTheme.success : RekonTheme.warning)
                    }
                    Text(phaseProgressText(phase))
                        .font(.subheadline)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .accessibilityLabel("Phase progress")
                        .accessibilityValue(phaseProgressAccessibilityValue(phase))
                        .accessibilityIdentifier("project-plan-phase-progress-\(phase.id.rawValue)")
                    if let gap = phaseGap(phase) {
                        Text(gap)
                            .font(.caption)
                            .foregroundStyle(RekonTheme.warning)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(phase.lifecycle.lifecycle.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RekonTheme.secondaryText)
                    if let action = recommendedAction(for: phase) {
                        Text(action)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RekonTheme.accent)
                            .lineLimit(1)
                    }
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(selected ? RekonTheme.elevatedSurface : RekonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? RekonTheme.accent : RekonTheme.border,
                            lineWidth: selected ? 2 : RekonBorder.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedPhaseID, equals: phase.id)
        .accessibilityFocused($accessibilityFocusedPhaseID, equals: phase.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(phase.name), \(phase.lifecycle.lifecycle.displayName) phase, \(readinessName(phase.readiness.state)) plan")
        .accessibilityValue(phaseRowAccessibilityValue(phase))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
        .accessibilityIdentifier("project-plan-phase-row-\(phase.id.rawValue)")
        .id(phaseScrollID(phase.id))
        .onMoveCommand { direction in movePhaseSelection(from: phase.id, direction: direction) }
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

    private func compactPhaseDetail(_ phase: ProjectPlanPhaseProjection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                roadmapScrollPosition = roadmapScrollRestorePosition
                showsCompactPhaseDetail = false
            } label: {
                Label("Back to roadmap", systemImage: "chevron.left")
            }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityLabel("Back to roadmap")
            .accessibilityIdentifier("back-to-project-plan-roadmap")

            roadmapFreshness
            phaseDetail(phase)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan-phase-detail-\(phase.id.rawValue)")
    }

    private func phaseDetail(_ phase: ProjectPlanPhaseProjection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phase.name)
                    .font(RekonTypography.sectionTitle)
                Text("\(phase.lifecycle.lifecycle.displayName) · \(readinessName(phase.readiness.state)) plan")
                    .font(.subheadline)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            .focusable()
            .focused($phaseDetailHeadingFocused)
            .accessibilityFocused($accessibilityPhaseDetailHeadingFocused)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("project-plan-phase-detail-heading-\(phase.id.rawValue)")

            Text(phaseProgressText(phase))
                .font(.subheadline.weight(.medium))
                .accessibilityLabel("Phase progress")
                .accessibilityValue(phaseProgressAccessibilityValue(phase))
                .accessibilityIdentifier("project-plan-phase-progress-\(phase.id.rawValue)")

            if let gap = phaseGap(phase) {
                Label(gap, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.warning)
            }
            if let action = recommendedAction(for: phase) {
                Text("Next action: \(action)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RekonTheme.accent)
            }

            phasePlanActions(phase)
            deliveryGoals(for: phase)
            phaseTickets(phase)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { phaseNavigationActions(phase) }
                VStack(alignment: .leading, spacing: 8) { phaseNavigationActions(phase) }
            }

            if roadmapLoadError == nil,
               let transitionPhaseLifecycle,
               let reloadPhaseLifecycle {
                PhaseLifecycleControls(
                    phase: phase,
                    transition: { action, baseline, reason in
                        await transitionPhaseLifecycle(
                            phase.id, phase.lifecycle.revision, action, baseline, reason)
                    },
                    reload: reloadPhaseLifecycle
                )
            } else if roadmapLoadError != nil {
                Text("Refresh the roadmap before changing this phase lifecycle.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.warning)
            }

            if !plan.proposals.isEmpty { planChanges }
            technicalRecord(for: phase)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(RekonTheme.border, lineWidth: RekonBorder.hairline)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func phasePlanActions(_ phase: ProjectPlanPhaseProjection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan actions").font(.headline)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { phasePlanActionButtons(phase) }
                VStack(alignment: .leading, spacing: 8) { phasePlanActionButtons(phase) }
            }
            if phasePlanFinalizationPhaseID == phase.id,
               let message = phasePlanFinalizationMessage {
                phasePlanFinalizationFeedback(phase: phase, message: message)
            } else if let recovery = phasePlanFinalizationRecovery?(phase.id) {
                Button("Reconcile saved finalization") {
                    reconcilePhasePlanFinalization(recovery.attemptID)
                }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(isFinalizingPhasePlan)
                .accessibilityIdentifier("reconcile-phase-plan-finalization")
            }
        }
    }

    @ViewBuilder
    private func phasePlanActionButtons(_ phase: ProjectPlanPhaseProjection) -> some View {
        let editable = phase.lifecycle.lifecycle != .completed && roadmapLoadError == nil
        if loadDeliveryGoalEditor != nil {
            Button("Create Delivery Goal") { openDeliveryGoalEditor(phase.id, goalID: nil) }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(!editable)
                .accessibilityIdentifier("create-delivery-goal-\(phase.id.rawValue)")
        }
        if loadDeliveryGoalAssignmentEditor != nil {
            Button("Edit assignments") { openDeliveryGoalAssignmentEditor(phase.id) }
                .buttonStyle(RekonSecondaryButtonStyle())
                .disabled(!editable)
                .accessibilityIdentifier("edit-delivery-goal-assignments-\(phase.id.rawValue)")
        }
        if finalizePhasePlan != nil {
            let eligible = editable && phase.readiness.state == .draft
            Button("Finalize plan") { beginPhasePlanFinalization(phase) }
                .buttonStyle(RekonPrimaryButtonStyle())
                .disabled(!eligible || isFinalizingPhasePlan)
                .accessibilityLabel(eligible
                    ? "Finalize \(phase.name) plan at revision \(phase.readiness.revision)"
                    : "Finalize \(phase.name) plan unavailable: \(finalizationUnavailableReason(phase))")
                .accessibilityIdentifier("finalize-phase-plan-\(phase.id.rawValue)")
        }
    }

    private func deliveryGoals(for phase: ProjectPlanPhaseProjection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Delivery Goals", count: phase.deliveryGoals.count)
            if phase.deliveryGoals.isEmpty {
                Text("No Delivery Goals recorded")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
            } else {
                ForEach(phase.deliveryGoals) { goal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "target").foregroundStyle(RekonTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.title).font(.subheadline.weight(.medium))
                            Text(goal.outcome)
                                .font(.caption)
                                .foregroundStyle(RekonTheme.secondaryText)
                                .lineLimit(2)
                            Text("\(goal.lifecycle.displayName) · \(goal.ticketIDs.count) assigned · \(goal.doneCriteria.count) done criteria")
                                .font(.caption2)
                                .foregroundStyle(RekonTheme.secondaryText)
                            if let coverage = goal.coverage {
                                Text(coverageSummary(coverage))
                                    .font(.caption)
                                    .foregroundStyle(coverage.isAcceptanceEligible ? RekonTheme.success : RekonTheme.secondaryText)
                                    .accessibilityIdentifier("delivery-goal-coverage-\(goal.goalID.rawValue)")
                            }
                        }
                        Spacer(minLength: 8)
                        if goal.lifecycle != .accepted,
                           goal.lifecycle != .superseded,
                           phase.lifecycle.lifecycle != .completed,
                           loadDeliveryGoalEditor != nil {
                            Button("Edit") { openDeliveryGoalEditor(phase.id, goalID: goal.goalID) }
                                .buttonStyle(.link)
                                .disabled(roadmapLoadError != nil)
                                .accessibilityIdentifier("edit-delivery-goal-\(goal.goalID.rawValue)")
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func phaseTickets(_ phase: ProjectPlanPhaseProjection) -> some View {
        DisclosureGroup(isExpanded: $showsPhaseTickets) {
            VStack(alignment: .leading, spacing: 8) {
                if phase.tickets.isEmpty {
                    Text("No tickets are placed in this phase.")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                } else {
                    ForEach(phase.tickets) { ticket in
                        TicketCardView(
                            card: ticket,
                            presentation: .fullOutcome,
                            isSelected: selectedPlanTicketID == ticket.id
                        ) { selectTicket(ticket.id, phaseID: phase.id) }
                        .focusable()
                        .focused($focusedTicketID, equals: ticket.id)
                        .accessibilityFocused($accessibilityFocusedTicketID, equals: ticket.id)
                        .id("project-plan-ticket-scroll-\(ticket.id.rawValue)")
                    }
                }
                if let selectedPlanTicketID,
                   phase.tickets.contains(where: { $0.id == selectedPlanTicketID }),
                   let detail = plan.detail(for: selectedPlanTicketID) {
                    ticketDetail(detail)
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Ticket assignments · \(phase.ticketCount)")
                .font(.headline)
        }
        .accessibilityIdentifier("project-plan-phase-tickets-\(phase.id.rawValue)")
    }

    @ViewBuilder
    private func phaseNavigationActions(_ phase: ProjectPlanPhaseProjection) -> some View {
        Button("Open phase board") { openPhase(phase.id) }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityLabel("Open \(phase.name) phase board")
        if let openDependencies {
            Button("View dependencies") {
                let ticket = selectedPlanTicketID.flatMap { selected in
                    phase.tickets.contains(where: { $0.id == selected }) ? selected : nil
                }
                openDependencies(ticket)
            }
            .buttonStyle(RekonSecondaryButtonStyle())
            .accessibilityIdentifier("open-phase-dependencies-\(phase.id.rawValue)")
        }
    }

    private var planChanges: some View {
        DisclosureGroup(isExpanded: $showsPlanChanges) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review a saved version before deciding. Approval does not change the plan; Apply is separate.")
                    .font(.caption)
                    .foregroundStyle(RekonTheme.secondaryText)
                ForEach(plan.proposals) { proposal in proposalRow(proposal) }
                if let selectedProposal { proposalInspector(proposal: selectedProposal.proposal, version: selectedProposal.version) }
            }
            .padding(.top, 8)
        } label: {
            sectionHeading("Plan changes", count: plan.proposals.count)
        }
    }

    private func technicalRecord(for phase: ProjectPlanPhaseProjection) -> some View {
        DisclosureGroup(isExpanded: $showsTechnicalRecord) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Phase ID: \(phase.id.rawValue)")
                Text("Plan revision: \(phase.readiness.revision)")
                Text("Lifecycle revision: \(phase.lifecycle.revision)")
                Text(readinessSummary(phase.readiness))
                if phase.completionAssessment.blockers.isEmpty {
                    Text("No completion blockers recorded.")
                } else {
                    ForEach(phase.completionAssessment.blockers) { blocker in
                        Text("• \(blocker.message)")
                    }
                }
                ForEach(phase.deliveryGoals) { goal in
                    if let coverage = goal.coverage {
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
            }
            .font(.caption)
            .foregroundStyle(RekonTheme.secondaryText)
            .padding(.top, 8)
        } label: {
            Text("Technical record").font(.headline)
        }
        .accessibilityIdentifier("project-plan-phase-technical-record-\(phase.id.rawValue)")
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
            phasePlanFinalizationNeedsReload = finalizationRequiresReload(error)
            let message = phasePlanFinalizationErrorMessage(error)
            phasePlanFinalizationMessage = if finalizationRequiresReload(error), let readback {
                "\(message) Current saved revision: \(readback.revision)."
            } else {
                message
            }
        case let .unconfirmed(error):
            phasePlanFinalizationFailure = nil
            phasePlanFinalizationNeedsReload = false
            phasePlanFinalizationMessage = phasePlanFinalizationErrorMessage(error)
        }
    }

    private func focusFinalizationTicket(_ ticketID: TicketID) {
        selectedPlanTicketID = ticketID
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
                        .disabled(roadmapLoadError != nil)
                        .accessibilityIdentifier("create-delivery-goal-for-finalization-\(phase.id.rawValue)")
                }
                ForEach(failure.incompleteGoalIDs, id: \.self) { goalID in
                    Button("Complete Delivery Goal \(goalID.rawValue)") {
                        openDeliveryGoalEditor(phase.id, goalID: goalID)
                    }
                    .buttonStyle(.link)
                    .disabled(roadmapLoadError != nil)
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
            selectTicket(ticket.id)
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
            .background(selectedPlanTicketID == ticket.id ? RekonTheme.elevatedSurface : RekonTheme.surface,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(
                selectedPlanTicketID == ticket.id ? RekonTheme.accent : RekonTheme.border,
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
        } else if let selectedPlanTicketID,
                  let detail = plan.detail(for: selectedPlanTicketID) {
            ticketDetail(detail)
                .accessibilityIdentifier("project-plan-inspector")
        } else if let phase = selectedPhase {
            phaseDetail(phase)
                .accessibilityIdentifier("project-plan-phase-inspector-\(phase.id.rawValue)")
        } else {
            ContentUnavailableView("Select a phase", systemImage: "rectangle.on.rectangle")
        }
    }

    private func ticketDetail(_ detail: TicketDetailProjection) -> some View {
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
            .disabled(isPerformingProposalAction || roadmapLoadError != nil)
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
            .disabled(isPerformingProposalAction || roadmapLoadError != nil)
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
            .disabled(isPerformingProposalAction || roadmapLoadError != nil)
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

    private var phaseLifecycleOrder: [PhaseLifecycle] {
        [.inDelivery, .upcoming, .unassessed, .completed]
    }

    private var orderedPhases: [ProjectPlanPhaseProjection] {
        phaseLifecycleOrder.flatMap { lifecycle in
            plan.phases.filter { $0.lifecycle.lifecycle == lifecycle }
        }
    }

    private var selectedPhase: ProjectPlanPhaseProjection? {
        guard let selectedPhaseID else { return nil }
        return plan.phases.first { $0.id == selectedPhaseID }
    }

    private func readinessName(_ state: PhasePlanState) -> String {
        switch state {
        case .legacyUnassessed: "Legacy unassessed"
        case .draft: "Draft"
        case .ready: "Ready"
        }
    }

    private func phaseProgressText(_ phase: ProjectPlanPhaseProjection) -> String {
        return "\(phase.deliveredOrAcceptedTicketCount) of \(phase.ticketCount) tickets delivered or accepted"
    }

    private func phaseProgressAccessibilityValue(_ phase: ProjectPlanPhaseProjection) -> String {
        return "\(phase.deliveredOrAcceptedTicketCount) of \(phase.ticketCount) tickets delivered or accepted; \(phase.acceptedTicketCount) accepted"
    }

    private func phaseRowAccessibilityValue(_ phase: ProjectPlanPhaseProjection) -> String {
        var parts = [phaseProgressText(phase)]
        if let gap = phaseGap(phase) { parts.append(gap) }
        if let action = recommendedAction(for: phase) { parts.append("action available: \(action)") }
        return parts.joined(separator: "; ")
    }

    private func phaseGap(_ phase: ProjectPlanPhaseProjection) -> String? {
        if phasePlanFinalizationRecovery?(phase.id) != nil {
            return "A finalization attempt still needs reconciliation"
        }
        if phasePlanFinalizationPhaseID == phase.id,
           let failure = phasePlanFinalizationFailure {
            if failure.incompleteGoalIDs.isEmpty,
               failure.unassignedTicketIDs.isEmpty,
               failure.conflictingTicketIDs.isEmpty {
                return "Finalization needs an actionable Delivery Goal"
            }
            return "Finalization validation found incomplete planning work"
        }
        let actionableGoals = phase.deliveryGoals.filter { $0.lifecycle != .superseded }
        if actionableGoals.isEmpty { return "No actionable Delivery Goal" }
        if phase.readiness.unassignedUpcomingCount > 0 {
            return "\(phase.readiness.unassignedUpcomingCount) upcoming ticket\(phase.readiness.unassignedUpcomingCount == 1 ? " is" : "s are") unassigned"
        }
        switch phase.readiness.state {
        case .legacyUnassessed:
            return "Plan readiness has not been assessed"
        case .draft:
            return "Draft plan needs readiness review"
        case .ready:
            break
        }
        if !phase.completionAssessment.blockers.isEmpty,
           phase.lifecycle.lifecycle == .inDelivery {
            return "\(phase.completionAssessment.blockers.count) completion blocker\(phase.completionAssessment.blockers.count == 1 ? "" : "s")"
        }
        return nil
    }

    private func recommendedAction(for phase: ProjectPlanPhaseProjection) -> String? {
        if phasePlanFinalizationRecovery?(phase.id) != nil { return "Reconcile finalization" }
        if phase.lifecycle.lifecycle == .completed { return nil }
        if phasePlanFinalizationPhaseID == phase.id,
           let failure = phasePlanFinalizationFailure {
            if failure.incompleteGoalIDs.isEmpty,
               failure.unassignedTicketIDs.isEmpty,
               failure.conflictingTicketIDs.isEmpty {
                return "Create Delivery Goal"
            }
            if !failure.incompleteGoalIDs.isEmpty { return "Complete Delivery Goal" }
            if !failure.unassignedTicketIDs.isEmpty { return "Edit assignments" }
            if !failure.conflictingTicketIDs.isEmpty { return "Resolve assignment conflicts" }
        }
        let actionableGoals = phase.deliveryGoals.filter { $0.lifecycle != .superseded }
        if actionableGoals.isEmpty { return "Create Delivery Goal" }
        if phase.readiness.unassignedUpcomingCount > 0 { return "Edit assignments" }
        switch phase.readiness.state {
        case .legacyUnassessed: return "Assess plan readiness"
        case .draft: return "Review plan"
        case .ready: return "Review lifecycle"
        }
    }

    private func finalizationUnavailableReason(_ phase: ProjectPlanPhaseProjection) -> String {
        if roadmapLoadError != nil { return "the roadmap must be refreshed" }
        if phase.lifecycle.lifecycle == .completed { return "the phase is completed" }
        if phase.readiness.state == .legacyUnassessed { return "plan readiness is unassessed" }
        return "the plan is already Ready"
    }

    private func phaseScrollID(_ phaseID: PhaseID) -> String {
        "project-plan-phase-scroll-\(phaseID.rawValue)"
    }

    private func selectPhase(_ phaseID: PhaseID) {
        selectedPhaseID = phaseID
        selectedPlanTicketID = nil
        selectedProposalID = nil
        selectedProposalVersion = nil
        showsTechnicalRecord = false
        showsPlanChanges = false
        showsPhaseTickets = false
        focusedPhaseID = phaseID
        accessibilityFocusedPhaseID = phaseID
        if usesCompactLayout {
            roadmapScrollRestorePosition = roadmapScrollPosition ?? phaseScrollID(phaseID)
            showsCompactPhaseDetail = true
            Task { @MainActor in
                await Task.yield()
                phaseDetailHeadingFocused = true
                accessibilityPhaseDetailHeadingFocused = true
            }
        }
    }

    private func selectTicket(_ ticketID: TicketID, phaseID: PhaseID? = nil) {
        selectedPlanTicketID = ticketID
        selectedTicketID = ticketID
        selectedProposalID = nil
        selectedProposalVersion = nil
        if let phaseID { selectedPhaseID = phaseID }
        focusChanged(.ticket(ticketID))
    }

    private func movePhaseSelection(from phaseID: PhaseID, direction: MoveCommandDirection) {
        guard let index = orderedPhases.firstIndex(where: { $0.id == phaseID }) else { return }
        let targetIndex: Int
        switch direction {
        case .up, .left: targetIndex = max(orderedPhases.startIndex, index - 1)
        case .down, .right: targetIndex = min(orderedPhases.index(before: orderedPhases.endIndex), index + 1)
        @unknown default: return
        }
        let target = orderedPhases[targetIndex]
        selectedPhaseID = target.id
        selectedPlanTicketID = nil
        selectedProposalID = nil
        selectedProposalVersion = nil
        focusedPhaseID = target.id
        accessibilityFocusedPhaseID = target.id
    }

    private func reconcilePhaseSelection() {
        if selectedPlanTicketID.flatMap({ plan.detail(for: $0) }) == nil {
            selectedPlanTicketID = nil
        }
        if let selectedPhaseID,
           plan.phases.contains(where: { $0.id == selectedPhaseID }) {
            return
        }
        selectedPhaseID = plan.project.activePhaseID.flatMap { activeID in
            plan.phases.first(where: { $0.id == activeID })?.id
        } ?? orderedPhases.first?.id
        if selectedPhaseID == nil { showsCompactPhaseDetail = false }
    }

    private func applyRequestedFocus(usesCompactLayout: Bool) {
        switch requestedFocus {
        case let .ticket(ticketID):
            guard plan.detail(for: ticketID) != nil else { return }
            selectedProposalID = nil
            selectedProposalVersion = nil
            selectedPlanTicketID = ticketID
            if let phase = plan.phases.first(where: { phase in
                phase.tickets.contains(where: { $0.id == ticketID })
            }) {
                selectedPhaseID = phase.id
                showsPhaseTickets = true
                if usesCompactLayout {
                    roadmapScrollRestorePosition = roadmapScrollPosition ?? phaseScrollID(phase.id)
                    showsCompactPhaseDetail = true
                }
            } else if plan.unassignedTickets.contains(where: { $0.id == ticketID }) {
                showsUnplacedWork = true
            } else if plan.retiredTickets.contains(where: { $0.id == ticketID }) {
                showsRetiredOriginals = true
            }
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
            showsPlanChanges = true
            if usesCompactLayout, selectedPhaseID != nil { showsCompactPhaseDetail = true }
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
        selectedProposalID = nil
        selectedProposalVersion = nil
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
           plan.detail(for: ticketID) != nil {
            if let phase = plan.phases.first(where: { phase in
                phase.tickets.contains(where: { $0.id == ticketID })
            }) {
                return ProjectPlanLayout.usesStackedInspector(forWidth: width)
                    ? nil
                    : phaseScrollID(phase.id)
            }
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
