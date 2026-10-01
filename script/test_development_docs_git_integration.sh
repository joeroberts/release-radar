#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

failures=0

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

expect_status() {
  local expected=$1
  local name=$2
  shift 2
  set +e
  "$@" >"$fixture_root/$name.stdout" 2>"$fixture_root/$name.stderr"
  local actual=$?
  set -e
  if [[ $actual -ne $expected ]]; then
    fail "$name: expected exit $expected, got $actual"
  else
    printf 'PASS %s\n' "$name"
  fi
}

expect_diagnostic() {
  local name=$1
  local pattern=$2
  if ! grep -Eqi "$pattern" "$fixture_root/$name.stderr"; then
    fail "$name: expected actionable diagnostic matching $pattern"
  fi
}

new_repo() {
  local name=$1
  local repo="$fixture_root/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name 'QA Fixture'
  git -C "$repo" config user.email 'qa@example.invalid'
  mkdir -p "$repo/script" "$repo/.githooks" "$repo/docs/delivery"
  cp "$repo_root/script/check_development_docs.swift" "$repo/script/"
  cp "$repo_root/.githooks/pre-commit" "$repo/.githooks/"
  cp "$repo_root/script/install_development_docs_hook.sh" "$repo/script/"
  chmod +x "$repo/.githooks/pre-commit" "$repo/script/install_development_docs_hook.sh"
  printf '%s' "$repo"
}

install_hook() {
  local repo=$1
  (cd "$repo" && ./script/install_development_docs_hook.sh --install)
}

commit() {
  local repo=$1
  local message=$2
  (cd "$repo" && git commit -qm "$message")
}

expect_file() {
  [[ -f "$1" ]] || fail "required artifact is missing: $1"
}

expect_file "$repo_root/.githooks/pre-commit"
expect_file "$repo_root/script/install_development_docs_hook.sh"
expect_file "$repo_root/.github/workflows/development-documentation.yml"

