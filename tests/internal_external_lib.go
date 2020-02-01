// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package ix

import "testing"

func Foo() string { return "foo" }

func TestLib(t *testing.T) {
	t.Error("TestLib should not be called")
}
