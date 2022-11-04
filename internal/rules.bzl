# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Rules for building Go programs.

Rules take a description of something to build (for example, the sources and
dependencies of a library) and create a plan of how to build it (output files,
actions).
"""

load(":actions.bzl", "go_compile", "go_link")

def _go_binary_impl(ctx):
    pass
    # EXERCISE: declare output file, call go_compile, go_link to create
    # actions, return DefaultInfo.

# EXERCISE: declare rule.
go_binary = None
