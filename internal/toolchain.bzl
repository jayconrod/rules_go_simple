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

def _go_toolchain_impl(ctx):
    # Find important files and paths.
    go_cmd = None
    for f in ctx.files.tools:
        if f.path.endswith("/bin/go") or f.path.endswith("/bin/go.exe"):
            go_cmd = f
            break
    if not go_cmd:
        fail("could not locate go command")
    env = {"GOROOT": paths.dirname(paths.dirname(go_cmd.path))}

    # Generate the package list from the standard library.
    stdimportcfg = ctx.actions.declare_file(ctx.label.name + ".importcfg")
    ctx.actions.run(
        outputs = [stdimportcfg],
        inputs = ctx.files.tools + ctx.files.std_pkgs,
        arguments = ["stdimportcfg", "-o", stdimportcfg.path],
        env = env,
        executable = ctx.executable.builder,
        mnemonic = "GoStdImportcfg",
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
            go_cmd = go_cmd,
            env = env,
            stdimportcfg = stdimportcfg,
            builder = ctx.executable.builder,
            tools = ctx.files.tools,
            std_pkgs = ctx.files.std_pkgs,
        ),
    )]

go_toolchain = rule(
    implementation = _go_toolchain_impl,
    attrs = {
        "builder": attr.label(
            mandatory = True,
            executable = True,
            cfg = "host",
            doc = "Executable that performs most actions",
        ),
        "tools": attr.label_list(
            mandatory = True,
            doc = "Compiler, linker, and other executables from the Go distribution",
        ),
        "std_pkgs": attr.label_list(
            mandatory = True,
            doc = "Standard library packages from the Go distribution",
        ),
    },
    doc = "Gathers functions and file lists needed for a Go toolchain",
)
