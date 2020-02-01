// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

// builder is a tool used to perform various tasks related to building Go code,
// such as compiling packages, linking executables, and generating
// test sources.
package main

import (
	"log"
	"os"
)

func main() {
	log.SetFlags(0)
	log.SetPrefix("builder: ")
	if len(os.Args) <= 2 {
		log.Fatalf("usage: %s stdimportcfg|compile|link|test options...", os.Args[0])
	}
	verb := os.Args[1]
	args := os.Args[2:]

	var action func(args []string) error
	switch verb {
	case "stdimportcfg":
		action = stdImportcfg
	case "compile":
		action = compile
	case "link":
		action = link
	case "test":
		action = test
	default:
		log.Fatalf("unknown action: %s", verb)
	}
	log.SetPrefix(verb + ": ")

	err := action(args)
	if err != nil {
		log.Fatal(err)
	}
}
