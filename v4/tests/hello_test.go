// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package hello_test

import (
	"bytes"
	"flag"
	"os/exec"
	"strings"
	"testing"
)

var helloPath = flag.String("hello", "", "path to hello binary")

func TestHello(t *testing.T) {
	cmd := exec.Command(strings.TrimPrefix(*helloPath, "v4/tests/"))
	out, err := cmd.Output()
	if err != nil {
		t.Fatal(err)
	}
	got := string(bytes.TrimSpace(out))
	if want := "Hello, world!"; got != want {
		t.Errorf("got %q; want %q", got, want)
	}
}
