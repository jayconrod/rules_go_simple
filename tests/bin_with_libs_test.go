// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"bytes"
	"flag"
	"os/exec"
	"strings"
	"testing"
)

func TestBinWithLibs(t *testing.T) {
	binPath := "./" + strings.TrimPrefix(flag.Args()[0], "tests/")
	got, err := exec.Command(binPath).Output()
	if err != nil {
		t.Fatal(err)
	}
	got = bytes.TrimSpace(got)
	want := []byte("foo\nbar\nbaz\nbaz")
	if !bytes.Equal(got, want) {
		t.Errorf("got:\n%s\n\nwant:\n%s\n", got, want)
	}
}
