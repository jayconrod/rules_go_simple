# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Rules for building Go programs.

Rules take a description of something to build (for example, the sources and
dependencies of a library) and create a plan of how to build it (output files,
actions).
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(":providers.bzl", "GoLibraryInfo")

def _go_binary_impl(ctx):
    # Load the toolchain.
    go_toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]

    # Declare an output file for the main package and compile it from srcs. All
    # our output files will start with a prefix to avoid conflicting with
    # other rules.
    main_archive = ctx.actions.declare_file("{name}_/main.a".format(name = ctx.label.name))
    go_toolchain.compile(
        ctx,
        srcs = ctx.files.srcs,
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = main_archive,
    )

    # Declare an output file for the executable and link it. Note that output
    # files may not have the same name as the rule, so we still need to use the
    # prefix here.
    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_toolchain.link(
        ctx,
        main = main_archive,
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = executable,
    )

    # Return the DefaultInfo provider. This tells Bazel what files should be
    # built when someone asks to build a go_binary rule. It also says which
    # file is executable (in this case, there's only one).
    runfiles = _collect_runfiles(
        ctx,
        direct_files = ctx.files.data,
        indirect_targets = ctx.attr.data + ctx.attr.deps,
    )
    return [DefaultInfo(
        files = depset([executable]),
        runfiles = runfiles,
        executable = executable,
    )]

# Declare the go_binary rule. This statement is evaluated during the loading
# phase when this file is loaded. The function body above is evaluated only
# during the analysis phase.
go_binary = rule(
    implementation = _go_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = "Source files to compile for the main package of this binary",
        ),
        "deps": attr.label_list(
            providers = [GoLibraryInfo],
            doc = "Direct dependencies of the binary",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files available to this binary at run-time",
        ),
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
    toolchains = ["@rules_go_simple//:toolchain_type"],
)

def _go_tool_binary_impl(ctx):
    # Locate the go command. We use it to invoke the compiler and linker.
    go_cmd = None
    for f in ctx.files.tools:
        if f.path.endswith("/bin/go") or f.path.endswith("/bin/go.exe"):
            go_cmd = f
            break
    if not go_cmd:
        fail("could not locate Go command")

    # Declare the output executable file.
    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)

    # Create a shell command that compiles and links the binary.
    cmd_tpl = ("{go} tool compile -o {out}.a {srcs} && " +
               "{go} tool link -o {out} {out}.a")
    cmd = cmd_tpl.format(
        go = shell.quote(go_cmd.path),
        out = shell.quote(executable.path),
        srcs = " ".join([shell.quote(src.path) for src in ctx.files.srcs]),
    )
    inputs = ctx.files.srcs + ctx.files.tools + ctx.files.std_pkgs
    ctx.actions.run_shell(
        outputs = [executable],
        inputs = inputs,
        command = cmd,
        mnemonic = "GoToolBuild",
    )

    return [DefaultInfo(
        files = depset([executable]),
        executable = executable,
    )]

go_tool_binary = rule(
    implementation = _go_tool_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            mandatory = True,
            doc = "Source files to compile for the main package of this binary",
        ),
        "tools": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "Executable files that are part of a Go distribution",
        ),
        "std_pkgs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = "Pre-compiled standard library packages that are part of a Go distribution",
        ),
    },
    doc = """Builds an executable program for the Go toolchain.

go_tool_binary is a simple version of go_binary. It is separate from go_binary
because go_binary depends on the Go toolchain, and the toolchain uses a binary
built with this rule to do most of its work.

This rule does not support dependencies or build constraints. All source files
will be compiled, and they may only depend on the standard library.
""",
    executable = True,
)

def _go_library_impl(ctx):
    # Load the toolchain.
    toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]

    # Declare an output file for the library package and compile it from srcs.
    archive = ctx.actions.declare_file("{name}_/pkg.a".format(name = ctx.label.name))
    toolchain.compile(
        ctx,
        srcs = ctx.files.srcs,
        importpath = ctx.attr.importpath,
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = archive,
    )

    # Return the output file and metadata about the library.
    runfiles = _collect_runfiles(
        ctx,
        direct_files = ctx.files.data,
        indirect_targets = ctx.attr.data + ctx.attr.deps,
    )
    return [
        DefaultInfo(
            files = depset([archive]),
            runfiles = runfiles,
        ),
        GoLibraryInfo(
            info = struct(
                importpath = ctx.attr.importpath,
                archive = archive,
            ),
            deps = depset(
                direct = [dep[GoLibraryInfo].info for dep in ctx.attr.deps],
                transitive = [dep[GoLibraryInfo].deps for dep in ctx.attr.deps],
            ),
        ),
    ]

go_library = rule(
    implementation = _go_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = "Source files to compile",
        ),
        "deps": attr.label_list(
            providers = [GoLibraryInfo],
            doc = "Direct dependencies of the library",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files available to binaries using this library",
        ),
        "importpath": attr.string(
            mandatory = True,
            doc = "Name by which the library may be imported",
        ),
    },
    doc = "Compiles a Go archive from Go sources and dependencies",
    toolchains = ["@rules_go_simple//:toolchain_type"],
)

def _go_test_impl(ctx):
    toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]

    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    toolchain.build_test(
        ctx,
        srcs = ctx.files.srcs,
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = executable,
        importpath = ctx.attr.importpath,
        rundir = ctx.label.package,
    )

    runfiles = _collect_runfiles(
        ctx,
        direct_files = ctx.files.data,
        indirect_targets = ctx.attr.data + ctx.attr.deps,
    )
    return [DefaultInfo(
        files = depset([executable]),
        runfiles = runfiles,
        executable = executable,
    )]

go_test = rule(
    implementation = _go_test_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = ("Source files to compile for this test. " +
                   "May be a mix of internal and external tests."),
        ),
        "deps": attr.label_list(
            providers = [GoLibraryInfo],
            doc = "Direct dependencies of the test",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files available to this test",
        ),
        "importpath": attr.string(
            default = "",
            doc = "Name by which test archives may be imported (optional)",
        ),
    },
    doc = """Compiles and links a Go test executable. Functions with names
starting with "Test" in files with names ending in "_test.go" will be called
using the go "testing" framework.""",
    test = True,
    toolchains = ["@rules_go_simple//:toolchain_type"],
)

def _collect_runfiles(ctx, direct_files, indirect_targets):
    """Builds a runfiles object for the current target.

    Args:
        ctx: analysis context.
        direct_files: list of Files to include directly.
        indirect_targets: list of Targets to gather transitive runfiles from.
    Returns:
        A runfiles object containing direct_files and runfiles from
        indirect_targets. The files from indirect_targets won't be included
        unless they are also included in runfiles.
    """
    return ctx.runfiles(
        files = direct_files,
        transitive_files = depset(
            transitive = [target[DefaultInfo].default_runfiles.files for target in indirect_targets],
        ),
    )
