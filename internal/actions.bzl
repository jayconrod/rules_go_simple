# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

def go_compile(ctx, *, srcs, importpath, stdlib, deps, out):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        importpath: the path other libraries may use to import this package.
        stdlib: a File for the compiled standard library directory.
        deps: list of GoLibraryInfo objects for direct dependencies.
        out: output .a File.
    """
    # EXERCISE: use the builder binary to compile the package.

def go_link(ctx, *, main, stdlib, builder, deps, out):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        main: archive file for the main package.
        stdlib: a File for the compiled standard library directory.
        builder: an executable File for the builder tool.
        deps: list of GoLibraryInfo objects for direct dependencies.
        out: output executable file.
    """

    transitive_deps = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    inputs = [main, stdlib] + [d.archive for d in transitive_deps.to_list()]

    args = ctx.actions.args()
    args.add("link")
    args.add("-stdlib", stdlib.path)
    args.add_all(transitive_deps, before_each = "-arc", map_each = _format_arc)
    args.add("-main", main)
    args.add("-o", out)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = builder,
        arguments = [args],
        use_default_shell_env = True,
        mnemonic = "GoLink",
    )

def go_build_test(ctx, *, srcs, stdlib, builder, deps, rundir, importpath, out):
    """Compiles and links a Go test executable.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        stdlib: a File for the compiled standard library directory.
        builder: an executable File for the builder tool.
        deps: list of GoLibraryInfo objects for direct dependencies.
        importpath: import path of the internal test archive.
        rundir: directory the test should change to before executing.
        out: output executable file.
    """
    direct_dep_infos = [d.info for d in deps]
    transitive_dep_infos = depset(transitive = [d.deps for d in deps]).to_list()
    inputs = (srcs +
              [stdlib] +
              [d.archive for d in direct_dep_infos] +
              [d.archive for d in transitive_dep_infos])

    args = ctx.actions.args()
    args.add("test")
    args.add("-stdlib", stdlib.path)
    args.add_all(direct_dep_infos, before_each = "-direct", map_each = _format_arc)
    args.add_all(transitive_dep_infos, before_each = "-transitive", map_each = _format_arc)
    if rundir != "":
        args.add("-dir", rundir)
    if importpath != "":
        args.add("-p", importpath)
    args.add("-o", out)
    args.add_all(srcs)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = builder,
        arguments = [args],
        use_default_shell_env = True,
        mnemonic = "GoTest",
    )

def _format_arc(lib):
    """Formats a GoLibraryInfo.info object as an -arc argument"""
    return "{}={}".format(lib.importpath, lib.archive.path)
