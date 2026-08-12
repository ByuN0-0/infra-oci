package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
)

type playerEntry struct {
	Name  string `json:"name"`
	Level int    `json:"level,omitempty"`
}

func readPlayerFile(path string) ([]playerEntry, error) {
	contents, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var players []playerEntry
	if err := json.Unmarshal(contents, &players); err != nil {
		return nil, fmt.Errorf("decode %s: %w", path, err)
	}
	sort.Slice(players, func(left, right int) bool {
		return players[left].Name < players[right].Name
	})
	return players, nil
}
