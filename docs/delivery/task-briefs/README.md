# Tracked task briefs

This directory contains the durable, tracked copies of Release Radar task
briefs that were accepted or cited as controlling during delivery.

- `docs/delivery/progress.md` remains the sole authority for current status,
  dependency gates, sequencing, and task eligibility.
- A brief records the reviewed scope for a task; its presence does not mean the
  task is currently open.
- Completed or superseded briefs remain here as historical delivery contracts.
- New controlling briefs must be placed here before implementation begins and
  must not be cited from `/tmp`, `.superpowers/sdd/`, or another ignored path.
- `SHA256SUMS` records the checksum of every retained task brief.
