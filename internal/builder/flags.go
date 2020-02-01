// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"fmt"
	"strings"
)

// splitArgs splits an argument list into two lists: builder arguments (for this
// program) and tool arguments (for an underlying tool like the compiler). The
// "--" argument is used as a separator. If this argument is not found, all
// arguments are builder arguments.
func splitArgs(args []string) (builderArgs, toolArgs []string) {
	builderArgs = args
	for i, arg := range args {
		if arg == "--" {
			builderArgs = args[:i]
			toolArgs = args[i+1:]
		}
	}
	return builderArgs, toolArgs
}

// archive is a mapping from a package path (e.g., "fmt") to a file system
// path to the package's archive (e.g., "/opt/go/pkg/linux_amd64/fmt.a").
type archive struct {
	packagePath, filePath string
}

// archiveFlag parses archives from command line arguments. Archive values
// have the form "packagePath=filePath".
type archiveFlag struct {
	archives *[]archive
}

func (f archiveFlag) String() string {
	if f.archives == nil {
		return ""
	}
	b := &strings.Builder{}
	sep := ""
	for _, arc := range *f.archives {
		fmt.Fprintf(b, "%s%s=%s", sep, arc.packagePath, arc.filePath)
		sep = " "
	}
	return b.String()
}

func (f archiveFlag) Set(value string) error {
	pos := strings.IndexByte(value, '=')
	if pos < 0 {
		return fmt.Errorf("malformed -arc flag: %q", value)
	}
	arc := archive{
		packagePath: value[:pos],
		filePath:    value[pos+1:],
	}
	*f.archives = append(*f.archives, arc)
	return nil
}
