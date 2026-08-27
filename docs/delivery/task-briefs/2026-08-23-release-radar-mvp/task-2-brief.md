### Task 2 (RR-02): Add the transactional local delivery store

**Dependencies:** RR-01.

**Files:**

- Create: `ReleaseRadarCore/Models/DeliveryModels.swift`
- Create: `ReleaseRadarCore/Store/SQLiteConnection.swift`
- Create: `ReleaseRadarCore/Store/StoreMigrations.swift`
- Create: `ReleaseRadarCore/Store/DeliveryStore.swift`
- Create: `ReleaseRadarTests/StoreAcceptanceTests.swift`

**Interfaces produced:**

```swift
actor DeliveryStore {
    func transact<T>(
        actor: DeliveryActor,
        reason: String,
        _ body: (SQLiteConnection) throws -> T
    ) throws -> T
}

enum TicketLane: String, Codable, CaseIterable, Sendable {
    case backlog, inProgress, needsReview, blocked, accepted
}
```

- [ ] Define projects/roots, phases, tickets, phase/ticket dependencies, blockers, evidence, thread links/exclusions, observed threads/goals, review items, audit events, and notification events as distinct records with stable typed IDs.
- [ ] Write `StoreAcceptanceTests` first for one valid ticket transition that commits its attributed audit event, plus invalid reference, cross-project link, and dependency-cycle cases that leave both delivery and audit tables unchanged.
- [ ] Implement versioned migrations and the `DeliveryStore` actor using SQLite transactions, foreign keys, uniqueness constraints, and an application-support database URL. Before migration, preserve an atomic pre-migration snapshot. Corruption or migration failure keeps the original database intact and opens an explicit unavailable/recovery state; never silently delete or recreate authoritative state.
- [ ] Relaunch the store in the test and prove the valid record/audit survives while rejected writes do not appear.
- [ ] Run `xcodebuild test -project ReleaseRadar.xcodeproj -scheme ReleaseRadar -only-testing:ReleaseRadarTests/StoreAcceptanceTests`.
- [ ] Obtain independent code, QA, architecture, and security review; update the ledger and commit as `feat: add transactional delivery store`.

