# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

load("@bazel_skylib//lib:shell.bzl", "shell")

def go_compile(ctx, srcs, out, importpath = "", deps = []):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        out: output .a File.
        importpath: the path other libraries may use to import this package.
        deps: list of GoLibrary objects for direct dependencies.
    """
    toolchain = ctx.toolchains["@rules_go_simple//v5:toolchain_type"]

    args = ctx.actions.args()
    args.add("compile")
    args.add("-stdimportcfg", toolchain.internal.stdimportcfg)
    dep_infos = [d.info for d in deps]
    args.add_all(dep_infos, before_each = "-arc", map_each = _format_arc)
    if importpath:
        args.add("-p", importpath)
    args.add("-o", out)
    args.add_all(srcs)

    inputs = (srcs +
              [dep.info.archive for dep in deps] +
              [toolchain.internal.stdimportcfg] +
              toolchain.internal.tools +
              toolchain.internal.std_pkgs)
    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = toolchain.internal.builder,
        arguments = [args],
        env = toolchain.internal.env,
        mnemonic = "GoCompile",
    )

def go_link(ctx, out, main, deps = []):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        main: archive file for the main package.
        deps: list of GoLibrary objects for direct dependencies.
    """
    toolchain = ctx.toolchains["@rules_go_simple//v5:toolchain_type"]

    transitive_deps = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    inputs = ([main, toolchain.internal.stdimportcfg] +
              [d.archive for d in transitive_deps.to_list()] +
              toolchain.internal.tools +
              toolchain.internal.std_pkgs)

    args = ctx.actions.args()
    args.add("link")
    args.add("-stdimportcfg", toolchain.internal.stdimportcfg)
    args.add_all(transitive_deps, before_each = "-arc", map_each = _format_arc)
    args.add("-main", main)
    args.add("-o", out)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = toolchain.internal.builder,
        arguments = [args],
        env = toolchain.internal.env,
        mnemonic = "GoLink",
    )

def go_build_test(ctx, srcs, deps, out, rundir = "", importpath = ""):
    """Compiles and links a Go test executable.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        deps: list of GoLibrary objects for direct dependencies.
        out: output executable file.
        importpath: import path of the internal test archive.
        rundir: directory the test should change to before executing.
    """
    toolchain = ctx.toolchains["@rules_go_simple//v5:toolchain_type"]
    direct_dep_infos = [d.info for d in deps]
    transitive_dep_infos = depset(transitive = [d.deps for d in deps]).to_list()
    inputs = (srcs +
              [toolchain.internal.stdimportcfg] +
              [d.archive for d in direct_dep_infos] +
              [d.archive for d in transitive_dep_infos] +
              toolchain.internal.tools +
              toolchain.internal.std_pkgs)

    args = ctx.actions.args()
    args.add("test")
    args.add("-stdimportcfg", toolchain.internal.stdimportcfg)
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
        executable = toolchain.internal.builder,
        arguments = [args],
        env = toolchain.internal.env,
        mnemonic = "GoTest",
    )

def _format_arc(lib):
    """Formats a GoLibrary.info object as an -arc argument"""
    return "{}={}".format(lib.importpath, lib.archive.path)
