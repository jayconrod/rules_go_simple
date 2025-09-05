# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")

def go_compile(ctx, *, srcs, importpath, stdlib, out):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        importpath: the path other libraries may use to import this package.
        stdlib: a File for the compiled standard library directory.
        out: output .a File.
    """

    cmd = r"""
    importcfg=$(mktemp)
    pushd {stdlib} >/dev/null
    for file in $(find -L . -type f); do
      without_suffix="${{file%.a}}"
      pkg_path="${{without_suffix#./}}"
      abs_file="$PWD/$file"
      printf "packagefile %s=%s\n" "$pkg_path" "$abs_file" >>"$importcfg"
    done
    popd >/dev/null
    go tool compile -o {out} -p {importpath} -importcfg "$importcfg" -- {srcs}
    """.format(
        stdlib = shell.quote(stdlib.path),
        out = shell.quote(out.path),
        importpath = shell.quote(importpath),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    ctx.actions.run_shell(
        mnemonic = "GoCompile",
        outputs = [out],
        inputs = srcs + [stdlib],
        command = cmd,
        env = {"GOPATH": "/dev/null"},  # suppress warning
        use_default_shell_env = True,
    )

def go_link(ctx, *, main, stdlib, out):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        main: archive file for the main package.
        stdlib: a File for the compile standard library directory.
        out: output executable file.
    """
    cmd = r"""
    importcfg=$(mktemp)
    pushd {stdlib} >/dev/null
    for file in $(find -L . -type f); do
      without_suffix="${{file%.a}}"
      pkg_path="${{without_suffix#./}}"
      abs_file="$PWD/$file"
      printf "packagefile %s=%s\n" "$pkg_path" "$abs_file" >>"$importcfg"
    done
    popd >/dev/null
    go tool link -o {out} -importcfg "$importcfg" -- {main}
    """.format(
        stdlib = shell.quote(stdlib.path),
        main = shell.quote(main.path),
        out = shell.quote(out.path),
    )
    ctx.actions.run_shell(
        mnemonic = "GoLink",
        outputs = [out],
        inputs = [main, stdlib],
        command = cmd,
        env = {"GOPATH": "/dev/null"},  # suppress warning
        use_default_shell_env = True,
    )
