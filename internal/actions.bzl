# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

def go_compile(ctx, *, importpath, srcs, out, deps):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        importpath: the path other libraries may use to import this package.
        srcs: list of source Files to be compiled.
        out: output .a File.
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]

    args = ctx.actions.args()
    args.add("compile")
    args.add("-stdimportcfg", toolchain.internal.stdlib.importcfg)
    dep_infos = [d.info for d in deps]
    args.add_all(dep_infos, before_each = "-arc", map_each = _format_arc)
    if importpath:
        args.add("-p", importpath)
    args.add("-o", out)
    args.add_all(srcs)

    inputs = depset(
        direct = srcs + [dep.info.archive for dep in deps],
        transitive = [toolchain.internal.files],
    )
    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = toolchain.internal.builder,
        arguments = [args],
        env = toolchain.internal.env,
        mnemonic = "GoCompile",
    )

def go_link(ctx, *, out, main, deps):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        main: archive file for the main package.
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]

    transitive_deps = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    inputs = depset(
        direct = [main],
        transitive = [dep.files for dep in deps] + [toolchain.internal.files],
    )

    args = ctx.actions.args()
    args.add("link")
    args.add("-stdimportcfg", toolchain.internal.stdlib.importcfg)
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

def go_build_test(ctx, *, importpath, srcs, deps, out, rundir):
    """Compiles and links a Go test executable.

    Args:
        ctx: analysis context.
        importpath: import path of the internal test archive.
        srcs: list of source Files to be compiled.
        deps: list of GoLibraryInfo objects for direct dependencies.
        out: output executable file.
        rundir: directory the test should change to before executing.
    """
    toolchain = ctx.toolchains["@rules_go_simple//:toolchain_type"]
    direct_dep_infos = [d.info for d in deps]
    transitive_dep_infos = depset(transitive = [d.deps for d in deps]).to_list()

    inputs = depset(
        direct = srcs,
        transitive = [dep.files for dep in deps] + [toolchain.internal.files],
    )

    args = ctx.actions.args()
    args.add("test")
    args.add("-stdimportcfg", toolchain.internal.stdlib.importcfg)
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

def go_build_stdlib(ctx, *, srcs, tools, build_stdlib, out_importcfg, out_packages):
    """Builds the standard library.

    Args:
        ctx: analysis context.
        srcs: list of source Files for packages in the standard library.
        tools: list of executable Files for tools shipped as part of the
            Go distribution.
        build_stdlib: script File used to build the standard library.
        out_importcfg: a Go importcfg file, mapping package paths to file paths
            for packages in the standard library. The paths are relative to
            the Bazel exec root, so this file can be used as an input to
            actions.
        out_packages: a directory containing compiled packages (.a files)
            from the standard library. The directory layout is unspecified;
            the location of each file is written in out_importcfg.
    """
    goroot = None
    go_mod_suffix = "/src/go.mod"
    for src in srcs:
        if src.path.endswith(go_mod_suffix):
            goroot = src.path[:-len(go_mod_suffix)]
    if not goroot:
        fail("could not determine GOROOT")
    inputs = srcs + tools
    arguments = [
        out_packages.path,
        out_importcfg.path,
    ]
    ctx.actions.run(
        outputs = [out_importcfg, out_packages],
        inputs = inputs,
        executable = build_stdlib,
        env = {"GOROOT": goroot},
        arguments = arguments,
        mnemonic = "GoStdLib",
    )

def go_build_tool(ctx, *, srcs, stdlib, tools, build_tool, out):
    """Compiles and links a Go executable to be used in the toolchain.

    Only allows a main package that depends on the standard library.
    Does not support data or other dependencies.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        stdlib: a GoStdLibInfo provider for the standard library.
        tools: list of executable Files for tools shipped as part of the
            Go distribution.
        build_tool: script used to build tools.
        out: output executable file.
    """
    compiler = find_tool("compile", tools)
    linker = find_tool("link", tools)
    inputs = depset(
        direct = srcs + tools,
        transitive = [stdlib.files],
    )
    arguments = [
        compiler.path,
        linker.path,
        stdlib.importcfg.path,
        out.path,
    ] + [src.path for src in srcs]
    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = build_tool,
        arguments = arguments,
        mnemonic = "GoToolBuild",
    )

def find_tool(name, tools):
    """Finds an executable file by name in the given list of Files.

    A File is returned if its basename is name, possibly with an ".exe" suffix.

    Args:
        name: the name of the tool to find, like "compile".
        tools: a list of Files to search.

    Returns:
        A File from tools whose basename is name, possibly with an ".exe" suffix.
    """
    for tool in tools:
        if tool.basename == name or tool.basename == name + ".exe":
            return tool
    fail("could not locate tool: {name}".format(name = name))

def _format_arc(lib):
    """Formats a GoLibraryInfo.info object as an -arc argument"""
    return "{}={}".format(lib.importpath, lib.archive.path)
