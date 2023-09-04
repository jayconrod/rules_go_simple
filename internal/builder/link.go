// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// link produces an executable file from a main archive file and a list of
// dependencies (both direct and transitive).
func link(args []string) error {
	// Process command line arguments.
	var stdImportcfgPath, mainPath, outPath string
	var archives []archive
	fs := flag.NewFlagSet("link", flag.ExitOnError)
	fs.StringVar(&stdImportcfgPath, "stdimportcfg", "", "path to importcfg for the standard library")
	fs.Var(archiveFlag{&archives}, "arc", "information about dependencies (including transitive dependencies), formatted as packagepath=file (may be repeated)")
	fs.StringVar(&mainPath, "main", "", "path to main package archive file")
	fs.StringVar(&outPath, "o", "", "path to binary file the linker should produce")
	fs.Parse(args)
	if len(fs.Args()) != 0 {
		return fmt.Errorf("expected 0 positional arguments; got %d", len(fs.Args()))
	}

	// Build an importcfg file.
	archiveMap, err := readImportcfg(stdImportcfgPath)
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
	platform := fmt.Sprintf("%s_%s", os.Getenv("GOHOSTOS"), os.Getenv("GOHOSTARCH"))
	linker := filepath.Join(os.Getenv("GOROOT"), "pkg", "tool", platform, "link")
	args := []string{"-importcfg", importcfgPath, "-o", outPath}
	args = append(args, "--", mainPath)
	cmd := exec.Command(linker, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
