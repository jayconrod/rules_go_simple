# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# deps.bzl exports public definitions from v4 of these rules. Later versions
# require newer, incompatible versions of Skylib, so they have their own
# deps.bzl files. Clients should load the deps.bzl for whichever version
# they need.

load(
    "@rules_go_simple//v4:deps.bzl",
    _go_rules_dependencies = "go_rules_dependencies",
)

go_rules_dependencies = _go_rules_dependencies
