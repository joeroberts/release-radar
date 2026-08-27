### Task 3 (RR-03): Expose one narrow agent action bridge

**Dependencies:** RR-02.

**Files:**

- Create: `ReleaseRadarCore/AgentBridge/AgentCommand.swift`
- Create: `ReleaseRadarCore/AgentBridge/AgentCommandDispatcher.swift`
- Create: `ReleaseRadarIntegration/AgentBridgeService.swift`
- Create: `ReleaseRadarAgentTools/main.swift`
- Create: `ReleaseRadarTests/AgentBridgeAcceptanceTests.swift`

**Interfaces produced:**

```swift
struct AgentCommandEnvelope: Codable, Sendable {
    let version: Int
    let requestID: UUID
    let projectRoot: String
    let assertedThreadID: String?
    let reason: String
    let command: AgentCommand
}

struct AgentCommandResult: Codable, Sendable {
    let entityIDs: [String]
    let auditEventID: AuditEventID?
    let error: AgentCommandError?
}
```

- [ ] Implement the approved commands only: phase/ticket upsert, ticket transition, dependency set, blocker record/resolve, evidence add, thread link, review request, completion record, and import-review resolve/dismiss.
- [ ] First prove the one concrete transport works from the sandboxed signed configuration: MCP JSON-RPC over stdio in `ReleaseRadarAgentTools`, forwarded through one bounded same-user local bridge to the running app. Authenticate the packaged signed peer by audit token/designated requirement or equivalent and fail closed on identity or protocol-version mismatch. The bridge never opens SQLite and has no generic shell, filesystem, URL, or arbitrary JSON-RPC method.
- [ ] Require version, bounded payload, reason, and a durably idempotent request ID. Resolve `projectRoot` to an onboarded canonical bookmark-backed project rather than trusting the supplied string. Evidence URLs must resolve within an authorized project/worktree root. Treat agent thread attribution as asserted unless the read-only observer verifies the thread belongs to that project.
- [ ] Write one integration scenario proving a valid command commits delivery state and audit ID, while invalid reference/cross-project/cycle commands return structured errors with full rollback; app unavailable returns `appUnavailable` and never writes elsewhere.
- [ ] Run the focused bridge test target, perform independent review, update the ledger, and commit as `feat: add typed agent delivery actions`.

