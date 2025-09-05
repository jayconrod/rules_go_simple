#!/usr/bin/env bash

# This script compiles and links a Go binary for go_tool_binary.
# It's a bash script because it's needed to build the builder binary
# that we use to implement the other rules.

set -o errexit -o nounset -o pipefail

executable="$1"
go_cmd="$2"
stdlib_dir="$3"
shift 3

# Generate an importcfg file for the standard library. go_tool_binary is only
# allowed to import packages in the standard library, so this has everything
# we need. We don't know which packages it imports, so we include everything.
importcfg="$(mktemp -t importcfg)"
for file in $(find -L "$stdlib_dir" -type f); do
  without_suffix="${file%.a}"
  pkg_path="${without_suffix#${stdlib_dir}/}"
  abs_file="$PWD/$file"
  printf 'packagefile %s=%s\n' "$pkg_path" "$abs_file" >>"$importcfg"
done

# Compile and link the tool binary.
"$go_cmd" tool compile -importcfg "$importcfg" -p main -o "$executable.a" $@
"$go_cmd" tool link -importcfg "$importcfg" -o "$executable" "$executable.a"
