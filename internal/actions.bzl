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

def go_compile(ctx, importpath, srcs, stdlib, out, deps = []):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        importpath: name by which the package will be imported.
        srcs: list of source Files to be compiled.
        stdlib: a GoStdLibInfo provider for the standard library.
        out: output .a file. Should have the importpath as a suffix,
            for example, library "example.com/foo" should have the path
            "somedir/example.com/foo.a".
        deps: list of GoLibraryInfo objects for direct dependencies.
    """

    dep_importcfg_text = "\n".join([
        "packagefile {importpath}={filepath}".format(
            importpath = dep.info.importpath,
            filepath = dep.info.archive.path,
        )
        for dep in deps
    ])
    command = """
set -o errexit
export GOPATH=/dev/null  # suppress warning
importcfg=$(mktemp)
cat >"${{importcfg}}" {stdlib_importcfg} - <<'EOF'
{dep_importcfg_text}
EOF
go tool compile -o {out} -p {importpath} -importcfg "${{importcfg}}" -- {srcs}
rm "${{importcfg}}"
""".format(
        stdlib_importcfg = shell.quote(stdlib.importcfg.path),
        dep_importcfg_text = dep_importcfg_text,
        out = shell.quote(out.path),
        importpath = shell.quote(importpath),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    inputs = depset(
        direct = srcs + [dep.info.archive for dep in deps],
        transitive = [stdlib.files],
    )

    ctx.actions.run_shell(
        outputs = [out],
        inputs = inputs,
        command = command,
        mnemonic = "GoCompile",
        use_default_shell_env = True,
    )

def go_link(ctx, out, stdlib, main, deps = []):
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
    dep_importcfg_text = "\n".join([
        "packagefile {importpath}={filepath}".format(
            importpath = dep.importpath,
            filepath = dep.archive.path,
        )
        for dep in deps_set.to_list()
    ])
    command = """
set -o errexit
export GOPATH=/dev/null  # suppress warning
importcfg=$(mktemp)
cat >"${{importcfg}}" {stdlib_importcfg} - <<'EOF'
{dep_importcfg_text}
EOF
go tool link -o {out} -importcfg "${{importcfg}}" -- {main}
""".format(
        stdlib_importcfg = shell.quote(stdlib.importcfg.path),
        dep_importcfg_text = dep_importcfg_text,
        out = shell.quote(out.path),
        main = shell.quote(main.path),
    )
    inputs = depset(
        direct = [main] + [d.archive for d in deps_set.to_list()],
        transitive = [stdlib.files],
    )

    ctx.actions.run_shell(
        outputs = [out],
        inputs = inputs,
        command = command,
        mnemonic = "GoLink",
        use_default_shell_env = True,
    )

def go_build_stdlib(ctx, out_importcfg, out_packages):
    """Builds the standard library.

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
  sed -E -e "s,=$(pwd)/,=," \
  >{out_importcfg}
"""
