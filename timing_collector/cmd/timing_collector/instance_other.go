//go:build !windows

package main

func stopPriorCollectorInstances() {}

func freeListenAddr(_ string) {}
