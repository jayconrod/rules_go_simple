// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package ix_test

import (
	"flag"
	"log"
	"os"
	"rules_go_simple/tests/ix"
	"testing"
)

var TestFooHelperCalled = false

func TestFooHelper(t *testing.T) {
	if got := ix.Helper(ix.Foo); got != "foofoo" {
		t.Errorf("got %q; want \"foofoo\"", got)
	}
	TestFooHelperCalled = true
}

func TestMain(m *testing.M) {
	flag.Parse()
	code := m.Run()
	if !ix.TestFooCalled {
		log.Fatal("TestFooCalled is false")
	}
	if !TestFooHelperCalled {
		log.Fatal("TestFooHelperCalled is false")
	}
	os.Exit(code)
}
