package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"time"
)

const (
	rconResponseValue = 0
	rconCommand       = 2
	rconAuth          = 3
	maxRCONPacket     = 1 << 20
)

type rconClient interface {
	execute(context.Context, string) (string, error)
}

type minecraftRCON struct {
	address      string
	passwordFile string
	timeout      time.Duration
}

func (client *minecraftRCON) execute(ctx context.Context, command string) (string, error) {
	password, err := os.ReadFile(client.passwordFile)
	if err != nil {
		return "", fmt.Errorf("read RCON password: %w", err)
	}
	dialer := net.Dialer{Timeout: client.timeout}
	connection, err := dialer.DialContext(ctx, "tcp", client.address)
	if err != nil {
		return "", fmt.Errorf("connect to RCON: %w", err)
	}
	defer connection.Close()
	deadline := time.Now().Add(client.timeout)
	_ = connection.SetDeadline(deadline)
	reader := bufio.NewReader(connection)

	if err := writeRCONPacket(connection, 1, rconAuth, strings.TrimSpace(string(password))); err != nil {
		return "", err
	}
	authID, _, _, err := readRCONPacket(reader)
	if err != nil {
		return "", err
	}
	if authID == -1 {
		return "", errors.New("RCON authentication failed")
	}

	if err := writeRCONPacket(connection, 2, rconCommand, command); err != nil {
		return "", err
	}
	responseID, _, body, err := readRCONPacket(reader)
	if err != nil {
		return "", err
	}
	if responseID != 2 {
		return "", errors.New("unexpected RCON response ID")
	}
	return body, nil
}

func writeRCONPacket(writer io.Writer, requestID, packetType int32, body string) error {
	payloadLength := 4 + 4 + len(body) + 2
	if payloadLength > maxRCONPacket {
		return errors.New("RCON packet is too large")
	}
	packet := make([]byte, 4+payloadLength)
	binary.LittleEndian.PutUint32(packet[0:4], uint32(payloadLength))
	binary.LittleEndian.PutUint32(packet[4:8], uint32(requestID))
	binary.LittleEndian.PutUint32(packet[8:12], uint32(packetType))
	copy(packet[12:], body)
	_, err := writer.Write(packet)
	return err
}

func readRCONPacket(reader io.Reader) (int32, int32, string, error) {
	var length int32
	if err := binary.Read(reader, binary.LittleEndian, &length); err != nil {
		return 0, 0, "", fmt.Errorf("read RCON packet length: %w", err)
	}
	if length < 10 || length > maxRCONPacket {
		return 0, 0, "", errors.New("invalid RCON packet length")
	}
	payload := make([]byte, length)
	if _, err := io.ReadFull(reader, payload); err != nil {
		return 0, 0, "", fmt.Errorf("read RCON packet: %w", err)
	}
	requestID := int32(binary.LittleEndian.Uint32(payload[0:4]))
	packetType := int32(binary.LittleEndian.Uint32(payload[4:8]))
	body := strings.TrimRight(string(payload[8:]), "\x00")
	return requestID, packetType, body, nil
}

func commandFor(action, username string) (string, error) {
	if !validUsername(username) {
		return "", errors.New("invalid Minecraft username")
	}
	switch action {
	case "whitelist.add":
		return "whitelist add " + username, nil
	case "whitelist.remove":
		return "whitelist remove " + username, nil
	case "ops.add":
		return "op " + username, nil
	case "ops.remove":
		return "deop " + username, nil
	default:
		return "", errors.New("unsupported action")
	}
}
