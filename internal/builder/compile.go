// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"flag"
	"fmt"
	"go/build"
	"os"
	"os/exec"
	"path/filepath"
)

// compile produces a Go archive file (.a) from a list of .go sources.  This
// function will filter sources using build constraints (OS and architecture
// file name suffixes and +build comments) and will build an importcfg file
// before invoking the Go compiler.
func compile(args []string) error {
	// Process command line arguments.
	var stdImportcfgPath, packagePath, outPath string
	var archives []archive
	fs := flag.NewFlagSet("compile", flag.ExitOnError)
	fs.StringVar(&stdImportcfgPath, "stdimportcfg", "", "path to importcfg for the standard library")
	fs.Var(archiveFlag{&archives}, "arc", "information about dependencies, formatted as packagepath=file (may be repeated)")
	fs.StringVar(&packagePath, "p", "", "package path for the package being compiled")
	fs.StringVar(&outPath, "o", "", "path to archive file the compiler should produce")
	fs.Parse(args)
	srcPaths := fs.Args()

	// Extract metadata from source files and filter out sources using
	// build constraints.
	srcs := make([]sourceInfo, 0, len(srcPaths))
	filteredSrcPaths := make([]string, 0, len(srcPaths))
	bctx := &build.Default
	for _, srcPath := range srcPaths {
		if src, err := loadSourceInfo(bctx, srcPath); err != nil {
			return err
		} else if src.match {
			srcs = append(srcs, src)
			filteredSrcPaths = append(filteredSrcPaths, srcPath)
		}
	}

	// Build an importcfg file that maps this package's imports to archive files
	// from the standard library or direct dependencies.
	stdArchiveMap, err := readImportcfg(stdImportcfgPath)
	if err != nil {
		return err
	}

	directArchiveMap := make(map[string]string)
	for _, arc := range archives {
		directArchiveMap[arc.packagePath] = arc.filePath
	}

	archiveMap := make(map[string]string)
	for _, src := range srcs {
		for _, imp := range src.imports {
			switch {
			case imp == "unsafe":
				continue

			case imp == "C":
				return fmt.Errorf("%s: cgo not supported", src.fileName)

			case stdArchiveMap[imp] != "":
				archiveMap[imp] = stdArchiveMap[imp]

			case directArchiveMap[imp] != "":
				archiveMap[imp] = directArchiveMap[imp]

			default:
				return fmt.Errorf("%s: import %q is not provided by any direct dependency", src.fileName, imp)
			}
		}
	}
	importcfgPath, err := writeTempImportcfg(archiveMap)
	if err != nil {
		return err
	}
	defer os.Remove(importcfgPath)

	// Invoke the compiler.
	return runCompiler(packagePath, importcfgPath, filteredSrcPaths, outPath)
}

func runCompiler(packagePath, importcfgPath string, srcPaths []string, outPath string) error {
	platform := fmt.Sprintf("%s_%s", os.Getenv("GOHOSTOS"), os.Getenv("GOHOSTARCH"))
	compiler := filepath.Join(os.Getenv("GOROOT"), "pkg", "tool", platform, "compile")
	var args []string
	if packagePath != "" {
		args = append(args, "-p", packagePath)
	}
	args = append(args, "-importcfg", importcfgPath)
	args = append(args, "-o", outPath, "--")
	args = append(args, srcPaths...)
	cmd := exec.Command(compiler, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
