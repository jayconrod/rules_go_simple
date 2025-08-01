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
)

// compile produces a Go archive file (.a) from a list of .go sources.  This
// function will filter sources using build constraints (OS and architecture
// file name suffixes and +build comments) and will build an importcfg file
// before invoking the Go compiler.
func compile(args []string) error {
	// Process command line arguments.
	var stdlibPath, packagePath, outPath string
	var archives []archive
	fs := flag.NewFlagSet("compile", flag.ExitOnError)
	fs.StringVar(&stdlibPath, "stdlib", "", "path to a directory containing compiled standard library packages")
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
	var errs []error
	for _, srcPath := range srcPaths {
		src, err := loadSourceInfo(bctx, srcPath)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if src.match {
			srcs = append(srcs, src)
			filteredSrcPaths = append(filteredSrcPaths, srcPath)
		}
	}

	// Build an importcfg file that maps this package's imports to archive files
	// from the standard library or direct dependencies.
	directArchiveMap := make(map[string]string)
	for _, arc := range archives {
		directArchiveMap[arc.packagePath] = arc.filePath
	}

	archiveMap := make(map[string]string)
	for _, src := range srcs {
		for _, imp := range src.imports {
			if _, ok := archiveMap[imp]; ok {
				// Already added.
				continue
			}
			if imp == "unsafe" {
				// Dummy package with no compiled archive.
				continue
			}
			if imp == "C" {
				errs = append(errs, fmt.Errorf("%s: cgo not supported", src.fileName))
			}
			if path, ok := directArchiveMap[imp]; ok {
				archiveMap[imp] = path
				continue
			}
			if stdPath, ok := isStdPackage(stdlibPath, imp); ok {
				archiveMap[imp] = stdPath
				continue
			}
			errs = append(errs, fmt.Errorf("%s: import %q is not provided by any direct dependency", src.fileName, imp))
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
	args := []string{"tool", "compile"}
	if packagePath != "" {
		args = append(args, "-p", packagePath)
	}
	args = append(args, "-importcfg", importcfgPath)
	args = append(args, "-o", outPath, "--")
	args = append(args, srcPaths...)
	goTool, err := findGoTool()
	if err != nil {
		return err
	}
	cmd := exec.Command(goTool, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
