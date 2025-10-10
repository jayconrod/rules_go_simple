# Copyright Jay Conrod. All rights reserved.

# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

"""Internal definitions for the go module extension"""

load(":repo.bzl", "go_download", "go_toolchains")

_PLATFORMS = [
    ("darwin", "arm64"),
    ("linux", "amd64"),
    ("linux", "arm64"),
    ("windows", "amd64"),
]

_ALLOWED_ARCHIVE_EXTS = [
    ".tar.gz",
    ".zip",
]

def _go_impl(ctx):
    # Pick a version of Go to use. Different MODULE.bazel files may declare
    # go.download tags with different versions, so pick the highest declared
    # version. Report an error if no version was requested.
    ctx.report_progress("selecting a version")
    highest_version = None
    for module in ctx.modules:
        for tag in module.tags.download:
            version = _parse_version(tag.version)
            if version == None:
                fail("module {} has download tag with invalid version '{}'".format(
                    module.name,
                    version,
                ))
            if highest_version == None or _compare_versions(version, highest_version) > 0:
                highest_version = version
    if highest_version == None:
        fail("go extension used without specifying a version. Declare a go.download tag with your desired version.")
    go_highest_version = "go{}.{}.{}".format(highest_version.major, highest_version.minor, highest_version.patch)

    # Download and parse an index of downloadable archives.
    download_index_url = "https://go.dev/dl/?mode=json&include=all"
    ctx.report_progress("checking available files at {}".format(download_index_url))
    ctx.download(
        url = [download_index_url],
        output = "versions.json",
    )
    data = ctx.read("versions.json")
    releases = json.decode(data)
    files = [
        file
        for release in releases
        if release["version"] == go_highest_version
        for file in release["files"]
        if file["kind"] == "archive"
    ]

    if len(files) == 0:
        fail("selected Go version '{}' but no files found at {}".format(go_highest_version, download_index_url))

    # Declare a go_download repo for each archive. This contains the extracted
    # archive and a generated BUILD.bazel file with targets to compile the
    # standard library and builder. The repo rules are evaluated lazily, so
    # we should only download an archive if the corresponding toolchain
    # is selected.
    ctx.report_progress("declaring toolchains")
    download_repo_names = []
    for (goos, goarch) in _PLATFORMS:
        compatible_files = [
            file
            for file in files
            if file["os"] == goos and
               file["arch"] == goarch and
               any([file["filename"].endswith(ext) for ext in _ALLOWED_ARCHIVE_EXTS])
        ]
        if len(compatible_files) == 0:
            fail("no files found for Go version {} compatible with {}/{}".format(go_highest_version, goos, goarch))
        url = "https://go.dev/dl/{}".format(compatible_files[0]["filename"])
        sha256 = compatible_files[0]["sha256"]

        name = "go_{}_{}".format(goos, goarch)
        download_repo_names.append(name)
        go_download(
            name = name,
            urls = [url],
            sha256 = sha256,
            goos = goos,
            goarch = goarch,
        )

    # Declare the go_toolchains repo containing all toolchains. It's important
    # that this is separate from the go_download repos so that we only download
    # archives for the toolchains that are actually selected.
    go_toolchains(
        name = "go_toolchains",
        repos = download_repo_names,
        goos_goarchs = ["{}_{}".format(*platform) for platform in _PLATFORMS],
    )

    return ctx.extension_metadata(
        # versions.json may change upstream, so we need to record sha256 sums
        # of downloaded archives in MODULE.bazel.lock. Setting this to True
        # would prevent that.
        reproducible = False,
    )

_download_tag = tag_class(
    attrs = {
        "version": attr.string(),
    },
    doc = """
Specifies the desired version of Go to download.

The go module extension selects the highest listed version in any module.
""",
)

go = module_extension(
    implementation = _go_impl,
    tag_classes = {
        "download": _download_tag,
    },
    os_dependent = False,
    arch_dependent = False,
    doc = """
Selects and downloads Go toolchain archives from go.dev and registers
appropriate Bazel toolchains. Archives are downloaded lazily, only for the
toolchains that Bazel selects at build time.
""",
)

def _parse_version(v):
    """Parses a semantic version string like '1.2.3'.

    Returns a struct with fields "major", "minor", and "patch".
    """
    parts = v.split(".")
    if len(parts) != 3 or any([not c.isdigit() for part in parts for c in part.elems()]):
        return None
    return struct(major = parts[0], minor = parts[1], patch = parts[2])

def _compare_versions(a, b):
    """Compares two version structs returned by _parse_version.

    Returns positive if the first argument is higher, negative if the second
    is higher, or zero if the arguments are equal.
    """
    diff = a.major - b.major
    if diff != 0:
        return diff
    diff = a.minor - b.minor
    if diff != 0:
        return diff
    return a.patch - b.patch
