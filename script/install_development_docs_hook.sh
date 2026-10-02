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
source_agent_hook="$repo_root/.codex/hooks/block_no_verify_commit.py"
hooks_path=$(git rev-parse --git-path hooks 2>/dev/null) || fail "could not resolve this repository's hooks directory"
target_hook="$hooks_path/pre-commit"
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || fail "could not resolve this repository's shared Git directory"
agent_hooks_path="$common_dir/hooks"
target_agent_hook="$agent_hooks_path/block_no_verify_commit.py"
temporary_hook=''
temporary_agent_hook=''

[[ -f "$source_hook" ]] || fail "checked-in hook is unavailable at $source_hook"
[[ -f "$source_agent_hook" ]] || fail "checked-in Codex hook handler is unavailable at $source_agent_hook"

cleanup_temporary_hook() {
    [[ -z "$temporary_hook" ]] || rm -f -- "$temporary_hook"
    [[ -z "$temporary_agent_hook" ]] || rm -f -- "$temporary_agent_hook"
}

matches_source() {
    [[ -f "$2" && -x "$2" ]] && cmp -s "$1" "$2"
}

case "$1" in
    --status)
        if matches_source "$source_hook" "$target_hook" && matches_source "$source_agent_hook" "$target_agent_hook"; then
            printf 'installed: development documentation and Codex hook handlers at %s and %s\n' "$target_hook" "$target_agent_hook"
            exit 0
        fi
        if [[ -e "$target_agent_hook" || -L "$target_agent_hook" ]]; then
            fail "not installed: existing Codex hook handler at $target_agent_hook is preserved"
        fi
        if [[ -e "$target_hook" || -L "$target_hook" ]]; then
            fail "not installed: existing pre-commit hook at $target_hook is preserved"
        fi
        fail "not installed: no development documentation or Codex hook handlers are installed"
        ;;
    --install)
        if [[ -e "$target_hook" || -L "$target_hook" ]] && ! matches_source "$source_hook" "$target_hook"; then
            fail "existing pre-commit hook at $target_hook will not be overwritten"
        fi
        if [[ -e "$target_agent_hook" || -L "$target_agent_hook" ]] && ! matches_source "$source_agent_hook" "$target_agent_hook"; then
            fail "existing Codex hook handler at $target_agent_hook will not be overwritten"
        fi
        mkdir -p "$hooks_path" || fail "could not create hooks directory at $hooks_path"
        mkdir -p "$agent_hooks_path" || fail "could not create shared hooks directory at $agent_hooks_path"
        trap cleanup_temporary_hook EXIT
        if ! matches_source "$source_hook" "$target_hook"; then
            temporary_hook=$(mktemp "$hooks_path/.development-docs-pre-commit.XXXXXX") || fail "could not prepare hook installation in $hooks_path"
            cp "$source_hook" "$temporary_hook" || fail "could not prepare hook installation in $hooks_path"
            chmod +x "$temporary_hook" || fail "could not make prepared hook executable"
            ln "$temporary_hook" "$target_hook" || fail "existing pre-commit hook at $target_hook will not be overwritten"
        fi
        if ! matches_source "$source_agent_hook" "$target_agent_hook"; then
            temporary_agent_hook=$(mktemp "$agent_hooks_path/.block-no-verify-commit.XXXXXX") || fail "could not prepare Codex hook handler in $agent_hooks_path"
            cp "$source_agent_hook" "$temporary_agent_hook" || fail "could not prepare Codex hook handler in $agent_hooks_path"
            chmod +x "$temporary_agent_hook" || fail "could not make prepared Codex hook handler executable"
            ln "$temporary_agent_hook" "$target_agent_hook" || fail "existing Codex hook handler at $target_agent_hook will not be overwritten"
        fi
        if ! matches_source "$source_hook" "$target_hook" || ! matches_source "$source_agent_hook" "$target_agent_hook"; then
            fail 'installed hook handlers did not match their checked-in executable sources'
        fi
        printf 'installed: development documentation and Codex hook handlers at %s and %s\n' "$target_hook" "$target_agent_hook"
        ;;
    *)
        usage
        ;;
esac
