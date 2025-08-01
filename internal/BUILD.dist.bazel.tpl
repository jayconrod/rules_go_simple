# This template is used by go_download to generate a build file for
# a downloaded Go distribution.

load("@rules_go_simple//:def.bzl", "go_toolchain")
load(
    "@rules_go_simple//internal:rules.bzl",
    "go_stdlib",
    "go_tool_binary",
)

# tools contains executable files that are part of the toolchain.
filegroup(
    name = "tools",
    srcs = ["bin/go{exe}"] + glob(["pkg/tool/{goos}_{goarch}/**"]),
    visibility = ["//visibility:public"],
)

go_stdlib(
    name = "stdlib",
    srcs = glob(
        [
            "src/**",
            "pkg/include/**",
        ],
        exclude = ["src/cmd/**"],
    ),
    tools = [":tools"],
)

# builder is an executable used by rules_go_simple to perform most actions.
# builder mostly acts as a wrapper around the compiler and linker.
go_tool_binary(
    name = "builder",
    srcs = ["@rules_go_simple//internal/builder:builder_srcs"],
    stdlib = ":stdlib",
    tools = [":tools"],
)

# toolchain_impl gathers information about the Go toolchain.
# See the GoToolchain provider.
go_toolchain(
    name = "toolchain_impl",
    builder = ":builder",
    stdlib = ":stdlib",
    tools = [":tools"],
)

# toolchain is a Bazel toolchain that expresses execution and target
# constraints for toolchain_impl. This target should be registered by
# calling register_toolchains in a WORKSPACE file.
toolchain(
    name = "toolchain",
    exec_compatible_with = [
        {exec_constraints},
    ],
    target_compatible_with = [
        {target_constraints},
    ],
    toolchain = ":toolchain_impl",
    toolchain_type = "@rules_go_simple//:toolchain_type",
)
