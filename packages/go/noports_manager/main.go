package main

import (
	"fmt"
	"noports_manager/app"
	"os"
)

func main() {
	my_app := app.App()
	if _, err := my_app.Run(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	os.Exit(0)
}
