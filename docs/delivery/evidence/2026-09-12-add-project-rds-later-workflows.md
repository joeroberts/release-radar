# Add Project RDS later-workflow correction

The owner-reported 0.1.14 screenshot showed that RDS styling stopped at the Add
Project landing screen. The Initialize and Attach workflows still used native
SwiftUI controls after entering the wizard.

Candidate `39ca6bc2385d957aabc052545d94116280e711a3` applies existing pinned
RDS primary, secondary, borderless-icon, quiet-text-field, checkbox and picker
components to application-owned workflow controls. It does not change the macOS
folder chooser, window traffic lights, action handlers, authorization, data
semantics, keyboard shortcuts, identifiers or disabled predicates. Duplicate
Attach-project names are mapped through unique visible labels back to their exact
project IDs. Once a folder is selected, the selector is a disabled RDS field;
the native accessibility check confirms it is not interactive.

## Verification

- Focused XCTest passed: landing contract, later-control style regression,
  default/minimum full native windows, and original RDS chrome test.
- Full native captures cover Initialize selection at [default](2026-09-12-add-project-initialize-default.png)
  and [minimum](2026-09-12-add-project-initialize-minimum.png) sizes; the
  confirmation fixture includes a task checkbox and recognized-artifact checkbox.
- Attach captures cover [confirmation at default](2026-09-12-add-project-attach-confirmation-default.png)
  and [minimum](2026-09-12-add-project-attach-confirmation-minimum.png) sizes,
  plus the [empty/error state](2026-09-12-add-project-attach-empty-default.png).
- One fresh independent Terra/high code-and-UX review found two Required issues
  (unstyled selection controls and the picker’s disabled-state propagation).
  Both bounded corrections were re-reviewed with no Required or Optional findings.

No RDS-library, owner-data, folder-authorization, remote, PR, merge,
notarization or publication action occurred in this correction.
