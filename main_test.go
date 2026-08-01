package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

func nodeFromYAML(t *testing.T, input string) yaml.Node {
	t.Helper()
	var value map[string]yaml.Node
	if err := yaml.Unmarshal([]byte(input), &value); err != nil {
		t.Fatal(err)
	}
	return value["segment"]
}

func TestParseSegmentModes(t *testing.T) {
	home := t.TempDir()
	custom := filepath.Join(home, "aliases.zsh")
	cases := []struct {
		name  string
		yaml  string
		mode  segmentMode
		path  string
	}{
		{"default", "segment: {}", modeDefault, ""},
		{"disabled", "segment: false", modeDisabled, ""},
		{"replace", "segment:\n  path: ~/aliases.zsh", modeReplace, custom},
		{"extend", "segment:\n  extend:\n    path: ~/aliases.zsh", modeExtend, custom},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			spec, err := parseSegment("aliases", nodeFromYAML(t, tc.yaml), home)
			if err != nil {
				t.Fatal(err)
			}
			if spec.Mode != tc.mode || spec.Custom != tc.path {
				t.Fatalf("got mode=%v path=%q", spec.Mode, spec.Custom)
			}
		})
	}
}

func TestParseSegmentRejectsAmbiguousAndUnsafeInput(t *testing.T) {
	home := t.TempDir()
	cases := []string{
		"segment:\n  path: ~/a.zsh\n  extend:\n    path: ~/b.zsh",
		"segment:\n  path: $(command)",
		"segment:\n  path: relative.zsh",
		"segment:\n  unknown: true",
	}
	for _, input := range cases {
		if _, err := parseSegment("aliases", nodeFromYAML(t, input), home); err == nil {
			t.Fatalf("expected error for:\n%s", input)
		}
	}
}

func TestPromptContract(t *testing.T) {
	home := t.TempDir()
	if _, err := parseSegment("prompt", nodeFromYAML(t, "segment:\n  engine: unknown"), home); err == nil {
		t.Fatal("unknown prompt engine accepted")
	}
	if _, err := parseSegment("prompt", nodeFromYAML(t, "segment:\n  extend:\n    path: ~/theme.toml"), home); err == nil {
		t.Fatal("prompt extend accepted")
	}
}

func TestRenderExtendAndDisable(t *testing.T) {
	home := t.TempDir()
	custom := filepath.Join(home, "aliases.zsh")
	if err := os.WriteFile(custom, []byte("alias custom='ok'\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	var cfg config
	input := "version: 1\nshell:\n  aliases:\n    extend:\n      path: " + custom + "\n  remote: false\n  prompt: false\n"
	if err := yaml.Unmarshal([]byte(input), &cfg); err != nil {
		t.Fatal(err)
	}
	out := t.TempDir()
	if err := render(cfg, home, out); err != nil {
		t.Fatal(err)
	}
	aliases, err := os.ReadFile(filepath.Join(out, "15-aliases.zsh"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(aliases)
	if !strings.Contains(text, "alias g='git'") || !strings.Contains(text, custom) {
		t.Fatalf("extend output is incomplete:\n%s", text)
	}
	if _, err := os.Stat(filepath.Join(out, "14-remote.zsh")); !os.IsNotExist(err) {
		t.Fatal("disabled remote segment was generated")
	}
	if _, err := os.Stat(filepath.Join(out, "16-prompt.zsh")); !os.IsNotExist(err) {
		t.Fatal("disabled prompt segment was generated")
	}
}

func TestAtomicWriteReplacesContent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "file")
	if err := atomicWrite(path, []byte("first"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := atomicWrite(path, []byte("second"), 0o600); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "second" {
		t.Fatalf("got %q", data)
	}
}

func TestDetectConflictsIsAdvisory(t *testing.T) {
	path := filepath.Join(t.TempDir(), ".zshrc")
	if err := os.WriteFile(path, []byte("eval \"$(starship init zsh)\"\nalias ll='ls'\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	got := strings.Join(detectConflicts(path), ",")
	if !strings.Contains(got, "prompt initialization") || !strings.Contains(got, "aliases") {
		t.Fatalf("missing conflicts: %s", got)
	}
}
