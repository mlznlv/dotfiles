package main

import (
	"os"
	"path/filepath"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestExpandPathRejectsExecutableSyntax(t *testing.T) {
	home := t.TempDir()
	for _, value := range []string{
		"$HOME/file.zsh",
		"$(touch /tmp/pwned)",
		"`touch /tmp/pwned`",
		"~/file*.zsh",
		"https://example.invalid/file.zsh",
		"relative/file.zsh",
	} {
		if _, err := expandPath(value, home); err == nil {
			t.Fatalf("expected path %q to be rejected", value)
		}
	}
}

func TestParseSegmentRejectsAmbiguousComposition(t *testing.T) {
	var node yaml.Node
	if err := yaml.Unmarshal([]byte("{path: /tmp/a.zsh, extend: {path: /tmp/b.zsh}}"), &node); err != nil {
		t.Fatal(err)
	}
	if _, err := parseSegment("aliases", *node.Content[0], t.TempDir()); err == nil {
		t.Fatal("expected path plus extend to be rejected")
	}
}

func TestInitRefusesToOverwriteMigratedConfig(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	if err := os.MkdirAll(a.paths.customDir, 0o700); err != nil {
		t.Fatal(err)
	}
	migrated := filepath.Join(a.paths.customDir, "migrated.zsh")
	if err := os.WriteFile(migrated, []byte("user owned\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(a.paths.loader, []byte("alias old='yes'\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := a.init(a.paths.configFile, true, false); err == nil {
		t.Fatal("expected adopt to refuse overwriting migrated.zsh")
	}
	got, err := os.ReadFile(migrated)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "user owned\n" {
		t.Fatal("existing migrated.zsh was modified")
	}
}

func TestAtomicWriteUsesPrivatePermissions(t *testing.T) {
	path := filepath.Join(t.TempDir(), "nested", "file")
	if err := atomicWrite(path, []byte("content"), 0o600); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("unexpected mode: %o", info.Mode().Perm())
	}
}
