# Copyright Jay Conrod. All rights reserved.
#
# This file is part of rules_go_simple. Use of this source code is governed by
# the 3-clause BSD license that can be found in the LICENSE.txt file.

# This script compiles and links a Go binary for go_tool_binary.
# It's a bash script because it's needed to build the builder binary
# that we use to implement the other rules.
param (
    [string]$executable,
    [string]$go_cmd,
    [string]$stdlib_dir
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
        if ($output -ne $null) {
            $output = $output.TrimEnd()
        }
        return $output
    } finally {
        Remove-Item $out_file, $err_file
    }
}

$lines = @()
$stdlib_abs_dir = (Resolve-Path $stdlib_dir).Path
Get-ChildItem -Path $stdlib_abs_dir -Recurse -File -FollowSymlink | ForEach-Object {
    $abs_file = $_.FullName
    $without_suffix = $abs_file -replace '\.a$', ''
    $without_prefix = $without_suffix.Substring($stdlib_abs_dir.Length+1)
    $pkg_path = $without_prefix -replace '\\', '/'
    $lines += "packagefile $pkg_path=$abs_file`n"
}
$importcfg = New-TemporaryFile
Set-Content -Path $importcfg -Value ($lines -join '')

Invoke-Exe $go_cmd tool compile -importcfg $importcfg -p main -o "$executable.a" @args
Invoke-Exe $go_cmd tool link -importcfg $importcfg -o $executable "$executable.a"
