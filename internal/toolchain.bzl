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
    "find_tool",
    "go_build_test",
    "go_compile",
    "go_link",
)
load(
    ":providers.bzl",
    "GoStdLibInfo",
)

def _go_toolchain_impl(ctx):
    # Find important files and paths.
    go_exe = find_tool("go", ctx.files.tools)
    env = {
        "GOHOSTARCH": ctx.attr.gohostarch,
        "GOHOSTOS": ctx.attr.gohostos,
        "GOROOT": paths.dirname(paths.dirname(go_exe.path)),
    }
    files = depset(
        direct = ctx.files.tools,
        transitive = [ctx.attr.stdlib[GoStdLibInfo].files],
    )

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
            go_exe = go_exe,
            env = env,
            builder = ctx.executable.builder,
            stdlib = ctx.attr.stdlib[GoStdLibInfo],
            tools = ctx.files.tools,
            files = files,
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
        "gohostarch": attr.string(
            mandatory = True,
            doc = """Name of the architecture that can run Go's
                precompiled executables""",
        ),
        "gohostos": attr.string(
            mandatory = True,
            doc = """Name of the operating system that can run Go's
                precompiled executables""",
        ),
        "stdlib": attr.label(
            mandatory = True,
            cfg = "exec",
            providers = [GoStdLibInfo],
            doc = "The compiled standard library",
        ),
        "tools": attr.label_list(
            mandatory = True,
            doc = "Compiler, linker, and other executables from the Go distribution",
        ),
    },
    doc = "Gathers functions and file lists needed for a Go toolchain",
)
