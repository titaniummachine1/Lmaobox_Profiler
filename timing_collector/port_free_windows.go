//go:build windows

package main

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func freeListenAddr(addr string) {
	port := addr
	if i := strings.LastIndex(addr, ":"); i >= 0 {
		port = addr[i+1:]
	}

	out, err := exec.Command("netstat", "-ano").Output()
	if err != nil {
		return
	}

	needle := ":" + port
	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, needle) || !strings.Contains(line, "LISTENING") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		pid := fields[len(fields)-1]
		fmt.Printf("timing_collector: freeing port %s (PID %s)\n", port, pid)
		_ = exec.Command("taskkill", "/F", "/PID", pid).Run()
	}
	time.Sleep(400 * time.Millisecond)
}
