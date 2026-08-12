package main

import (
	"bufio"
	"context"
	"net"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestMinecraftRCONIntegration(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	var commandsMu sync.Mutex
	var commands []string
	go func() {
		for {
			connection, err := listener.Accept()
			if err != nil {
				return
			}
			go func() {
				defer connection.Close()
				reader := bufio.NewReader(connection)
				authID, _, password, err := readRCONPacket(reader)
				if err != nil {
					return
				}
				if password != "test-password" {
					_ = writeRCONPacket(connection, -1, rconCommand, "")
					return
				}
				_ = writeRCONPacket(connection, authID, rconCommand, "")
				commandID, _, command, err := readRCONPacket(reader)
				if err != nil {
					return
				}
				commandsMu.Lock()
				commands = append(commands, command)
				commandsMu.Unlock()
				response := "Added icuL_ to the whitelist"
				if command == "op MissingPlayer" {
					response = "That player does not exist"
				}
				_ = writeRCONPacket(connection, commandID, rconResponseValue, response)
			}()
		}
	}()

	passwordPath := filepath.Join(t.TempDir(), "rcon-password")
	if err := os.WriteFile(passwordPath, []byte("test-password\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	client := &minecraftRCON{address: listener.Addr().String(), passwordFile: passwordPath, timeout: time.Second}
	response, err := client.execute(context.Background(), "whitelist add icuL_")
	if err != nil || response != "Added icuL_ to the whitelist" {
		t.Fatalf("success response = %q, %v", response, err)
	}
	failure, err := client.execute(context.Background(), "op MissingPlayer")
	if err != nil || !rconResponseFailed(failure) {
		t.Fatalf("failure response = %q, %v", failure, err)
	}
	commandsMu.Lock()
	defer commandsMu.Unlock()
	if len(commands) != 2 || commands[0] != "whitelist add icuL_" || commands[1] != "op MissingPlayer" {
		t.Fatalf("commands = %#v", commands)
	}
}
