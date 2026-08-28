---
name: release-radar
description: Use when working in a repository tracked by Release Radar or when the owner asks to initialize or synchronize Release Radar tracking.
---

# Release Radar Tracking

1. Read the applicable repository instructions and existing durable tracking conventions before acting.
2. When the owner requests initialization and no tracking documentation exists, create only the minimum tracking documentation the owner requested.
3. Use typed Release Radar MCP tools for Release Radar reads and mutations; never access its SQLite storage directly.
4. In the same owner-directed workflow, update the repository documentation and the corresponding Release Radar state.
5. Read back and verify both postconditions. If either remains unverified, report the discrepancy instead of completion.
6. Never fabricate completion, review, acceptance, or authority.
