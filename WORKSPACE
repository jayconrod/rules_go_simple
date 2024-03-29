# The WORKSPACE file should appear in the root directory of the repository.
# Its job is to configure external repositories, which are declared
# with repository rules. We also register toolchains here.
#
# This file is only evaluated for builds in *this* repository, not for builds in
# other repositories that depend on this one.

# Each workspace should set a canonical name. This is the name other workspaces
# may use to import it (via an http_archive rule or something similar).
# It's also the name used in labels that refer to this workspace
# (for example @rules_go_simple//:deps.bzl).
workspace(name = "rules_go_simple")

load(
    "@rules_go_simple//:deps.bzl",
    "go_download",
    "go_rules_dependencies",
)

# go_rules_dependencies declares the dependencies of rules_go_simple. Any
# project that depends on rules_go_simple should call this.
go_rules_dependencies()

# These rules download Go distributions for macOS and Linux.
# They are lazily evaluated, so they won't actually download anything until
# we depend on a target inside these workspaces. We register toolchains
# below though, so that forces downloads. We could be more clever
# about registering only the toolchain we need.
go_download(
    name = "go_darwin_arm64",
    goarch = "arm64",
    goos = "darwin",
    sha256 = "49e394ab92bc6fa3df3d27298ddf3e4491f99477bee9dd4934525a526f3a391c",
    urls = ["https://go.dev/dl/go1.19.3.darwin-arm64.tar.gz"],
)

go_download(
    name = "go_linux_amd64",
    goarch = "amd64",
    goos = "linux",
    sha256 = "74b9640724fd4e6bb0ed2a1bc44ae813a03f1e72a4c76253e2d5c015494430ba",
    urls = ["https://go.dev/dl/go1.19.3.linux-amd64.tar.gz"],
)

# register_toolchains makes one or more toolchain rules available for Bazel's
# automatic toolchain selection. Bazel will pick whichever toolchain is
# compatible with the execution and target platforms.
register_toolchains(
    "@go_darwin_arm64//:toolchain",
    "@go_linux_amd64//:toolchain",
)
