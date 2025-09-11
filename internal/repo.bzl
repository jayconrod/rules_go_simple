# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Repository rules for rules_go_simple.

A repository rule creates a "repo", a named directory containing build files
and source files, usually downloaded from an external dependency. Both of the
repository rules here are used internally by the go module extension.

go_download actually downloads a Go distribution archive and generates a
BUILD.bazel file that can build the standard library and a builder binary.

go_toolchains generates a BUILD.bazel file with all of the toolchain
definitions.

The go module extension declares one go_toolchains repo and multiple
go_download repos (one for each supported platform). Bazel will only materialize
a go_download repo if its toolchain is selected for a build.
"""

_GOOS_TO_CONSTRAINT = {
    "darwin": "@platforms//os:macos",
    "linux": "@platforms//os:linux",
    "windows": "@platforms//os:windows",
}

_GOARCH_TO_CONSTRAINT = {
    "amd64": "@platforms//cpu:x86_64",
    "arm64": "@platforms//cpu:aarch64",
}

# EXERCISE: declare and implement the go_download repository rule.
