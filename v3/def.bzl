# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# def.bzl contains public definitions that may be used by Bazel projects for
# building Go programs. These definitions should be loaded from here and
# not any internal directory.

load("//v3/internal:rules.bzl", "go_binary", "go_library")
load("//v3/internal:providers.bzl", "GoLibrary")
