# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Common functions for creating actions to build Go programs.

Rules should determine input and output files and providers, but they should
call functions to create actions. This allows action code to be shared
by multiple rules.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")

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

    dep_importcfg_text = "\n".join([
        "packagefile {importpath}={filepath}".format(
            importpath = dep.info.importpath,
            filepath = dep.info.archive.path,
        )
        for dep in deps
    ])
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
cat >>"$importcfg" <<'EOF'
{dep_importcfg_text}
EOF
go tool compile -o {out} -p {importpath} -importcfg "$importcfg" -- {srcs}
""".format(
        stdlib = shell.quote(stdlib.path),
        dep_importcfg_text = dep_importcfg_text,
        out = shell.quote(out.path),
        importpath = shell.quote(importpath),
        srcs = " ".join([shell.quote(src.path) for src in srcs]),
    )

    inputs = srcs + [stdlib] + [dep.info.archive for dep in deps]
    ctx.actions.run_shell(
        mnemonic = "GoCompile",
        outputs = [out],
        inputs = inputs,
        command = cmd,
        env = {"GOPATH": "/dev/null"},  # suppress warning
        use_default_shell_env = True,
    )

def go_link(ctx, *, main, stdlib, deps, out):
    """Links a Go executable.

    Args:
        ctx: analysis context.
        main: archive file for the main package.
        stdlib: a File for the compiled standard library directory.
        deps: list of GoLibraryInfo objects for direct dependencies.
        out: output executable file.
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
    cmd = r"""
importcfg=$(mktemp)
pushd {stdlib} >/dev/null
for file in $(find -L . -type f); do
  without_suffix="${{file%.a}}"
  pkg_path="${{without_suffix#./}}"
  abs_file="$PWD/$file"
  printf "packagefile %s=%s\n" "$pkg_path" "$abs_file" >>"$importcfg"
done
cat >>"$importcfg" <<'EOF'
{dep_importcfg_text}
EOF
popd >/dev/null
go tool link -o {out} -importcfg "$importcfg" -- {main}
""".format(
        stdlib = shell.quote(stdlib.path),
        dep_importcfg_text = dep_importcfg_text,
        main = shell.quote(main.path),
        out = shell.quote(out.path),
    )
    inputs = [main, stdlib] + [d.archive for d in deps_set.to_list()]
    ctx.actions.run_shell(
        mnemonic = "GoLink",
        outputs = [out],
        inputs = inputs,
        command = cmd,
        env = {"GOPATH": "/dev/null"},  # suppress warning
        use_default_shell_env = True,
    )
