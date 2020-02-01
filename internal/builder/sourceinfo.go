// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"path/filepath"
	"strconv"
	"strings"
)

type sourceInfo struct {
	fileName    string
	match       bool
	packageName string
	imports     []string
	tests       []string
	hasTestMain bool
}

// loadSourceInfo extracts metadata from a source file.
func loadSourceInfo(bctx *build.Context, fileName string) (sourceInfo, error) {
	if match, err := bctx.MatchFile(filepath.Dir(fileName), filepath.Base(fileName)); err != nil {
		return sourceInfo{}, err
	} else if !match {
		return sourceInfo{fileName: fileName}, nil
	}

	fset := token.NewFileSet()
	flags := parser.ImportsOnly
	if strings.HasSuffix(fileName, "_test.go") {
		flags = 0
	}
	tree, err := parser.ParseFile(fset, fileName, nil, flags)
	if err != nil {
		return sourceInfo{}, err
	}

	si := sourceInfo{
		fileName:    fileName,
		match:       true,
		packageName: tree.Name.Name,
	}
	for _, decl := range tree.Decls {
		switch decl := decl.(type) {
		case *ast.GenDecl:
			if decl.Tok != token.IMPORT {
				break
			}

			for _, spec := range decl.Specs {
				importSpec := spec.(*ast.ImportSpec)
				importPath, err := strconv.Unquote(importSpec.Path.Value)
				if err != nil {
					panic(err)
				}
				si.imports = append(si.imports, importPath)
			}

		case *ast.FuncDecl:
			if decl.Recv != nil ||
				!strings.HasPrefix(decl.Name.Name, "Test") {
				break
			}
			if decl.Name.Name == "TestMain" {
				si.hasTestMain = true
				break
			}

			if len(decl.Type.Params.List) != 1 ||
				decl.Type.Results != nil {
				break
			}
			starExpr, ok := decl.Type.Params.List[0].Type.(*ast.StarExpr)
			if !ok {
				break
			}
			selExpr, ok := starExpr.X.(*ast.SelectorExpr)
			if !ok || selExpr.Sel.Name != "T" {
				break
			}
			si.tests = append(si.tests, decl.Name.Name)
		}
	}
	return si, nil
}
