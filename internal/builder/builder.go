// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

// builder is a tool used to perform various tasks related to building Go code,
// such as compiling packages, linking executables, and generating
// test sources.
package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) <= 2 {
		fmt.Fprintf(os.Stderr, "usage: %s stdimportcfg|compile|link|test options...\n", os.Args[0])
		os.Exit(1)
	}
	verb := os.Args[1]
	args := os.Args[2:]

	var action func(args []string) error
	switch verb {
	case "compile":
		action = compile
	case "link":
		action = link
	case "test":
		action = test
	default:
		fmt.Fprintf(os.Stderr, "unknown action: %s\n", verb)
		os.Exit(1)
	}

	err := action(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: error: %v\n", verb, err)
		os.Exit(1)
	}
}
