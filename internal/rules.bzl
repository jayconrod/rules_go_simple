# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

load(
    ":actions.bzl",
    "declare_archive",
    "go_build_test",
    "go_compile",
    "go_link",
    "go_build_tool",
    "go_write_stdimportcfg",
)
load(":providers.bzl", "GoLibrary")

def _go_binary_impl(ctx):
    # Declare an output file for the main package and compile it from srcs. All
    # our output files will start with a prefix to avoid conflicting with
    # other rules.
    main_archive = declare_archive(ctx, "main")
    go_compile(
        ctx,
        srcs = ctx.files.srcs,
        deps = [dep[GoLibrary] for dep in ctx.attr.deps],
        out = main_archive,
    )

    # Declare an output file for the executable and link it. Note that output
    # files may not have the same name as the rule, so we still need to use the
    # prefix here.
    executable_path = "{name}%/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_link(
        ctx,
        main = main_archive,
        deps = [dep[GoLibrary] for dep in ctx.attr.deps],
        out = executable,
    )

    # Return the DefaultInfo provider. This tells Bazel what files should be
    # built when someone asks to build a go_binary rules. It also says which
    # one is executable (in this case, there's only one).
    return [DefaultInfo(
        files = depset([executable]),
        runfiles = ctx.runfiles(collect_data = True),
        executable = executable,
    )]

# Declare the go_binary rule. This statement is evaluated during the loading
# phase when this file is loaded. The function body above is evaluated only
# during the analysis phase.
go_binary = rule(
    _go_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = "Source files to compile for the main package of this binary",
        ),
        "deps": attr.label_list(
            providers = [GoLibrary],
            doc = "Direct dependencies of the binary",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Data files available to this binary at run-time",
        ),
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "host",
        ),
        "_stdimportcfg": attr.label(
            default = "//internal/builder:stdimportcfg",
            allow_single_file = True,
        ),
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_tool_binary_impl(ctx):
    executable_path = "{name}%/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_build_tool(
        ctx,
        srcs = ctx.files.srcs,
        out = executable,
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
            doc = "Source files to compile for the main package of this binary",
        ),
    },
    doc = """Builds an executable program for the Go toolchain.

go_tool_binary is a simple version of go_binary. It is separate from go_binary
because go_binary relies on a program produced by this rule.

This rule does not support dependencies or build constraints. All source files
will be compiled, and they may only depend on the standard library.
""",
    executable = True,
)

def _go_library_impl(ctx):
    # Declare an output file for the library package and compile it from srcs.
    archive = declare_archive(ctx, ctx.attr.importpath)
    go_compile(
        ctx,
        srcs = ctx.files.srcs,
        importpath = ctx.attr.importpath,
        deps = [dep[GoLibrary] for dep in ctx.attr.deps],
        out = archive,
    )

    # Return the output file and metadata about the library.
    return [
        DefaultInfo(
            files = depset([archive]),
            runfiles = ctx.runfiles(collect_data = True),
        ),
        GoLibrary(
            info = struct(
                importpath = ctx.attr.importpath,
                archive = archive,
            ),
            deps = depset(
                direct = [dep[GoLibrary].info for dep in ctx.attr.deps],
                transitive = [dep[GoLibrary].deps for dep in ctx.attr.deps],
            ),
        ),
    ]

go_library = rule(
    _go_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".go"],
            doc = "Source files to compile",
        ),
        "deps": attr.label_list(
            providers = [GoLibrary],
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
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "host",
        ),
        "_stdimportcfg": attr.label(
            default = "//internal/builder:stdimportcfg",
            allow_single_file = True,
        ),
    },
    doc = "Compiles a Go archive from Go sources and dependencies",
)

def _go_test_impl(ctx):
    executable_path = "{name}%/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_build_test(
        ctx,
        srcs = ctx.files.srcs,
        deps = [dep[GoLibrary] for dep in ctx.attr.deps],
        out = executable,
        importpath = ctx.attr.importpath,
        rundir = ctx.label.package,
    )

    return [DefaultInfo(
        files = depset([executable]),
        runfiles = ctx.runfiles(collect_data = True),
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
            providers = [GoLibrary],
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
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "host",
        ),
        "_stdimportcfg": attr.label(
            default = "//internal/builder:stdimportcfg",
            allow_single_file = True,
        ),
    },
    doc = """Compiles and links a Go test executable. Functions with names
starting with "Test" in files with names ending in "_test.go" will be called
using the go "testing" framework.""",
    test = True,
)

def _go_stdimportcfg_impl(ctx):
    f = ctx.actions.declare_file(ctx.label.name + ".txt")
    go_write_stdimportcfg(ctx, f)
    return [DefaultInfo(files = depset([f]))]

go_stdimportcfg = rule(
    implementation = _go_stdimportcfg_impl,
    attrs = {
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "host",
        ),
    },
    doc = """Generates an importcfg file for the Go standard library.
importcfg files map Go package paths to file paths.""",
)
