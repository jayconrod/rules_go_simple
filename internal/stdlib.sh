#!/usr/bin/env bash

# This script compiles the Go standard library for go_stdlib.
# It's a bash script because we can't compile or run any Go code before
# compiling the standard library.

set -o errexit -o nounset -o pipefail

go_cmd="$1"
pkg_dir="$2"

# Create the GOCACHE and GOROOT directories, and delete them on exit.
# Both must be temporary directories with random names. This script may run
# in multiple concurrent actions (if we're building for multiple platforms),
# and if Bazel is run without sandboxing, those actions must not conflict
# with each other by writing something unexpected into the output directory.
#
# GOCACHE stores compiled output files.
# GOROOT stores a copy of the source tree.
export GOCACHE=$(mktemp -d -t gocache)
cleanup_paths=("$GOCACHE")
trap 'chmod -R u+w "${cleanup_paths[@]}" && rm -rf "${cleanup_paths[@]}"' EXIT

# Compile the packages in the standard library.
# Instead of 'go build std' we use 'go list -export std' because we want to
# know the names of the compiled files.
mkdir -p "$pkg_dir"
pkg_list="$(mktemp -t pkg_list)"
cleanup_paths+=("$pkg_list")
"$go_cmd" list -export -f '{{.ImportPath}}={{.Export}}' std >"$pkg_list"

# Move the compiled files out of the cache.
while IFS='=' read pkg_path cache_file; do
  if [[ -z $cache_file ]]; then
    continue # skip fake packages like unsafe
  fi
  pkg_file="$pkg_dir/$pkg_path.a"
  mkdir -p "$(dirname "$pkg_file")"
  mv "$cache_file" "$pkg_file"
done <"$pkg_list"
