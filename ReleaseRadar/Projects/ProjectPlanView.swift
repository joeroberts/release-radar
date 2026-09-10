import ReleaseRadarCore
import RekonDesignSystem
import SwiftUI

enum ProjectPlanLayout {
    static func usesStackedInspector(forWidth width: CGFloat) -> Bool { width < 1_100 }
}

struct ProjectPlanView: View {
    let plan: ProjectPlanProjection
    @Binding var selectedTicketID: TicketID
    let openAllPhases: () -> Void
    let openPhase: (PhaseID) -> Void
    var documentationStatus: DocumentationObservationStatus? = nil
    var loadEvidencePreview: ((EvidenceID) async -> EvidencePreview)? = nil
    var loadTicketReferences: ((TicketID) async -> ReferenceLoadResult<TicketReferenceSet>)? = nil
    var openReferenceSource: ((TicketID, String, Int64) -> Void)? = nil
    var decideProposal: ((PlanChangeProposalID, Int64, String, PlanChangeDecisionDisposition) async -> AgentCommandResult)? = nil
    var applyProposal: ((PlanChangeProposalID, Int64, String, String) async -> AgentCommandResult)? = nil
    var refreshProposal: ((PlanChangeProposalID, Int64, String, [PlanChangeOperation]) async -> AgentCommandResult)? = nil
    var transitionPhaseLifecycle: ((PhaseID, Int64, PhaseLifecycleAction, String?, String) async -> AgentCommandResult)? = nil
    var reloadPhaseLifecycle: (() async -> Void)? = nil
    var referenceContextIdentity: String? = nil
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
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) { heading; Spacer(); allPhasesButton }
            VStack(alignment: .leading, spacing: 12) { heading; allPhasesButton }
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
                openReferenceSource: openReferenceSource.map { opener in
                    { linkID, version in opener(detail.id, linkID, version) }
                },
                referenceContextIdentity: referenceContextIdentity
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
