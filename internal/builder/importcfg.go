// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"bytes"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// isStdPackage returns the path to a compile package file in the standard
// library and a bool indicating whether it exists.
func isStdPackage(stdlibPath, imp string) (pkgFile string, exists bool) {
	pkgFile = filepath.Join(stdlibPath, imp+".a")
	_, err := os.Stat(pkgFile)
	return pkgFile, err == nil
}

// listStdlibPaths returns a map from standard library import strings to
// compiled package file paths. This map may be used to write an importcfg file.
func listStdlibPaths(stdlibPath string) (_ map[string]string, err error) {
	defer func() {
		if err != nil {
			err = fmt.Errorf("listing std paths: %w", err)
		}
	}()
	stdlibPath, err = filepath.Abs(stdlibPath)
	if err != nil {
		return nil, err
	}
	entries := make(map[string]string)
	err = filepath.WalkDir(stdlibPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !strings.HasSuffix(path, ".a") || d.IsDir() {
			return nil
		}
		imp := strings.TrimPrefix(path, stdlibPath+string(os.PathSeparator))
		imp = strings.TrimSuffix(imp, ".a")
		entries[imp] = path
		return nil
	})
	if err != nil {
		return nil, err
	}
	return entries, nil
}

// writeTempImportcfg writes a temporary importcfg file. The caller is
// responsible for deleting it.
func writeTempImportcfg(archiveMap map[string]string) (string, error) {
	tmpFile, err := os.CreateTemp("", "importcfg-*")
	if err != nil {
		return "", err
	}
	tmpPath := tmpFile.Name()
	if err := tmpFile.Close(); err != nil {
		os.Remove(tmpPath)
		return "", err
	}
	if err := writeImportcfg(archiveMap, tmpPath); err != nil {
		os.Remove(tmpPath)
		return "", err
	}
	return tmpPath, nil
}

func writeImportcfg(archiveMap map[string]string, outPath string) error {
	pkgPaths := make([]string, 0, len(archiveMap))
	for pkgPath := range archiveMap {
		pkgPaths = append(pkgPaths, pkgPath)
	}
	sort.Strings(pkgPaths)

	buf := &bytes.Buffer{}
	for _, pkgPath := range pkgPaths {
		fmt.Fprintf(buf, "packagefile %s=%s\n", pkgPath, archiveMap[pkgPath])
	}

	return os.WriteFile(outPath, buf.Bytes(), 0666)
}
