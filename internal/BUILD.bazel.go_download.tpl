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

# stdlib compiles packages in the standard library.
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
    visibility = ["//visibility:public"],
)

# builder is an executable used by rules_go_simple to perform most actions.
# builder mostly acts as a wrapper around the compiler and linker.
go_tool_binary(
    name = "builder",
    srcs = ["@rules_go_simple//internal/builder:builder_srcs"],
    stdlib = ":stdlib",
    tools = [":tools"],
    visibility = ["//visibility:public"],
)

# EXERCISE: declare a toolchain and a toolchain implementation.
