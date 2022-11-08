# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")

def declare_archive(ctx, importpath):
    """Declares a new .a file the compiler should produce.

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
    """Returns a directory that should be searched.

    This directory is passed to the compiler or linker with the -I and -L flags,
    respectively, to find the archive file for a library. The archive
    must have been declared with declare_archive.

    Args:
        info: GoLibraryInfo.info for this library.
    Returns:
        A path string for the directory.
    """
    suffix_len = len("/" + info.importpath + ".a")
    return info.archive.path[:-suffix_len]

def go_compile(ctx, importpath, srcs, out, deps = []):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        importpath: name by which the package will be imported.
        srcs: list of source Files to be compiled.
        out: output .a file. Should have the importpath as a suffix,
            for example, library "example.com/foo" should have the path
            "somedir/example.com/foo.a".
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    dep_import_args = []
    dep_archives = []
    for dep in deps:
        dep_import_args.append("-I " + shell.quote(_search_dir(dep.info)))
        dep_archives.append(dep.info.archive)

    cmd = "go tool compile -p {importpath} -o {out} {imports} -- {srcs}".format(
        importpath = importpath,
        out = shell.quote(out.path),
        imports = " ".join(dep_import_args),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = srcs + dep_archives,
        command = cmd,
        mnemonic = "GoCompile",
        use_default_shell_env = True,
    )

def go_link(ctx, out, main, deps = []):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        main: archive file for the main package.
        deps: list of GoLibraryInfo objects for direct dependencies.
    """
    deps_set = depset(
        direct = [d.info for d in deps],
        transitive = [d.deps for d in deps],
    )
    dep_lib_args = []
    dep_archives = []
    for dep in deps_set.to_list():
        dep_lib_args.append("-L " + shell.quote(_search_dir(dep)))
        dep_archives.append(dep.archive)

    cmd = "go tool link -o {out} {libs} -- {main}".format(
        out = shell.quote(out.path),
        libs = " ".join(dep_lib_args),
        main = shell.quote(main.path),
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = [main] + dep_archives,
        command = cmd,
        mnemonic = "GoLink",
        use_default_shell_env = True,
    )
