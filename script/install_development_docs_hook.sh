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
hooks_path=$(git rev-parse --git-path hooks 2>/dev/null) || fail 'could not resolve this repository\'s hooks directory'
target_hook="$hooks_path/pre-commit"

[[ -f "$source_hook" ]] || fail "checked-in hook is unavailable at $source_hook"

case "$1" in
    --status)
        if [[ -f "$target_hook" ]] && cmp -s "$source_hook" "$target_hook"; then
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
        cp "$source_hook" "$target_hook" || fail "could not install hook at $target_hook"
        chmod +x "$target_hook" || fail "could not make hook executable at $target_hook"
        printf 'installed: development documentation hook at %s\n' "$target_hook"
        ;;
    *)
        usage
        ;;
esac
