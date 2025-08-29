# Copyright Jay Conrod. All rights reserved.
#
# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# This script compiles the Go standard library for go_stdlib on Windows.
# It's a powershell script because we can't compile or run any Gio code before
# compiling the standard library.
param (
    [string]$go_cmd,
    [string]$pkg_dir
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"
Set-StrictMode -Version latest

<#
.SYNOPSIS
Executes a command with a list of arguments and returns the output string.

.DESCRIPTION
This function is used as a replacement for the call operator (&). For some
unknown reason, when this script is invoked within a Bazel action and the call
operator invokes the go command, it does nothing and produces no output.
Start-Process works, even though it's much more verbose.
#>
function Invoke-Exe {
    param(
        [string]$exe
    )

    $out_file = New-TemporaryFile
    $err_file = New-TemporaryFile
    try {
        $proc = Start-Process -FilePath $exe `
                              -ArgumentList $args `
                              -NoNewWindow -Wait -PassThru `
                              -RedirectStandardOutput $out_file `
                              -RedirectStandardError $err_file
        if ($proc.ExitCode -ne 0) {
            $err_msg = Get-Content $err_file -Raw
            throw "Command failed with exit code $($proc.ExitCode): $exe $args`n$err_msg"
        }
        $output = Get-Content $out_file -Raw
        return $output.TrimEnd()
    } finally {
        Remove-Item $out_file, $err_file
    }
}

# Create the GOCACHE and GOROOT directories, and delete them on exit.
$orig_goroot = Invoke-Exe $go_cmd env GOROOT
$env:GOTOOLDIR = Invoke-Exe $go_cmd env GOTOOLDIR
$env:GOCACHE = Join-Path $env:Temp $(New-Guid)
$env:GOROOT = Join-Path $env:Temp $(New-Guid)
Register-EngineEvent Powershell.Exiting -Action {
    Remove-Item -Recurse -Force $env:GOCACHE
    Remove-Item -Recurse -Force $env:GOROOT
} | Out-Null

# Copy the source tree. When this runs as an action, Bazel constructs a source
# tree for the action with a mix of symbolic links and junctions; remote
# executors may do something else. The Go command does not allow symbolic links
# when processing embedded files, so we need to make a source tree full of
# real files. Copy-Item makes copies; unfortunately, we can't use it to create
# hard links as we do on Linux. Hard links are not reliable on Windows anyway:
# they can't always be deleted, and there's a small, limited number of links
# per file.
Copy-Item -Recurse -Force $orig_goroot $env:GOROOT

# # Compile the packages in the standard library.
# # Instead of 'go build std' we use 'go list -export std' because we want to
# # know the names of the compiled files.
New-Item -ItemType Directory -Force -Path $pkg_dir
$list_output = Invoke-Exe $go_cmd list -export -f '{{.ImportPath}}={{.Export}}' std

# Move the compiled files out of the cache.
foreach ($line in $list_output -split "`n") {
    if ($line -match "=") {
        $parts = $line -split "="
        $pkg_path = $parts[0]
        $cache_file = $parts[1]
        if ([string]::IsNullOrEmpty($cache_file)) {
            continue # skip fake packages like unsafe
        }

        $pkg_file = Join-Path $pkg_dir ($pkg_path + ".a")
        $pkg_dirname = Split-Path $pkg_file -Parent
        New-Item -ItemType Directory -Force -Path $pkg_dirname
        Move-Item -Force $cache_file $pkg_file
    }
}
