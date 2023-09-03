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
    "declare_archive",
    "go_build_stdlib",
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
    main_archive = declare_archive(ctx, "main")
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
    executable_path = "{name}%/{name}".format(name = ctx.label.name)
    executable = ctx.actions.declare_file(executable_path)
    go_link(
        ctx,
        main = main_archive,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = executable,
    )

    # Return the DefaultInfo provider. This tells Bazel what files should be
    # built when someone asks to build a go_binary rules. It also says which
    # one is executable (in this case, there's only one).
    return [DefaultInfo(
        files = depset([executable]),
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
        "_stdlib": attr.label(
            default = "//:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
        ),
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_library_impl(ctx):
    # Declare an output file for the library package and compile it from srcs.
    archive = declare_archive(ctx, ctx.attr.importpath)
    go_compile(
        ctx,
        importpath = ctx.attr.importpath,
        srcs = ctx.files.srcs,
        stdlib = ctx.attr._stdlib[GoStdLibInfo],
        deps = [dep[GoLibraryInfo] for dep in ctx.attr.deps],
        out = archive,
    )

    # Return the output file and metadata about the library.
    return [
        DefaultInfo(files = depset([archive])),
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
        "importpath": attr.string(
            mandatory = True,
            doc = "Name by which the library may be imported",
        ),
        "_stdlib": attr.label(
            default = "//:stdlib",
            providers = [GoStdLibInfo],
            doc = "Hidden dependency on the Go standard library",
        ),
    },
    doc = "Compiles a Go archive from Go sources and dependencies",
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

# go_stdlib is an internal rule that builds the Go standard library using
# the go tool installed on the host system.
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
# There is a single go_stdlib target, //:stdlib. All other Go rules
# have a hidden dependency on that target.
go_stdlib = rule(
    implementation = _go_stdlib_impl,
    doc = "Builds the Go standard library",
    provides = [GoStdLibInfo],
)
