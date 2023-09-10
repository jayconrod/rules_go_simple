// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"bytes"
	"fmt"
	"os"
	"sort"
	"strings"
)

// readImportcfg parses an importcfg file. It returns a map from package paths
// to archive file paths.
func readImportcfg(importcfgPath string) (map[string]string, error) {
	archiveMap := make(map[string]string)

	data, err := os.ReadFile(importcfgPath)
	if err != nil {
		return nil, err
	}

	// based on parsing code in cmd/link/internal/ld/ld.go
	for lineNum, line := range strings.Split(string(data), "\n") {
		lineNum++ // 1-based
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		var verb, args string
		if i := strings.Index(line, " "); i < 0 {
			verb = line
		} else {
			verb, args = line[:i], strings.TrimSpace(line[i+1:])
		}
		var before, after string
		if i := strings.Index(args, "="); i >= 0 {
			before, after = args[:i], args[i+1:]
		}
		if verb == "packagefile" {
			archiveMap[before] = after
		}
	}

	return archiveMap, nil
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
