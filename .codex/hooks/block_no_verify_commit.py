#!/usr/bin/env python3
"""Block direct Git commits that deliberately skip repository hooks."""

import json
import shlex
import sys


SHELL_OPERATORS = {";", "&&", "||", "|", "&", "(", ")", "<", ">", ">>", "<<"}
BYPASS_OPTIONS = {"--no-verify", "-n"}


def bypasses_pre_commit(command: object) -> bool:
    """Return whether command is one unambiguous Git commit hook bypass."""
    if not isinstance(command, str) or not command:
        return False

    try:
        arguments = shlex.split(command, posix=True)
    except ValueError:
        return False

    if len(arguments) < 3 or arguments[:2] != ["git", "commit"]:
        return False
    if any(argument in SHELL_OPERATORS for argument in arguments):
        return False

    try:
        end_of_options = arguments.index("--", 2)
    except ValueError:
        end_of_options = len(arguments)

    return any(argument in BYPASS_OPTIONS for argument in arguments[2:end_of_options])


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError, TypeError):
        return

    tool_input = event.get("tool_input") if isinstance(event, dict) else None
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not bypasses_pre_commit(command):
        return

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "git commit --no-verify bypasses this repository's pre-commit validation. "
                    "Commit without --no-verify so the staged checks can run."
                ),
            }
        },
        sys.stdout,
    )


if __name__ == "__main__":
    main()
