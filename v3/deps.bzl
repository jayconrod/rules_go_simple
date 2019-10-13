# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# deps.bzl contains public definitions needed in WORKSPACE and macros called
# from WORKSPACE. It is kept separate from def.bzl so that definitions loaded
# from def.bzl may use dependencies declared here.

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def go_rules_dependencies():
    """Declares external repositories that rules_go_simple depends on. This
    function should be loaded and called from WORKSPACE files."""

    # bazel_skylib is a set of libraries that are useful for writing
    # Bazel rules. We use it to handle quoting arguments in shell commands.
    _maybe(
        git_repository,
        name = "bazel_skylib",
        remote = "https://github.com/bazelbuild/bazel-skylib",
        commit = "3fea8cb680f4a53a129f7ebace1a5a4d1e035914",
        shallow_since = "1528913834 -0400",
    )

def _maybe(rule, name, **kwargs):
    """Declares an external repository if it hasn't been declared already."""
    if name not in native.existing_rules():
        rule(name = name, **kwargs)
