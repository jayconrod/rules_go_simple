# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Providers returned by Go rules.

Providers are objects produced by rules, consumed by rules they depend on.
Each provider holds some metadata about the rule. For example, most rules
provide DefaultInfo, a built-in provider that contains a list of output files.
"""

GoLibraryInfo = provider(
    doc = "Contains information about a Go library",
    fields = {
        "info": """A struct containing information about this library.
        Has the following fields:
            importpath: Name by which the library may be imported.
            archive: The .a file compiled from the library's sources.
        """,
        "deps": "A depset of info structs for this library's dependencies",
        "files": """A depset of files containing this library and everything
        it transitively imports.""",
    },
)

# GoToolchainInfo is a dummy provider that serves as documentation for the
# public interface of the ToolchainInfo provide returned by go_toolchain.
# Toolchains compatible with @rules_go_simple//:toolchain_type must
# satisfy this interface. However, no GoToolchainInfo object is actually created.
GoToolchainInfo = provider(
    doc = "Contains information about a Go toolchain",
    fields = {
        "compile": """Function that compiles a Go package from sources.

        Args:
            ctx: analysis context.
            srcs: list of source Files to be compiled.
            out: output .a file.
            importpath: the path other libraries may use to import this package.
            deps: list of GoLibraryInfo objects for direct dependencies.
        """,
        "link": """Function that links a Go executable.

        Args:
            ctx: analysis context.
            out: ouptut executable file.
            main: archive File for the main package.
            deps: list of GoLibraryInfo objects for direct dependencies.
        """,
        "build_test": """Function that compiles and links a test executable.

        Args:
            ctx: analysis context.
            srcs: list of source Files to be compiled.
            deps: list of GoLibraryInfo objects for direct dependencies.
            out: output executable file.
            importpath: import path of the internal test archive.
            rundir: directory the test should change to before executing.
        """,
    },
)
