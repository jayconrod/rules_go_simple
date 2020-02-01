# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# def.bzl contains public definitions that may be used by Bazel projects for
# building Go programs. These definitions should be loaded from here and
# not any internal directory.

load(
    "//internal:rules.bzl",
    _go_binary = "go_binary",
    _go_library = "go_library",
    _go_test = "go_test",
)
load(
    "//internal:providers.bzl",
    _GoLibrary = "GoLibrary",
)
load(
    "//internal:toolchain.bzl",
    _go_toolchain = "go_toolchain",
)

go_binary = _go_binary
go_library = _go_library
go_test = _go_test
go_toolchain = _go_toolchain
GoLibrary = _GoLibrary
