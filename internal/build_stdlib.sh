#!/usr/bin/env bash

# go_stdlib uses this script to compile the Go standard library.
# See that rule for more commentary.
#
# This script was not part of the original rule set. Previously, we depended
# on precompiled library files shipped with the Go distribution. These files
# were removed in Go 1.20 to reduce download sizes, so now we need to compile
# them ourselves using the go tool.

set -o errexit -o nounset -o pipefail

function usage_error {
  echo >&2 "usage: GOROOT=dir $0 packages-dir importcfg-file"
  exit 1
}

# Parse command-line arguments.
if [[ -z "${GOROOT:-}" || $# -ne 2 || -z $1 || -z $2 ]]; then
  usage_error
fi
out_packages=$1
out_importcfg=$2

# Dereference symbolic links in the working directory path. 'go list' below
# will print absolute paths without symbolic links. We want to use sed later
# to trim the working directory prefix from each path, so we need to get rid
# of the symbolic links now.
cd "$(realpath .)"
work_dir="$PWD"

# Set GOROOT to an absolute path. Go requires it to be an absolute path, but
# Bazel rules won't know the full path before execution.
export GOROOT=$(realpath "$GOROOT")

# Set GOPATH to a dummy value. This silences a warning printed by the go tool
# when HOME is not set.
export GOPATH=/dev/null

# Set GOCACHE to the output package directory. 'go list' will write compiled
# packages here.
export GOCACHE=$(realpath "$out_packages")

# Replace symbolic links in GOROOT with hard links. Depending on Bazel's execution
# strategy, it may build a tree of symbolic links to input files. Some
# packages (like crypto/internal/nistec) embed data files, and a go:embed
# directive must not match an irregular file, like a symbolic link.
while IFS= read -r -d $'\0' symlink; do
  cd "$(dirname "$symlink")"
  ln -f "$(readlink "$symlink")" "$(basename "$symlink")"
  cd "$work_dir"
done < <(find "$GOROOT" -type l -print0)

# Compile packages and write the importcfg saying where they are.
# 'go list' normally doesn't build anything, but with -export, it needs to
# print output file names in the cache, and it needs to actually compile those
# files first. We use a fancy format string with -f so it tells us where those
# files are. The output file names are absolute paths, which won't be usable
# in other Bazel actions if sandboxing or remote execution are used, so we
# trim the work directory prefix using sed.
"${GOROOT}/bin/go" list -export -f '{{if .Export}}packagefile {{.ImportPath}}={{.Export}}{{end}}' std | \
  sed -E -e "s,=${work_dir}/,=," \
  >"$out_importcfg"
