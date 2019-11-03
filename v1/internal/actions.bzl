# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

load("@bazel_skylib//lib:shell.bzl", "shell")

def go_compile(ctx, srcs, out):
    """Compiles a single Go package from sources.

    Args:
        ctx: analysis context.
        srcs: list of source Files to be compiled.
        out: output .a file. Should have the importpath as a suffix,
            for example, library "example.com/foo" should have the path
            "somedir/example.com/foo.a".
    """
    cmd = "go tool compile -o {out} -- {srcs}".format(
        out = shell.quote(out.path),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = srcs,
        command = cmd,
        mnemonic = "GoCompile",
        use_default_shell_env = True,
    )

def go_link(ctx, out, main):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        out: output executable file.
        main: archive file for the main package.
    """
    cmd = "go tool link -o {out} -- {main}".format(
        out = shell.quote(out.path),
        main = shell.quote(main.path),
    )
    ctx.actions.run_shell(
        outputs = [out],
        inputs = [main],
        command = cmd,
        mnemonic = "GoLink",
        use_default_shell_env = True,
    )
