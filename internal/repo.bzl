# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

def _go_download_impl(ctx):
    # Download the Go distribution.
    # Execute 'tar x' explicitly instead of using ctx.download_and_extract.
    # The Go archive contains test files with invalid unicode names,
    # which ctx.download_and_extract does not tolerate.
    ctx.report_progress("downloading")
    ctx.download(
        ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        output = "go.tar.gz",
    )
    ctx.report_progress("extracting")
    ctx.execute(["tar", "xf", "go.tar.gz", "--strip-components=1"])
    ctx.delete("go.tar.gz")

    # Add a build file to the repository root directory.
    # We need to fill in some template parameters, based on the platform.
    ctx.report_progress("generating build file")
    if ctx.attr.goos == "darwin":
        os_constraint = "@platforms//os:osx"
    elif ctx.attr.goos == "linux":
        os_constraint = "@platforms//os:linux"
    elif ctx.attr.goos == "windows":
        os_constraint = "@platforms//os:windows"
    else:
        fail("unsupported goos: " + ctx.attr.goos)
    if ctx.attr.goarch == "amd64":
        arch_constraint = "@platforms//cpu:x86_64"
    elif ctx.attr.goarch == "arm64":
        arch_constraint = "@platforms//cpu:arm64"
    else:
        fail("unsupported arch: " + ctx.attr.goarch)
    constraints = [os_constraint, arch_constraint]
    constraint_str = ",\n        ".join(['"%s"' % c for c in constraints])

    substitutions = {
        "{goos}": ctx.attr.goos,
        "{goarch}": ctx.attr.goarch,
        "{exe}": ".exe" if ctx.attr.goos == "windows" else "",
        "{exec_constraints}": constraint_str,
        "{target_constraints}": constraint_str,
    }
    ctx.template(
        "BUILD.bazel",
        ctx.attr._build_tpl,
        substitutions = substitutions,
    )

go_download = repository_rule(
    implementation = _go_download_impl,
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "List of mirror URLs where a Go distribution archive can be downloaded",
        ),
        "sha256": attr.string(
            mandatory = True,
            doc = "Expected SHA-256 sum of the downloaded archive",
        ),
        "goos": attr.string(
            mandatory = True,
            values = ["darwin", "linux", "windows"],
            doc = "Host operating system for the Go distribution",
        ),
        "goarch": attr.string(
            mandatory = True,
            values = ["amd64", "arm64"],
            doc = "Host architecture for the Go distribution",
        ),
        "_build_tpl": attr.label(
            default = "@rules_go_simple//internal:BUILD.dist.bazel.tpl",
        ),
    },
    doc = "Downloads a standard Go distribution and installs a build file",
)
