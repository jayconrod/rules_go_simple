// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package ix

import "testing"

var TestFooCalled = false

func TestFoo(t *testing.T) {
	if got := Foo(); got != "foo" {
		t.Errorf("got %q; want \"foo\"", got)
	}
	TestFooCalled = true
}

func Helper(f func() string) string {
	s := f()
	return s + s
}
