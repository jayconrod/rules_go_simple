# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Toolchains for Go rules.

go_toolchain creates a provider as described in GoToolchainInfo in
providers.bzl. toolchains and go_toolchains are declared in the build file
generated in go_toolchains in repo.bzl.
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

def _go_toolchain_impl(ctx):
    # Find important files and paths.
    go_cmd = find_go_cmd(ctx.files.tools)
    env = {"GOROOT": paths.dirname(paths.dirname(go_cmd.path))}

    # Return a TooclhainInfo provider. This is the object that rules get
    # when they ask for the toolchain.
    return [platform_common.ToolchainInfo(
        # Functions that generate actions. Rules may call these.
        # This is the public interface of the toolchain.
        compile = go_compile,
        link = go_link,
        build_test = go_build_test,

        # Internal data. Contents may change without notice.
        # Think of these like private fields in a class. Actions may use these
        # (they are methods of the class) but rules may not (they are clients).
        internal = struct(
            go_cmd = go_cmd,
            env = env,
            builder = ctx.executable.builder,
            tools = ctx.files.tools,
            stdlib = ctx.file.stdlib,
        ),
    )]

go_toolchain = rule(
    implementation = _go_toolchain_impl,
    attrs = {
        "builder": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "Executable that performs most actions",
        ),
        "tools": attr.label_list(
            mandatory = True,
            doc = "Compiler, linker, and other executables from the Go distribution",
        ),
        "stdlib": attr.label(
            mandatory = True,
            allow_single_file = True,
            cfg = "target",
            doc = "Package files for the standard library compiled by go_stdlib",
        ),
    },
    doc = "Gathers functions and file lists needed for a Go toolchain",
)
