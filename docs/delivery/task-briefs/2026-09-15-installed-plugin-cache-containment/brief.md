# Installed plugin cache containment

Restore ADR-002's installed-cache read boundary in the production lifecycle
helper. Main released this separate security fix after independent read-only
findings reconciled with the writer's trace. Broader Outcome 3 remains excluded.

The reader must anchor the effective-user home, walk only fixed cache components
and the validated version with descriptor-relative no-follow opens, retain and
validate directory links, and read stable regular package files once from their
descriptors. Preserve legacy three-file and current four-file recognition,
harmless empty directories, current manifest/MCP permissiveness, UTF-8 digest
ordering and framing, and existing status/error mapping.

Scope is helper-local reader extraction and containment, actual-reader native
synthetic tests, the owning mutable design note and catalog/index maintenance.
No Core linkage, caller-selected production roots, XPC changes, owner cache or
credentials access, app execution/state mutation, broad refactor, governing-file
or accepted ADR changes, configuration changes or publication is authorized.

Risks are symlink traversal, ancestor/entry replacement, transient reads outside
the fixed root, nonregular files blocking reads, unstable bytes and digest/status
regressions. Open directories with `O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`, files
with `O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC`; compare entry and handle metadata
before opens and after the snapshot. Preserve bytes for validation and hashing.

Use native Swift/XCTest on the production reader without helper/XPC startup.
Tests start with a failing original-trigger fixture. Synthetic homes cover both
inventories and creation orders, symlinks at fixed/package/file components with
no target reads, missing/extra/nonregular files, FIFO, version mismatch,
deterministic replacement/restoration and same-size mutations, read errors,
sibling/config sentinels and path-free errors. No new validation framework.

Acceptance requires containment and stability tests passing, compatible frozen
synthetic digests, unchanged caller mapping, repository documentation checks and
one independent code/security review arranged by Main/RO04. Required corrections
retain this scope; optional recommendations do not block.

Writer owns the helper reader, focused tests and affected docs on
`codex/installed-plugin-cache-containment`, baseline
`54b93756984af955e1cd654cf2d3eefccd78ba6a`, root
`/Users/jroberts/.codex/worktrees/63ab/release_radar`. Assigned Sol/high under the
restricted runtime; no escalation beyond the assigned profile without a named
blocker. Main owns programme state and independent-review dispatch.

[ADR-002](../../../architecture/ADR-002-codex-plugin-lifecycle.md) supplies the
accepted boundary; the [mutable lifecycle design](../../../design/release-radar-codex-plugin-lifecycle-design.md)
owns current specifications. Existing helper status, install preflight and
postcondition consumers retain their contracts. No persistence migration or
public compatibility/recovery change is intended.

Endpoint is scoped local commit, focused native checks and independent review.
No packaging, installation, push, PR, merge, app binding/catalog acceptance or
other owner/external state mutation. Changed catalog metadata remains pending
application acceptance; repository check success does not establish app state.
