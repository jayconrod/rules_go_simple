// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
)

// link produces an executable file from a main archive file and a list of
// dependencies (both direct and transitive).
func link(args []string) error {
	// Process command line arguments.
	var stdlibPath, mainPath, outPath string
	var archives []archive
	fs := flag.NewFlagSet("link", flag.ExitOnError)
	fs.StringVar(&stdlibPath, "stdlib", "", "path to a directory containing compiled standard library packages")
	fs.Var(archiveFlag{&archives}, "arc", "information about dependencies (including transitive dependencies), formatted as packagepath=file (may be repeated)")
	fs.StringVar(&mainPath, "main", "", "path to main package archive file")
	fs.StringVar(&outPath, "o", "", "path to binary file the linker should produce")
	fs.Parse(args)
	if len(fs.Args()) != 0 {
		return fmt.Errorf("expected 0 positional arguments; got %d", len(fs.Args()))
	}

	// Build an importcfg file that maps package paths to compiled archive files.
	// This includes the main package, all transitively imported packages listed
	// with -arc, and all standard library packages. We don't technically need to
	// list unimported standard library packages, but within this action, there's
	// no way to know which packages are actually imported.
	archiveMap, err := listStdlibPaths(stdlibPath)
	if err != nil {
		return err
	}
	for _, arc := range archives {
		archiveMap[arc.packagePath] = arc.filePath
	}
	importcfgPath, err := writeTempImportcfg(archiveMap)
	if err != nil {
		return err
	}
	defer os.Remove(importcfgPath)

	// Invoke the linker.
	return runLinker(mainPath, importcfgPath, outPath)
}

func runLinker(mainPath, importcfgPath string, outPath string) error {
	args := []string{"tool", "link", "-importcfg", importcfgPath, "-o", outPath}
	args = append(args, "--", mainPath)
	goTool, err := findGoTool()
	if err != nil {
		return err
	}
	cmd := exec.Command(goTool, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
