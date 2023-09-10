# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")

def go_compile(ctx, *, importpath, srcs, stdlib, out, deps):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        importpath: the path other libraries may use to import this package.
        srcs: list of source Files to be compiled.
        stdlib: a GoStdLibInfo provider for the standard library.
        out: output .a file. Should have the importpath as a suffix,
            for example, library "example.com/foo" should have the path
            "somedir/example.com/foo.a".
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    args = ctx.actions.args()
    args.add("compile")
    args.add("-stdimportcfg", stdlib.importcfg.path)
    dep_infos = [d.info for d in deps]
    args.add_all(dep_infos, before_each = "-arc", map_each = _format_arc)
    if importpath:
        args.add("-p", importpath)
    args.add("-o", out)
    args.add_all(srcs)

    inputs = depset(
        direct = srcs + [dep.info.archive for dep in deps],
        transitive = [stdlib.files],
    )

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        executable = ctx.executable._builder,
        arguments = [args],
        mnemonic = "GoCompile",
        use_default_shell_env = True,
    )

def go_link(ctx, *, out, stdlib, main, deps):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        stdlib: a GoStdLibInfo provider for the standard library.
        main: archive file for the main package.
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    deps_set = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    inputs = depset(
        direct = [main] + [d.archive for d in deps_set.to_list()],
        transitive = [stdlib.files],
    )

    args = ctx.actions.args()
    args.add("link")
    args.add("-stdimportcfg", stdlib.importcfg.path)
    args.add_all(deps_set, before_each = "-arc", map_each = _format_arc)
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

def go_build_test(ctx, *, importpath, srcs, stdlib, deps, out, rundir):
    """Compiles and links a Go test executable.

    Args:
        ctx: analysis context.
        importpath: import path of the internal test archive.
        srcs: list of source Files to be compiled.
        stdlib: a GoStdLibInfo provider for the standard library.
        deps: list of GoLibraryInfo objects for direct dependencies.
        out: output executable file.
        rundir: directory the test should change to before executing.
    """
    direct_dep_infos = [d.info for d in deps]
    transitive_dep_infos = depset(transitive = [d.deps for d in deps]).to_list()

    inputs = (srcs +
              stdlib.files.to_list() +
              [d.archive for d in direct_dep_infos] +
              [d.archive for d in transitive_dep_infos])

    args = ctx.actions.args()
    args.add("test")
    args.add("-stdimportcfg", stdlib.importcfg)
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

def go_build_tool(ctx, *, srcs, stdlib, out):
    """Compiles and links a Go executable to be used in the toolchain.

    Only allows a main package that depends on the standard library.
    Does not support data or other dependencies.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        stdlib: a GoStdLibInfo provider for the standard library.
        out: output executable file.
    """
    command = """
set -o errexit
export GOPATH=/dev/null  # suppress warning
go tool compile -o {out}.a -p main -importcfg {stdlib_importcfg} -- {srcs}
go tool link -o {out} -importcfg {stdlib_importcfg} -- {out}.a
""".format(
        out = shell.quote(out.path),
        stdlib_importcfg = shell.quote(stdlib.importcfg.path),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    inputs = depset(
        direct = srcs,
        transitive = [stdlib.files],
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = inputs,
        command = command,
        mnemonic = "GoToolBuild",
        use_default_shell_env = True,
    )

def _format_arc(lib):
    """Formats a GoLibraryInfo.info object as an -arc argument"""
    return "{}={}".format(lib.importpath, lib.archive.path)

def go_build_stdlib(ctx, *, out_importcfg, out_packages):
    """Builds the standard library.

    go_build_stdlib compiles the standard library from the sources installed
    on the host system. The packages are installed into a GOCACHE directory
    as an output of a Bazel action.

    Args:
        ctx: analysis context.
        out_importcfg: a Go importcfg file, mapping package paths to file paths
            for packages in the standard library. The paths are relative to
            the Bazel exec root, so this file can be used as an input to
            actions.
        out_packages: a directory containing compiled packages (.a files)
            from the standard library. The directory layout is unspecified;
            the location of each file is written in out_importcfg.
    """
    command = GO_BUILD_STDLIB_TEMPLATE.format(
        out_importcfg = shell.quote(out_importcfg.path),
        out_packages = shell.quote(out_packages.path),
    )
    ctx.actions.run_shell(
        outputs = [out_importcfg, out_packages],
        command = command,
        mnemonic = "GoStdLib",
        use_default_shell_env = True,
    )

# GO_BUILD_STDLIB_TEMPLATE is a crude Bash script that builds the standard
# library.
GO_BUILD_STDLIB_TEMPLATE = """
set -o errexit

# Dereference symbolic links in the working directory path. 'go list' below
# will print absolute paths without symbolic links. If we want to trim
# the working directory with sed, then $PWD must not contain symbolc links.
cd "$(realpath .)"

# Set GOPATH to a dummy value. This silences a warning triggered by
# $HOME not being set.
export GOPATH=/dev/null

# Set GOCACHE to the output package directory. 'go list' will write compiled
# packages here.
export GOCACHE="$(realpath {out_packages})"

# Compile packages and write the importcfg saying where they are.
# 'go list' normally doesn't build anything, but with -export, it needs to
# print output file names in the cache, and it needs to actually compile those
# files first. We use a fancy format string with -f so it tells us where those
# files are. The output file names are absolute paths, which won't be usable
# in other Bazel actions if sandboxing or remote execution are used, so we
# trim everything before $(pwd) using sed.
go list -export -f '{{{{if .Export}}}}packagefile {{{{.ImportPath}}}}={{{{.Export}}}}{{{{end}}}}' std | \
  sed -E -e "s,=$(pwd)/,=," \\
  >{out_importcfg}
"""
