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
    var referenceContextIdentity: String? = nil
    var requestedFocus: NavigationFocus? = nil
    var focusChanged: (NavigationFocus?) -> Void = { _ in }
    @FocusState private var focusedTicketID: TicketID?
    @AccessibilityFocusState private var accessibilityFocusedTicketID: TicketID?

    var body: some View {
        GeometryReader { geometry in
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
        }
        .background(RekonTheme.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan")
        .onChange(of: requestedFocus) { _, _ in applyRequestedFocus() }
        .task { applyRequestedFocus() }
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
            sectionHeading("Recorded phases", count: plan.phases.count)
            if plan.phases.isEmpty {
                ContentUnavailableView("No phases recorded", systemImage: "list.bullet.rectangle")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(plan.phases) { phase in phaseCard(phase) }
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
                            selectedTicketID = card.id
                            focusChanged(.ticket(card.id))
                        }
                        .focusable()
                        .focused($focusedTicketID, equals: card.id)
                        .accessibilityFocused($accessibilityFocusedTicketID, equals: card.id)
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
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(RekonTheme.border, lineWidth: RekonBorder.hairline) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("project-plan-phase-\(phase.id.rawValue)")
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
        if let detail = plan.detail(for: selectedTicketID) ?? plan.unassignedDetails.values.sorted(by: { $0.id.rawValue < $1.id.rawValue }).first {
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

    private func readinessSummary(_ readiness: PhasePlanProjection) -> String {
        let state = switch readiness.state {
        case .legacyUnassessed: "Legacy unassessed"
        case .draft: "Draft"
        case .ready: "Ready"
        }
        return "\(state) · revision \(readiness.revision) · \(readiness.coveredUpcomingCount)/\(readiness.upcomingCount) covered"
    }

    private func applyRequestedFocus() {
        guard case let .ticket(ticketID) = requestedFocus,
              plan.detail(for: ticketID) != nil else { return }
        focusedTicketID = ticketID
        accessibilityFocusedTicketID = ticketID
    }
}
