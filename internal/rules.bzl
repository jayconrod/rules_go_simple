# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Rules for building Go programs.

Rules take a description of something to build (for example, the sources and
dependencies of a library) and create a plan of how to build it (output files,
actions).
"""

load(":actions.bzl", "go_compile", "go_link")
load(":util.bzl", "find_go_cmd")

def _go_binary_impl(ctx):
    # Declare an output file for the main package and compile it from srcs.
    main_archive = ctx.actions.declare_file("{name}.a".format(name = ctx.label.name))
    go_compile(
        ctx,
        srcs = ctx.files.srcs,
        importpath = "main",
        out = main_archive,
    )

    # Declare an output file for the executable and link it.
    executable = ctx.actions.declare_file(ctx.label.name)
    go_link(
        ctx,
        main = main_archive,
        out = executable,
    )

    # Return the DefaultInfo provider. This tells Bazel what files should be
    # built when someone asks to build a go_binary rule. It also says which
    # file is executable (in this case, there's only one).
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
        "_stdlib": attr.label(
            default = "//internal:stdlib",
        ),
    },
    doc = "Builds an executable program from Go source code",
    executable = True,
)

def _go_stdlib_impl(ctx):
    # Declare an output directory for the compiled standard library, not a file.
    # The compiled standard library has an .a file for each package with a path
    # matching the import path (fmt.a, archive/tar.a, and so on). New packages
    # may be added over time, so we don't know exactly what files will be
    # produced. It doesn't matter as far as Bazel is concerned though: we can
    # treat the whole thing as a single File.
    go_cmd = "go"
    pkg_dir = ctx.actions.declare_directory(ctx.label.name)
    ctx.actions.run(
        mnemonic = "GoStdLib",
        executable = ctx.executable._script,
        arguments = [go_cmd, pkg_dir.path],
        outputs = [pkg_dir],
        use_default_shell_env = True,
    )

    return [DefaultInfo(files = depset([pkg_dir]))]

go_stdlib = rule(
    implementation = _go_stdlib_impl,
    attrs = {
        "_script": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            default = ":stdlib.sh",
            doc = "Script that compiles the Go standard library",
        ),
    },
    doc = """Internal rule needed to build the standard library. Needed by
go_tool_binary and the rest of the toolchain.""",
)
