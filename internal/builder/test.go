// Copyright Jay Conrod. All rights reserved.

// This file is part of rules_go_simple. Use of this source code is governed by
// the 3-clause BSD license that can be found in the LICENSE.txt file.

package main

import (
	"errors"
	"flag"
	"fmt"
	"go/build"
	"io/ioutil"
	"os"
	"strings"
	"text/template"
)

// testMainInfo contains information needed to generate the main .go file
// for a test binary. It's consumed in a template used by generateTestMain.
type testMainInfo struct {
	Imports             []testArchiveInfo
	TestMainPackageName string
	RunDir              string
}

// testArchiveInfo contains information about a test archive. Tests may build
// two archives (in addition to the main archive): an internal archive which
// is compiled together with the library under test, and an external archive
// which is not. The external archive may reference exported symbols in
// the internal test archive.
type testArchiveInfo struct {
	ImportPath, PackageName string
	Tests                   []string

	srcs        []sourceInfo
	srcPaths    []string
	hasTestMain bool
}

// test produces a test executable from a list of .go sources. test filters
// sources into internal and external archives, which are compiled separately.
// test then generates a main .go file that starts the tests and compiles
// that into the main archive. Finally, test links the test executable.
func test(args []string) error {
	// Parse command line arguments.
	var stdImportcfgPath, packagePath, outPath, runDir string
	var directArchives, transitiveArchives []archive
	fs := flag.NewFlagSet("test", flag.ExitOnError)
	fs.StringVar(&stdImportcfgPath, "stdimportcfg", "", "path to importcfg for the standard library")
	fs.StringVar(&packagePath, "p", "default", "string used to import the test library")
	fs.Var(archiveFlag{&directArchives}, "direct", "information about direct dependencies")
	fs.Var(archiveFlag{&transitiveArchives}, "transitive", "information about transitive dependencies")
	fs.StringVar(&outPath, "o", "", "path to binary file to generate")
	fs.StringVar(&runDir, "dir", ".", "directory the test binary should change to before running")
	fs.Parse(args)
	srcPaths := fs.Args()

	// Filter sources into two archives: an internal package that gets compiled
	// together with the library under test, and an external package that
	// gets compiled separately.
	testInfo := testArchiveInfo{
		ImportPath:  packagePath,
		PackageName: "test",
	}
	xtestInfo := testArchiveInfo{
		ImportPath:  packagePath + "_test",
		PackageName: "xtest",
	}
	packageName := ""
	bctx := &build.Default
	for _, srcPath := range srcPaths {
		src, err := loadSourceInfo(bctx, srcPath)
		if err != nil {
			return err
		}
		if !src.match {
			continue
		}

		info := &testInfo
		srcPackageName := src.packageName
		if strings.HasSuffix(src.packageName, "_test") {
			info = &xtestInfo
			srcPackageName = src.packageName[:len(src.packageName)-len("_test")]
		}
		if packageName == "" {
			packageName = srcPackageName
		} else if packageName != srcPackageName {
			return fmt.Errorf("%s: package name %q does not match package name %q in file %s", src.fileName, src.packageName, info.PackageName, srcPaths[0])
		}
		info.Tests = append(info.Tests, src.tests...)
		info.srcs = append(info.srcs, src)
		info.srcPaths = append(info.srcPaths, srcPath)
		info.hasTestMain = info.hasTestMain || src.hasTestMain
	}

	// Build a map from package paths to archive files using the standard
	// importcfg and -direct command line arguments.
	archiveMap, err := readImportcfg(stdImportcfgPath)
	if err != nil {
		return err
	}
	for _, arc := range directArchives {
		archiveMap[arc.packagePath] = arc.filePath
	}

	// Compile each archive.
	mainInfo := testMainInfo{RunDir: runDir}
	var testArchivePath string
	if len(testInfo.srcs) > 0 {
		mainInfo.Imports = append(mainInfo.Imports, testInfo)
		if testInfo.hasTestMain {
			mainInfo.TestMainPackageName = testInfo.PackageName
		}

		testArchivePath, err = compileTestArchive(testInfo.ImportPath, testInfo.srcPaths, testInfo.srcs, archiveMap)
		if err != nil {
			return err
		}
		defer os.Remove(testArchivePath)
		archiveMap[packagePath] = testArchivePath
	}

	var xtestArchivePath string
	if len(xtestInfo.srcs) > 0 {
		mainInfo.Imports = append(mainInfo.Imports, xtestInfo)
		if xtestInfo.hasTestMain {
			if testInfo.hasTestMain {
				return errors.New("TestMain defined in both internal and external test files")
			}
			mainInfo.TestMainPackageName = xtestInfo.PackageName
		}

		xtestArchivePath, err = compileTestArchive(xtestInfo.ImportPath, xtestInfo.srcPaths, xtestInfo.srcs, archiveMap)
		if err != nil {
			return err
		}
		defer os.Remove(xtestArchivePath)
		archiveMap[packagePath+"_test"] = xtestArchivePath
	}

	// Generate a source file and compile the main package, which imports
	// the test libraries and starts the test.
	testmainSrcPath, err := generateTestMain(mainInfo)
	if err != nil {
		return err
	}
	defer os.Remove(testmainSrcPath)

	for _, arc := range transitiveArchives {
		archiveMap[arc.packagePath] = arc.filePath
	}
	importcfgPath, err := writeTempImportcfg(archiveMap)
	if err != nil {
		return err
	}
	defer os.Remove(importcfgPath)

	testMainArchiveFile, err := ioutil.TempFile("", "*-testmain.a")
	if err != nil {
		return err
	}
	testMainArchivePath := testMainArchiveFile.Name()
	defer os.Remove(testMainArchivePath)
	if err := testMainArchiveFile.Close(); err != nil {
		return err
	}
	if err := runCompiler("main", importcfgPath, []string{testmainSrcPath}, testMainArchivePath); err != nil {
		return err
	}

	// Link everything together.
	return runLinker(testMainArchivePath, importcfgPath, outPath)
}