if [[ $failures -eq 0 ]]; then
  valid_staged_invalid_unstaged=$(new_repo valid-staged-invalid-unstaged)
  printf 'valid staged snapshot\n' >"$valid_staged_invalid_unstaged/docs/delivery/progress.md"
  git -C "$valid_staged_invalid_unstaged" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$valid_staged_invalid_unstaged"
  printf 'x\n%.0s' {1..61} >"$valid_staged_invalid_unstaged/docs/delivery/progress.md"
  expect_status 0 valid_staged_invalid_unstaged commit "$valid_staged_invalid_unstaged" valid-staged

  invalid_staged_valid_unstaged=$(new_repo invalid-staged-valid-unstaged)
  printf 'x\n%.0s' {1..61} >"$invalid_staged_valid_unstaged/docs/delivery/progress.md"
  git -C "$invalid_staged_valid_unstaged" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$invalid_staged_valid_unstaged"
  printf 'valid unstaged content\n' >"$invalid_staged_valid_unstaged/docs/delivery/progress.md"
  expect_status 1 invalid_staged_valid_unstaged commit "$invalid_staged_valid_unstaged" invalid-staged
  expect_diagnostic invalid_staged_valid_unstaged 'has 61 lines|reduce it to 60'

  missing_progress=$(new_repo missing-progress)
  printf 'ordinary change\n' >"$missing_progress/README.md"
  git -C "$missing_progress" add README.md script/check_development_docs.swift
  install_hook "$missing_progress"
  expect_status 1 missing_progress commit "$missing_progress" missing-progress
  expect_diagnostic missing_progress 'staged docs/delivery/progress\.md is unavailable'

  staged_symlink=$(new_repo staged-symlink)
  printf 'valid target\n' >"$staged_symlink/valid-progress.md"
  ln -s ../../valid-progress.md "$staged_symlink/docs/delivery/progress.md"
  git -C "$staged_symlink" add valid-progress.md docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$staged_symlink"
  expect_status 1 staged_symlink commit "$staged_symlink" staged-symlink
  expect_diagnostic staged_symlink 'progress\.md must be a regular file'

  root_symlink="$fixture_root/root-symlink"
  mkdir -p "$root_symlink/docs/delivery"
  printf 'valid target\n' >"$root_symlink/valid-progress.md"
  ln -s ../../valid-progress.md "$root_symlink/docs/delivery/progress.md"
  expect_status 1 root_symlink swift "$repo_root/script/check_development_docs.swift" --root "$root_symlink"
  expect_diagnostic root_symlink 'regular|symlink|progress|file'

  root_nonregular="$fixture_root/root-nonregular"
  mkdir -p "$root_nonregular/docs/delivery/progress.md"
  expect_status 1 root_nonregular swift "$repo_root/script/check_development_docs.swift" --root "$root_nonregular"
  expect_diagnostic root_nonregular 'regular|progress|read|file'

  deleted_progress=$(new_repo deleted-progress)
  printf 'valid baseline\n' >"$deleted_progress/docs/delivery/progress.md"
  git -C "$deleted_progress" add docs/delivery/progress.md script/check_development_docs.swift
  commit "$deleted_progress" baseline
  install_hook "$deleted_progress"
  rm "$deleted_progress/docs/delivery/progress.md"
  git -C "$deleted_progress" add -u docs/delivery/progress.md
  expect_status 1 deleted_progress commit "$deleted_progress" deleted-progress
  expect_diagnostic deleted_progress 'staged docs/delivery/progress\.md is unavailable'

  unchanged_invalid=$(new_repo unchanged-invalid)
  printf 'x\n%.0s' {1..61} >"$unchanged_invalid/docs/delivery/progress.md"
  git -C "$unchanged_invalid" add docs/delivery/progress.md script/check_development_docs.swift
  commit "$unchanged_invalid" invalid-baseline
  install_hook "$unchanged_invalid"
  printf 'ordinary change\n' >"$unchanged_invalid/README.md"
  git -C "$unchanged_invalid" add README.md
  expect_status 1 unchanged_invalid commit "$unchanged_invalid" unchanged-invalid
  expect_diagnostic unchanged_invalid 'has 61 lines|reduce it to 60'

  staged_invalid_unstaged_noop_validator=$(new_repo staged-invalid-unstaged-noop-validator)
  printf 'x\n%.0s' {1..61} >"$staged_invalid_unstaged_noop_validator/docs/delivery/progress.md"
  git -C "$staged_invalid_unstaged_noop_validator" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$staged_invalid_unstaged_noop_validator"
  printf 'import Foundation\n' >"$staged_invalid_unstaged_noop_validator/script/check_development_docs.swift"
  expect_status 1 staged_invalid_unstaged_noop_validator commit "$staged_invalid_unstaged_noop_validator" staged-invalid
  expect_diagnostic staged_invalid_unstaged_noop_validator 'has 61 lines|reduce it to 60'

  staged_valid_unstaged_broken_validator=$(new_repo staged-valid-unstaged-broken-validator)
  printf 'valid staged progress\n' >"$staged_valid_unstaged_broken_validator/docs/delivery/progress.md"
  git -C "$staged_valid_unstaged_broken_validator" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$staged_valid_unstaged_broken_validator"
  printf 'this is not Swift\n' >"$staged_valid_unstaged_broken_validator/script/check_development_docs.swift"
  expect_status 0 staged_valid_unstaged_broken_validator commit "$staged_valid_unstaged_broken_validator" staged-valid

  staged_missing_validator=$(new_repo staged-missing-validator)
  printf 'valid staged progress\n' >"$staged_missing_validator/docs/delivery/progress.md"
  git -C "$staged_missing_validator" add docs/delivery/progress.md
  install_hook "$staged_missing_validator"
  expect_status 1 staged_missing_validator commit "$staged_missing_validator" staged-missing-validator
  expect_diagnostic staged_missing_validator 'validator|staged|missing|unavailable'

  staged_symlink_validator=$(new_repo staged-symlink-validator)
  printf 'valid staged progress\n' >"$staged_symlink_validator/docs/delivery/progress.md"
  mv "$staged_symlink_validator/script/check_development_docs.swift" "$staged_symlink_validator/script/check_development_docs.swift.real"
  ln -s check_development_docs.swift.real "$staged_symlink_validator/script/check_development_docs.swift"
  git -C "$staged_symlink_validator" add docs/delivery/progress.md script/check_development_docs.swift script/check_development_docs.swift.real
  install_hook "$staged_symlink_validator"
  expect_status 1 staged_symlink_validator commit "$staged_symlink_validator" staged-symlink-validator
  expect_diagnostic staged_symlink_validator 'validator|regular|symlink|staged'

  unavailable_swift=$(new_repo unavailable-swift)
  printf 'valid\n' >"$unavailable_swift/docs/delivery/progress.md"
  git -C "$unavailable_swift" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$unavailable_swift"
  expect_status 1 unavailable_swift env PATH=/bin /usr/bin/git -C "$unavailable_swift" commit -qm unavailable-swift
  expect_diagnostic unavailable_swift 'swift|validator|unavailable'

  staged_validator_unavailable_worktree=$(new_repo staged-validator-unavailable-worktree)
  printf 'valid\n' >"$staged_validator_unavailable_worktree/docs/delivery/progress.md"
  git -C "$staged_validator_unavailable_worktree" add docs/delivery/progress.md script/check_development_docs.swift
  install_hook "$staged_validator_unavailable_worktree"
  mv "$staged_validator_unavailable_worktree/script/check_development_docs.swift" "$staged_validator_unavailable_worktree/script/check_development_docs.swift.off"
  expect_status 0 staged_validator_unavailable_worktree commit "$staged_validator_unavailable_worktree" staged-validator-unavailable-worktree

  collision=$(new_repo collision)
  hooks_path=$(git -C "$collision" rev-parse --path-format=absolute --git-path hooks)
  mkdir -p "$hooks_path"
  printf '#!/usr/bin/env bash\necho preserved\n' >"$hooks_path/pre-commit"
  chmod +x "$hooks_path/pre-commit"
  expect_status 1 installer_collision install_hook "$collision"
  grep -Fqx 'echo preserved' "$hooks_path/pre-commit" || fail 'installer_collision: existing hook changed'
  expect_diagnostic installer_collision 'existing|pre-commit|overwrite'

  configured_hooks=$(new_repo configured-hooks)
  configured_path="$configured_hooks/custom-hooks"
  git -C "$configured_hooks" config core.hooksPath "$configured_path"
  expect_status 0 configured_hooks install_hook "$configured_hooks"
  [[ $(git -C "$configured_hooks" config --get core.hooksPath) == "$configured_path" ]] || fail 'configured_hooks: core.hooksPath changed'
  [[ -x "$configured_path/pre-commit" ]] || fail 'configured_hooks: hook was not installed in configured hooks path'
  expect_status 0 installer_status bash -c "cd '$configured_hooks' && ./script/install_development_docs_hook.sh --status"
  chmod -x "$configured_path/pre-commit"
  expect_status 1 nonexecutable_hook_status bash -c "cd '$configured_hooks' && ./script/install_development_docs_hook.sh --status"
  expect_diagnostic nonexecutable_hook_status 'not installed|executable|pre-commit'

  workflow="$repo_root/.github/workflows/development-documentation.yml"
  grep -Eq 'pull_request:' "$workflow" || fail 'workflow: pull_request trigger missing'
  grep -Eq 'push:' "$workflow" || fail 'workflow: push trigger missing'
  grep -Eq 'contents:[[:space:]]*read' "$workflow" || fail 'workflow: least-privilege contents permission missing'
  grep -Eq -- '--root' "$workflow" || fail 'workflow: validator root mode missing'
fi

if [[ $failures -ne 0 ]]; then
  exit 1
fi
