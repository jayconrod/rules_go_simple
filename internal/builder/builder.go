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
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "builder error: %v\n", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) <= 2 {
		return fmt.Errorf("usage: builder compile|link|test options...")
	}
	verb := args[0]
	args = args[1:]

	var action func(args []string) error
	switch verb {
	case "compile":
		action = compile
	case "link":
		action = link
	case "test":
		action = test
	default:
		return fmt.Errorf("unknown action: %s", verb)
	}
	return action(args)
}
