package main

import (
	"os"
	"path/filepath"
	"testing"

	"gopkg.in/yaml.v3"
)

func FuzzLoadConfig(f *testing.F) {
	seeds := []string{
		"version: 1\nshell: {}\n",
		"version: 1\nshell:\n  aliases: false\n",
		"version: 1\nshell:\n  aliases:\n    path: ~/aliases.zsh\n",
		"version: 1\nshell:\n  aliases:\n    extend:\n      path: ~/aliases.zsh\n",
		"version: 1\nshell:\n  prompt:\n    engine: starship\n",
	}
	for _, seed := range seeds {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, input string) {
		dir := t.TempDir()
		path := filepath.Join(dir, "shell.yaml")
		if err := os.WriteFile(path, []byte(input), 0o600); err != nil {
			t.Fatal(err)
		}
		_, _ = loadConfig(path)
	})
}

func FuzzParseSegment(f *testing.F) {
	seeds := []string{
		"{}",
		"false",
		"{path: ~/custom.zsh}",
		"{extend: {path: ~/custom.zsh}}",
		"{engine: starship}",
	}
	for _, seed := range seeds {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, input string) {
		var node yaml.Node
		if err := yaml.Unmarshal([]byte(input), &node); err != nil || len(node.Content) == 0 {
			return
		}
		_, _ = parseSegment("aliases", *node.Content[0], t.TempDir())
		_, _ = parseSegment("prompt", *node.Content[0], t.TempDir())
	})
}
