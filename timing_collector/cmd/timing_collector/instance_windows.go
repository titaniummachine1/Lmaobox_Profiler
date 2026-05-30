//go:build windows

package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const collectorExeName = "timing_collector.exe"

// stopPriorCollectorInstances ends other timing_collector.exe processes so only one collector serves :9876.
func stopPriorCollectorInstances() {
	self := os.Getpid()
	stopped := false
	for _, pid := range collectorPIDs() {
		if pid == self {
			continue
		}
		fmt.Printf("timing_collector: stopping prior instance (PID %d)\n", pid)
		_ = exec.Command("taskkill", "/F", "/PID", strconv.Itoa(pid)).Run()
		stopped = true
	}
	if stopped {
		time.Sleep(400 * time.Millisecond)
	}
}

func collectorPIDs() []int {
	out, err := exec.Command("tasklist", "/FI", "IMAGENAME eq "+collectorExeName, "/FO", "CSV", "/NH").Output()
	if err != nil {
		return nil
	}
	var pids []int
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		pid := pidFromTasklistCSVLine(line)
		if pid > 0 {
			pids = append(pids, pid)
		}
	}
	return pids
}

func pidFromTasklistCSVLine(line string) int {
	// "timing_collector.exe","12345","Console","1","12,345 K"
	first := strings.Index(line, ",")
	if first < 0 {
		return 0
	}
	rest := strings.TrimSpace(line[first+1:])
	if len(rest) < 2 || rest[0] != '"' {
		return 0
	}
	rest = rest[1:]
	end := strings.Index(rest, `"`)
	if end < 0 {
		return 0
	}
	pid, err := strconv.Atoi(rest[:end])
	if err != nil {
		return 0
	}
	return pid
}

func parseListenPort(addr string) string {
	if i := strings.LastIndex(addr, ":"); i >= 0 {
		return addr[i+1:]
	}
	return addr
}

// freeListenAddr clears the listen port if a stray timing_collector instance still holds it.
func freeListenAddr(addr string) {
	port := parseListenPort(addr)
	out, err := exec.Command("netstat", "-ano").Output()
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(out), "\n") {
		if !strings.Contains(line, "LISTENING") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 5 || listenPortFromNetstat(fields) != port {
			continue
		}
		pid, err := strconv.Atoi(fields[len(fields)-1])
		if err != nil || pid == os.Getpid() || !isCollectorPID(pid) {
			continue
		}
		fmt.Printf("timing_collector: freeing port %s (PID %d)\n", port, pid)
		_ = exec.Command("taskkill", "/F", "/PID", strconv.Itoa(pid)).Run()
	}
	time.Sleep(200 * time.Millisecond)
}

func listenPortFromNetstat(fields []string) string {
	local := fields[1]
	if i := strings.LastIndex(local, ":"); i >= 0 {
		return local[i+1:]
	}
	return ""
}

func isCollectorPID(pid int) bool {
	out, err := exec.Command("tasklist", "/FI", fmt.Sprintf("PID eq %d", pid), "/FO", "CSV", "/NH").Output()
	if err != nil {
		return false
	}
	line := strings.TrimSpace(string(out))
	return strings.HasPrefix(strings.ToLower(line), strings.ToLower(collectorExeName))
}
