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
# below though, so that forces both downloads. We could be more clever
# about registering only the toolchain we need.
go_download(
    name = "go_darwin_amd64",
    goarch = "amd64",
    goos = "darwin",
    sha256 = "a9088c44a984c4ba64179619606cc65d9d0cb92988012cfc94fbb29ca09edac7",
    urls = ["https://dl.google.com/go/go1.13.4.darwin-amd64.tar.gz"],
)

go_download(
    name = "go_linux_amd64",
    goarch = "amd64",
    goos = "linux",
    sha256 = "692d17071736f74be04a72a06dab9cac1cd759377bd85316e52b2227604c004c",
    urls = ["https://dl.google.com/go/go1.13.4.linux-amd64.tar.gz"],
)

# register_toolchains makes one or more toolchain rules available for Bazel's
# automatic toolchain selection. Bazel will pick whichever toolchain is
# compatible with the execution and target platforms.
register_toolchains(
    "@go_darwin_amd64//:toolchain",
    "@go_linux_amd64//:toolchain",
)
