// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// findGoTool finds and returns an absolute path to the Go command, based
// on the GOROOT environment variable.
func findGoTool() (string, error) {
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", fmt.Errorf("GOROOT not set")
	}
	absGoroot, err := filepath.Abs(goroot)
	if err != nil {
		return "", err
	}
	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}
	return filepath.Join(absGoroot, "bin", "go"+ext), nil
}
