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

    archives = _archives_from_facts(ctx.facts, go_highest_version)
    if archives == None:
        archives = _fetch_archives(ctx, go_highest_version)
    facts = {
        "version": go_highest_version,
        "files": archives,
    }

    # Declare a go_download repo for each archive. This contains the extracted
    # archive and a generated BUILD.bazel file with targets to compile the
    # standard library and builder. The repo rules are evaluated lazily, so
    # we should only download an archive if the corresponding toolchain
    # is selected.
    ctx.report_progress("declaring toolchains")
    download_repo_names = []
    for archive in archives:
        goos = archive["goos"]
        goarch = archive["goarch"]
        name = "go_{}_{}".format(goos, goarch)
        download_repo_names.append(name)
        go_download(
            name = name,
            urls = [archive["url"]],
            sha256 = archive["sha256"],
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
        reproducible = True,
        facts = facts,
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

def _archives_from_facts(facts, go_version):
    """Returns archive metadata from lockfile facts, or None if unusable."""
    if facts.get("version") != go_version:
        return None
    files = facts.get("files")
    if files == None:
        return None
    by_platform = {}
    for entry in files:
        key = "{}_{}".format(entry.get("goos"), entry.get("goarch"))
        by_platform[key] = entry
    archives = []
    for (goos, goarch) in _PLATFORMS:
        entry = by_platform.get("{}_{}".format(goos, goarch))
        if entry == None:
            return None
        url = entry.get("url")
        sha256 = entry.get("sha256")
        if url == None or sha256 == None:
            return None
        archives.append({
            "goos": goos,
            "goarch": goarch,
            "url": url,
            "sha256": sha256,
        })
    return archives

def _fetch_archives(ctx, go_version):
    """Downloads go.dev's release index and returns archive metadata."""
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
        if release["version"] == go_version
        for file in release["files"]
        if file["kind"] == "archive"
    ]
    if len(files) == 0:
        fail("selected Go version '{}' but no files found at {}".format(go_version, download_index_url))
    archives = []
    for (goos, goarch) in _PLATFORMS:
        compatible_files = [
            file
            for file in files
            if file["os"] == goos and
               file["arch"] == goarch and
               any([file["filename"].endswith(ext) for ext in _ALLOWED_ARCHIVE_EXTS])
        ]
        if len(compatible_files) == 0:
            fail("no files found for Go version {} compatible with {}/{}".format(go_version, goos, goarch))
        file = compatible_files[0]
        archives.append({
            "goos": goos,
            "goarch": goarch,
            "url": "https://go.dev/dl/{}".format(file["filename"]),
            "sha256": file["sha256"],
        })
    return archives

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
