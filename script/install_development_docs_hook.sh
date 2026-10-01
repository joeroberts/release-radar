#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s (--install | --status)\n' "${0##*/}" >&2
    exit 64
}

fail() {
    printf 'error: development documentation hook: %s\n' "$*" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || fail 'run this command from a Git working tree'
source_hook="$repo_root/.githooks/pre-commit"
hooks_path=$(git rev-parse --git-path hooks 2>/dev/null) || fail "could not resolve this repository's hooks directory"
target_hook="$hooks_path/pre-commit"
temporary_hook=''

[[ -f "$source_hook" ]] || fail "checked-in hook is unavailable at $source_hook"

cleanup_temporary_hook() {
    [[ -z "$temporary_hook" ]] || rm -f -- "$temporary_hook"
}

case "$1" in
    --status)
        if [[ -f "$target_hook" && -x "$target_hook" ]] && cmp -s "$source_hook" "$target_hook"; then
            printf 'installed: development documentation hook at %s\n' "$target_hook"
            exit 0
        fi
        if [[ -e "$target_hook" || -L "$target_hook" ]]; then
            fail "not installed: existing pre-commit hook at $target_hook is preserved"
        fi
        fail "not installed: no pre-commit hook at $target_hook"
        ;;
    --install)
        if [[ -e "$target_hook" || -L "$target_hook" ]]; then
            fail "existing pre-commit hook at $target_hook will not be overwritten"
        fi
        mkdir -p "$hooks_path" || fail "could not create hooks directory at $hooks_path"
        temporary_hook=$(mktemp "$hooks_path/.development-docs-pre-commit.XXXXXX") || fail "could not prepare hook installation in $hooks_path"
        trap cleanup_temporary_hook EXIT
        cp "$source_hook" "$temporary_hook" || fail "could not prepare hook installation in $hooks_path"
        chmod +x "$temporary_hook" || fail "could not make prepared hook executable"
        ln "$temporary_hook" "$target_hook" || fail "existing pre-commit hook at $target_hook will not be overwritten"
        if ! [[ -x "$target_hook" ]] || ! cmp -s "$source_hook" "$target_hook"; then
            fail "installed hook at $target_hook did not match the checked-in executable hook"
        fi
        printf 'installed: development documentation hook at %s\n' "$target_hook"
        ;;
    *)
        usage
        ;;
esac
