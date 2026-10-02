#!/usr/bin/env python3
"""Block direct Git commits that deliberately skip repository hooks."""

import json
import shlex
import sys


BYPASS_OPTIONS = {"--no-verify", "-n"}
OPTIONS_WITH_VALUES = {
    "-m",
    "--message",
    "-F",
    "--file",
    "-t",
    "--template",
    "-C",
    "--reuse-message",
    "-c",
    "--reedit-message",
    "--author",
    "--date",
    "--cleanup",
    "--trailer",
    "--pathspec-from-file",
}


def has_unquoted_shell_operator(command: str) -> bool:
    quote = None
    escaped = False
    for character in command:
        if escaped:
            escaped = False
        elif character == "\\" and quote != "'":
            escaped = True
        elif quote:
            if character == quote:
                quote = None
        elif character in {"'", '"'}:
            quote = character
        elif character in ";|&()<>":
            return True
    return quote is not None


def bypasses_pre_commit(command: object) -> bool:
    """Return whether command is one unambiguous Git commit hook bypass."""
    if not isinstance(command, str) or not command:
        return False

    try:
        arguments = shlex.split(command, posix=True)
    except ValueError:
        return False

    if len(arguments) < 3 or arguments[:2] != ["git", "commit"] or has_unquoted_shell_operator(command):
        return False

    try:
        end_of_options = arguments.index("--", 2)
    except ValueError:
        end_of_options = len(arguments)

    index = 2
    while index < end_of_options:
        argument = arguments[index]
        if argument in BYPASS_OPTIONS:
            return True
        index += 2 if argument in OPTIONS_WITH_VALUES else 1
    return False


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
