# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Starlark utility functions, used in multiple .bzl files."""

def find_go_cmd(tools):
    for f in tools:
        if f.path.endswith("/bin/go") or f.path.endswith("/bin/go.exe"):
            return f
    fail("could not locate go tool")
