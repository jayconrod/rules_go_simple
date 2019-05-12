# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

load("@bazel_skylib//:lib.bzl", "shell")

def declare_archive(ctx, importpath):
    """Declares a new .a file the compiler should produce, following a naming
    convention.

    .a files are consumed by the compiler (for dependency type information)
    and the linker. Both tools locate archives using lists of search paths.
    Archives must be named according to their importpath. For example,
    library "example.com/foo" must be named "<searchdir>/example.com/foo.a".

    Args:
        ctx: analysis context.
        importpath: the name by which the library may be imported.
    Returns:
        A File that should be written by the compiler.
    """
    return ctx.actions.declare_file("{name}%/{importpath}.a".format(
        name = ctx.label.name,
        importpath = importpath,
    ))

def _search_dir(info):
    """Returns a directory that should be searched (by -I to the compiler
    or -L to the linker) to find the archive file for a library. The archive
    must have been declared with declare_archive.

    Args:
        info: GoLibrary.info for this library.
    Returns:
        A path string for the directory.
    """
    suffix_len = len("/" + info.importpath + ".a")
    return info.archive.path[:-suffix_len]

def go_compile(ctx, srcs, out, importpath = "", deps = []):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        out: output .a file. Should have the importpath as a suffix,
            for example, library "example.com/foo" should have the path
            "somedir/example.com/foo.a".
        importpath: the path other libraries may use to import this package.
        deps: list of GoLibrary objects for direct dependencies.
    """
    args = ctx.actions.args()
    args.add("compile")
    args.add("-stdimportcfg", ctx.file._stdimportcfg)
    dep_infos = [d.info for d in deps]
    args.add_all(dep_infos, before_each = "-arc", map_each = _format_arc)
    if importpath:
        args.add("-p", importpath)
    args.add("-o", out)
    args.add_all(srcs)

    inputs = srcs + [dep.info.archive for dep in deps] + [ctx.file._stdimportcfg]
    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = ctx.executable._builder,
        arguments = [args],
        mnemonic = "GoCompile",
        use_default_shell_env = True,
    )

def go_link(ctx, out, main, deps = []):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        main: archive file for the main package.
        deps: list of GoLibrary objects for direct dependencies.
    """
    transitive_deps = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    inputs = [main, ctx.file._stdimportcfg] + [d.archive for d in transitive_deps.to_list()]

    args = ctx.actions.args()
    args.add("link")
    args.add("-stdimportcfg", ctx.file._stdimportcfg)
    args.add_all(transitive_deps, before_each = "-arc", map_each = _format_arc)
    args.add("-main", main)
    args.add("-o", out)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = ctx.executable._builder,
        arguments = [args],
        mnemonic = "GoLink",
        use_default_shell_env = True,
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
    direct_dep_infos = [d.info for d in deps]
    transitive_dep_infos = depset(transitive = [d.deps for d in deps]).to_list()
    inputs = (srcs +
              [ctx.file._stdimportcfg] +
              [d.archive for d in direct_dep_infos] +
              [d.archive for d in transitive_dep_infos])

    args = ctx.actions.args()
    args.add("test")
    args.add("-stdimportcfg", ctx.file._stdimportcfg)
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
        executable = ctx.executable._builder,
        arguments = [args],
        mnemonic = "GoTest",
        use_default_shell_env = True,
    )

def go_build_tool(ctx, srcs, out):
    """Compiles and links a Go executable to be used in the toolchain.

    Only allows a main package that depends on the standard library.
    Does not support data or other dependencies.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        out: output executable file.
    """
    cmd_tpl = ("go tool compile -o {out}.a {srcs} && " +
               "go tool link -o {out} {out}.a")
    cmd = cmd_tpl.format(
        out = shell.quote(out.path),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = srcs,
        command = cmd,
        mnemonic = "GoToolBuild",
        use_default_shell_env = True,
    )

def go_write_stdimportcfg(ctx, out):
    """Generates the importcfg mapping standard library import paths to
    archive files. Every compile and link action needs this.

    Args:
        ctx: analysis context.
        out: output importcfg file.
    """
    ctx.actions.run(
        outputs = [out],
        arguments = ["stdimportcfg", "-o", out.path],
        executable = ctx.executable._builder,
        mnemonic = "GoStdImportcfg",
        use_default_shell_env = True,
    )
    

def _format_arc(lib):
    """Formats a GoLibrary.info object as an -arc argument"""
    return "{}={}".format(lib.importpath, lib.archive.path)
