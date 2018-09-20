package main

import (
	"fmt"
	"os"
	"rules_go_simple/v3/tests/list_data_lib"
)

func main() {
	files, err := list_data_lib.ListData()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, f := range files {
		fmt.Println(f)
	}
}
