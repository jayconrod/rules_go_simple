// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"flag"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

var want = []string{
	"bar.txt",
	"foo.txt",
}

func TestDataFromBinary(t *testing.T) {
	binPath := strings.TrimPrefix(flag.Args()[0], "v5/tests/")
	out, err := exec.Command(binPath).Output()
	if err != nil {
		t.Fatal(err)
	}

	got := make(map[string]bool)
	for _, path := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		got[path] = true
	}
	for _, w := range want {
		if !got[w] {
			t.Errorf("wanted %q but it was not visible", w)
		}
	}
}

func TestDataFromTest(t *testing.T) {
	data := listData(t)
	got := make(map[string]bool)
	for _, path := range data {
		got[path] = true
	}
	for _, w := range want {
		if !got[w] {
			t.Errorf("wanted %q but it was not visible", w)
		}
	}
}

func listData(t *testing.T) []string {
	var files []string
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		t.Error(err)
	}
	return files
}
