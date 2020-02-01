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
    },
)
