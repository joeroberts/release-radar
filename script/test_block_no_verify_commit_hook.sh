#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
handler="$repo_root/.codex/hooks/block_no_verify_commit.py"
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

failures=0

run_handler() {
  local name=$1
  local input=$2
  set +e
  printf '%s' "$input" | /usr/bin/env python3 "$handler" >"$fixture_root/$name.stdout" 2>"$fixture_root/$name.stderr"
  local status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    printf 'FAIL %s: expected exit 0, got %s\n' "$name" "$status" >&2
    failures=$((failures + 1))
  fi
}

expect_deny() {
  local name=$1
  local input=$2
  run_handler "$name" "$input"
  if ! /usr/bin/env python3 - "$fixture_root/$name.stdout" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as output:
    actual = json.load(output)

assert actual == {
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            "git commit --no-verify bypasses this repository's pre-commit validation. "
            "Commit without --no-verify so the staged checks can run."
        ),
    }
}
PY
  then
    printf 'FAIL %s: expected documented PreToolUse denial\n' "$name" >&2
    failures=$((failures + 1))
  else
    printf 'PASS %s\n' "$name"
  fi
}

expect_allow() {
  local name=$1
  local input=$2
  run_handler "$name" "$input"
  if [[ -s "$fixture_root/$name.stdout" || -s "$fixture_root/$name.stderr" ]]; then
    printf 'FAIL %s: expected pass-through with no output\n' "$name" >&2
    failures=$((failures + 1))
  else
    printf 'PASS %s\n' "$name"
  fi
}

expect_deny no_verify '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify -m test"}}'
expect_deny short_no_verify '{"tool_name":"Bash","tool_input":{"command":"git commit -n -m test"}}'
expect_allow ordinary_commit '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
expect_allow quoted_option_value "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m '--no-verify'\"}}"
expect_allow push '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
expect_allow option_after_separator '{"tool_name":"Bash","tool_input":{"command":"git commit -- --no-verify"}}'
expect_allow compound_command '{"tool_name":"Bash","tool_input":{"command":"git commit --no-verify && echo afterward"}}'
expect_deny quoted_semicolon_option_value "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit --no-verify -m ';'\"}}"
expect_allow missing_command '{"tool_name":"Bash","tool_input":{}}'
expect_allow unknown_input '{"tool_name":"Bash","tool_input":[]}'
expect_allow malformed_json '{'

if [[ $failures -ne 0 ]]; then
  exit 1
fi
