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
    "go_compile",
    "go_link",
)
load(":providers.bzl", "GoLibraryInfo")

def _go_binary_impl(ctx):
    # EXERCISE: collect GoLibraryInfo from dependencies, pass to go_compile
    # and go_link.
    deps = []

    # Declare an output file for the main package and compile it from srcs. All
    # our output files will start with a prefix to avoid conflicting with
    # other rules.
    main_archive = declare_archive(ctx, "main")
    go_compile(
        ctx,
        importpath = "main",
        srcs = ctx.files.srcs,
        deps = deps,
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
        deps = deps,
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
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_library_impl(ctx):
    pass
    # EXERCISE: declare output file and actions, return GoLibraryInfo
    # and DefaultInfo.

# EXERCISE: declare go_library with srcs, deps, importpath attributes.
# Returns GoLibraryInfo provider.
go_library = None
