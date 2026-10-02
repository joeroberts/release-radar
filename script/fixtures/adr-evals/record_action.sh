#!/bin/sh
set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: record_action.sh ABSOLUTE_EMPTY_OUTPUT ACTION [ARG ...]" >&2
  exit 64
fi

output_path=$1
shift

case "$output_path" in
  /*) ;;
  *)
    echo "recorder output must be an absolute path" >&2
    exit 64
    ;;
esac

if [ -L "$output_path" ] || [ ! -f "$output_path" ] || [ -s "$output_path" ]; then
  echo "recorder output must be an existing empty non-symlink regular file" >&2
  exit 64
fi

printf '%s\n' "$*" >> "$output_path"
