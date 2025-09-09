# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""go.bzl contains the public definition for the go module extension.

This definition may be loaded from MODULE.bazel files of projects that
use rules_go_simple.
"""

load("//internal:repo.bzl", _go_download = "go_download")

go_download = _go_download
