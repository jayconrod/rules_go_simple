# The WORKSPACE file should appear in the root directory of the repository.
# It's job is to configure external repositories, which are declared
# with repository rules. This file is only evaluated for builds in *this*
# repository, not for builds in other repositories that depend on this one.
# For this reason, we declare dependencies in a macro that can be loaded
# here *and* in other repositories' WORKSPACE files.

workspace(name = "rules_go_simple")

load("@rules_go_simple//:deps.bzl", "go_rules_dependencies")

go_rules_dependencies()
