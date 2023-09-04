#!/usr/bin/env bash

# go_tool_binary uses this script to compile the builder tool. See that rule
# for more commentary.

set -o errexit -o nounset -o pipefail

function usage_error {
  echo >&2 "usage: $0 compiler linker stdimportcfg-file out-file srcs..."
  exit 1
}

# Parse command-line arguments.
if [[ $# -lt 5 ]]; then
  usage_error
  exit 1
fi
compiler=$1
linker=$2
importcfg=$3
out_exe=$4
shift 4

# Compile the tool. We assume there's only a compile for one platform.
main_archive=$(mktemp)
"$compiler" -o "$main_archive" -importcfg "$importcfg" -p main -- $@

# Link the tool.
"$linker" -o "$out_exe" -importcfg "$importcfg" -- "$main_archive"

rm "$main_archive"
