#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
validator="$repo_root/script/check_development_docs.swift"
fixture_root=$(mktemp -d)
trap 'rm -rf "$fixture_root"' EXIT

failures=0

expect_status() {
  local expected=$1
  local name=$2
  shift 2
  set +e
  "$@" >/dev/null 2>"$fixture_root/stderr-$name"
  local actual=$?
  set -e
  if [[ $actual -ne $expected ]]; then
    printf 'FAIL %s: expected exit %s, got %s\n' "$name" "$expected" "$actual" >&2
    failures=$((failures + 1))
  else
    printf 'PASS %s\n' "$name"
  fi
}

expect_diagnostic() {
  local name=$1
  local pattern=$2
  if ! grep -Eqi "$pattern" "$fixture_root/stderr-$name"; then
    printf 'FAIL %s: diagnostic did not identify the condition\n' "$name" >&2
    failures=$((failures + 1))
  fi
}

write_root() {
  local name=$1
  local content=$2
  local root="$fixture_root/$name"
  mkdir -p "$root/docs/delivery"
  printf '%s' "$content" >"$root/docs/delivery/progress.md"
  printf '%s' "$root"
}

expect_root() {
  local expected=$1
  local name=$2
  local content=$3
  local root
  root=$(write_root "$name" "$content")
  expect_status "$expected" "$name" swift "$validator" --root "$root"
}

expect_stdin() {
  local expected=$1
  local name=$2
  local content=$3
  set +e
  printf '%s' "$content" | swift "$validator" --progress-stdin >/dev/null 2>"$fixture_root/stderr-$name"
  local actual=$?
  set -e
  if [[ $actual -ne $expected ]]; then
    printf 'FAIL %s: expected exit %s, got %s\n' "$name" "$expected" "$actual" >&2
    failures=$((failures + 1))
  else
    printf 'PASS %s\n' "$name"
  fi
}

sixty_lines=$(printf 'x\n%.0s' {1..60})
sixty_one_lines=$(printf 'x\n%.0s' {1..61})
exact_bytes=$(printf 'a%.0s' {1..6144})
overflow_bytes=$(printf 'a%.0s' {1..6145})
multibyte_exact=$(printf 'é%.0s' {1..3072})
multibyte_overflow=$(printf 'é%.0s' {1..3073})

expect_root 0 empty ''
expect_root 0 lf_terminated "$sixty_lines"
expect_root 1 line_overflow "$sixty_one_lines"
expect_root 0 exact_byte_limit "$exact_bytes"
expect_root 1 byte_overflow "$overflow_bytes"
expect_root 0 multibyte_exact_byte_limit "$multibyte_exact"
expect_root 1 multibyte_byte_overflow "$multibyte_overflow"
expect_root 0 final_nonempty_segment $'one\ntwo'
expect_root 0 final_empty_segment $'one\ntwo\n'

parity_content=$'one\ntwo\n'
expect_root 0 root_mode "$parity_content"
expect_stdin 0 stdin_mode "$parity_content"

invalid_root="$fixture_root/invalid_utf8"
mkdir -p "$invalid_root/docs/delivery"
printf '\xff' >"$invalid_root/docs/delivery/progress.md"
expect_status 1 invalid_utf8_root swift "$validator" --root "$invalid_root"
expect_stdin 1 invalid_utf8_stdin $'\xff'

missing_root="$fixture_root/missing"
mkdir -p "$missing_root"
expect_status 1 missing_progress_file swift "$validator" --root "$missing_root"

directory_root="$fixture_root/directory"
mkdir -p "$directory_root/docs/delivery/progress.md"
expect_status 1 unreadable_progress_path swift "$validator" --root "$directory_root"

expect_status 64 missing_mode swift "$validator"
expect_status 64 unknown_argument swift "$validator" --unknown
expect_status 64 relative_root swift "$validator" --root relative

expect_diagnostic line_overflow 'line|60'
expect_diagnostic byte_overflow 'byte|6144'
expect_diagnostic multibyte_byte_overflow 'byte|6144'
expect_diagnostic invalid_utf8_root 'utf|encoding|valid'
expect_diagnostic invalid_utf8_stdin 'utf|encoding|valid'
expect_diagnostic missing_progress_file 'progress|read|file|path'
expect_diagnostic unreadable_progress_path 'progress|read|file|path'
expect_diagnostic missing_mode 'usage|argument|root|stdin'
expect_diagnostic unknown_argument 'usage|argument|root|stdin'
expect_diagnostic relative_root 'absolute|root|path'

if [[ $failures -ne 0 ]]; then
  exit 1
fi
