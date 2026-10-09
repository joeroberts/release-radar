#!/usr/bin/env bash
# Emit complete changed paths as NUL-delimited repository-relative names.
# An unusable revision range deliberately emits no paths, which the classifier
# treats as its visible fail-closed fallback input.
set -euo pipefail

emit_diff() {
    local left="$1"
    local right="$2"
    local output

    output="$(mktemp)"
    trap 'rm -f "$output"' RETURN
    if git diff --no-renames --name-only -z "$left" "$right" > "$output"; then
        cat "$output"
    fi
}

case "${1:-}" in
    --pull-request)
        if [[ "$#" -ne 3 ]]; then exit 0; fi
        if base="$(git merge-base "$2" "$3")"; then
            emit_diff "$base" "$3"
        fi
        ;;
    --push)
        if [[ "$#" -ne 3 || "$2" =~ ^0+$ ]]; then exit 0; fi
        emit_diff "$2" "$3"
        ;;
    *)
        exit 0
        ;;
esac