func compileTestArchive(packagePath string, srcPaths []string, srcs []sourceInfo, archiveMap map[string]string) (string, error) {
	importcfgPath, err := writeTempImportcfg(archiveMap)
	if err != nil {
		return "", err
	}

	tmpArchiveFile, err := ioutil.TempFile("", "*-test.a")
	if err != nil {
		return "", err
	}
	tmpArchivePath := tmpArchiveFile.Name()
	if err := tmpArchiveFile.Close(); err != nil {
		os.Remove(tmpArchivePath)
		return "", err
	}

	if err := runCompiler(packagePath, importcfgPath, srcPaths, tmpArchivePath); err != nil {
		os.Remove(tmpArchivePath)
		return "", err
	}

	return tmpArchivePath, nil
}

var testmainTpl = template.Must(template.New("testmain").Parse(`
// Code generated by @rules_go_simple//internal/builder:test.go. DO NOT EDIT.

package main

import (
	"log"
	"os"
	"testing"
	"testing/internal/testdeps"

{{range .Imports}}
	{{.PackageName}} "{{.ImportPath}}"
{{end}}
)

var allTests = []testing.InternalTest{
{{range $p := .Imports}}
{{range $t := $p.Tests}}
	{"{{$t}}", {{$p.PackageName}}.{{$t}}},
{{end}}
{{end}}
}

func main() {
	if err := os.Chdir("{{.RunDir}}"); err != nil {
		log.Fatalf("could not change to test directory: %v", err)
	}

	m := testing.MainStart(testdeps.TestDeps{}, allTests, nil, nil)
{{if .TestMainPackageName}}
	{{.TestMainPackageName}}.TestMain(m)
{{else}}
	os.Exit(m.Run())
{{end}}
}
`))

func generateTestMain(mainInfo testMainInfo) (testmainPath string, err error) {
	testmainFile, err := ioutil.TempFile("", "*-testmain.go")
	if err != nil {
		return "", err
	}
	tmpPath := testmainFile.Name() // testmainPath only set on success
	defer func() {
		if cerr := testmainFile.Close(); cerr != nil && err == nil {
			err = cerr
		}
		if err != nil {
			os.Remove(tmpPath)
		}
	}()

	if err := testmainTpl.Execute(testmainFile, mainInfo); err != nil {
		return "", err
	}
	return tmpPath, nil
}
