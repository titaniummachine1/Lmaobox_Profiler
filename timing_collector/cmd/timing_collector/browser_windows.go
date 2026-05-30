//go:build windows

package main

import (
	"os/exec"
)

func tryOpenBrowser(url string) {
	_ = exec.Command("cmd", "/c", "start", "", url).Start()
}
