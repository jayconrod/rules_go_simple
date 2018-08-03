# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

load(
    ":actions.bzl",
    "declare_archive",
    "go_compile",
    "go_link",
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
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_library_impl(ctx):
    # Declare an output file for the library package and compile it from srcs.
    archive = declare_archive(ctx, ctx.attr.importpath)
    go_compile(
        ctx,
        srcs = ctx.files.srcs,
        deps = [dep[GoLibrary] for dep in ctx.attr.deps],
        out = archive,
    )

    # Return the output file and metadata about the library.
    return [
        DefaultInfo(files = depset([archive])),
        GoLibrary(
            data = struct(
                importpath = ctx.attr.importpath,
                archive = archive,
            ),
            deps = depset(
                direct = [dep[GoLibrary].data for dep in ctx.attr.deps],
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
        "importpath": attr.string(
            mandatory = True,
            doc = "Name by which the library may be imported",
        ),
    },
    doc = "Compiles a Go archive from Go sources and dependencies",
)
