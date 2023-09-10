# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Rules for building Go programs.

Rules take a description of something to build (for example, the sources and
dependencies of a library) and create a plan of how to build it (output files,
actions).
"""

load(
    ":actions.bzl",
    "go_build_stdlib",
    "go_build_test",
    "go_build_tool",
    "go_compile",
    "go_link",
)
load(
    ":providers.bzl",
    "GoLibraryInfo",
    "GoStdLibInfo",
)

def _go_binary_impl(ctx):
    # Declare an output file for the main package and compile it from srcs. All
    # our output files will start with a prefix to avoid conflicting with
    # other rules.
    main_archive = ctx.actions.declare_file("{name}_/main.a".format(name = ctx.label.name))
    go_compile(
        ctx,
        importpath = "main",
        srcs = ctx.files.srcs,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = main_archive,
    )

    # Declare an output file for the executable and link it. Note that output
    # files may not have the same name as the rule, so we still need to use the
    # prefix here.
    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_link(
        ctx,
        main = main_archive,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
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
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "exec",
        ),
        "_stdlib": attr.label(
            default = "//internal:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
        ),
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_tool_binary_impl(ctx):
    # Declare the output executable file.
    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_build_tool(
        ctx,
        srcs = ctx.files.srcs,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
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
            mandatory = True,
            doc = "Source files to compile for the main package of this binary",
        ),
        "_stdlib": attr.label(
            default = "//internal:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
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
    # Declare an output file for the library package and compile it from srcs.
    archive = ctx.actions.declare_file("{name}_/pkg.a".format(name = ctx.label.name))
    go_compile(
        ctx,
        importpath = ctx.attr.importpath,
        srcs = ctx.files.srcs,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
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
            files = depset(
                direct = [archive],
                transitive = [dep[GoLibraryInfo].files for dep in ctx.attr.deps],
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
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "exec",
        ),
        "_stdlib": attr.label(
            default = "//internal:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
        ),
    },
    doc = "Compiles a Go archive from Go sources and dependencies",
)

def _go_test_impl(ctx):
    executable_path = "{name}_/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_build_test(
        ctx,
        importpath = ctx.attr.importpath,
        srcs = ctx.files.srcs,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = executable,
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
        "_builder": attr.label(
            default = "//internal/builder",
            executable = True,
            cfg = "exec",
        ),
        "_stdlib": attr.label(
            default = "//internal:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
        ),
    },
    doc = """Compiles and links a Go test executable. Functions with names
starting with "Test" in files with names ending in "_test.go" will be called
using the go "testing" framework.""",
    test = True,
)

def _go_stdlib_impl(ctx):
    # Declare two outputs: an importcfg file, and a packages directory.
    # Then build them both with go_build_stdlib. See the explanation there.
    prefix = ctx.label.name + "%/"
    importcfg = ctx.actions.declare_file(prefix + "importcfg")
    packages = ctx.actions.declare_directory(prefix + "packages")
    go_build_stdlib(
        ctx,
        out_importcfg = importcfg,
        out_packages = packages,
    )
    return [
        DefaultInfo(files = depset([importcfg, packages])),
        GoStdLibInfo(
            importcfg = importcfg,
            packages = packages,
            files = depset([importcfg, packages]),
        ),
    ]

# go_stdlib is an internal rule that compiles the Go standard library
# using source files and tools from a downloaded Go distribution.
#
# This rule was not part of the original tutorial series. Instead, we depended
# on precompiled packages that shipped with the Go distribution. The
# precompiled standard library was removed in Go 1.20 in order to reduce
# download sizes. Unfortunately, that meant this tutorial needed a rule that
# compiles the standard library, making it much more complicated.
#
# go_stdlib produces two outputs:
#
#     1. An importcfg file mapping each package's import path to a relative
#        file path within Bazel's execroot. This is read by the compiler and
#        linker to locate files for imported packages.
#     2. A packages directory containing compiled packages. These packages
#        are read by the compiler (for export data) and the linker
#        (for linking).
#
# go_stdlib returns a GoStdLibInfo provider that points to these outputs.
#
# There is a single go_stdlib target, //internal:stdlib. All other Go rules
# have a hidden dependency on that target.
go_stdlib = rule(
    implementation = _go_stdlib_impl,
    doc = "Builds the Go standard library",
    provides = [GoStdLibInfo],
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
