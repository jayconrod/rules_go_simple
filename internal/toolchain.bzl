# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Toolchains for Go rules.

go_toolchain creates a provider as described in GoToolchainInfo in
providers.bzl. toolchains and go_toolchains are declared in the build file
generated in go_download in repo.bzl.
"""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    ":actions.bzl",
    "go_build_test",
    "go_compile",
    "go_link",
)
load(":util.bzl", "find_go_cmd")

# EXERCISE: declare and implement the go_toolchain rule. It should have
# attributes "tools" for precompiled binaries, "stdlib" for go_stdlib,
# and "builder" for go_tool_binary. It should return a
# platform_common.ToolchainInfo provider matching GoToolchainInfo.
