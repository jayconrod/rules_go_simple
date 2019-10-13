// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package foo

import (
	"fmt"
	"rules_go_simple/v5/tests/bar"
	"rules_go_simple/v5/tests/baz"
)

func Foo() {
	fmt.Println("foo")
	bar.Bar()
	baz.Baz()
}
