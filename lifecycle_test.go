package main

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func newTestApp(t *testing.T) (app, string) {
	t.Helper()
	home := t.TempDir()
	configDir := filepath.Join(home, ".config", "zsh")
	out, err := os.CreateTemp(t.TempDir(), "stdout-")
	if err != nil {
		t.Fatal(err)
	}
	errOut, err := os.CreateTemp(t.TempDir(), "stderr-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = out.Close()
		_ = errOut.Close()
	})
	return app{
		paths: paths{
			home:         home,
			configDir:    configDir,
			configFile:   filepath.Join(configDir, "shell.yaml"),
			generatedDir: filepath.Join(configDir, "generated"),
			customDir:    filepath.Join(configDir, "custom"),
			loader:       filepath.Join(home, ".zshrc"),
		},
		out: out,
		err: errOut,
	}, home
}

func readOutput(t *testing.T, file *os.File) string {
	t.Helper()
	if _, err := file.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	data, err := io.ReadAll(file)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func writeDefaultConfig(t *testing.T, path string) {
	t.Helper()
	content := "version: 1\nshell:\n  prompt: false\n"
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestInitCleanMachine(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)

	if err := a.init(a.paths.configFile, false, false); err != nil {
		t.Fatal(err)
	}

	loader, err := os.ReadFile(a.paths.loader)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(loader), marker) {
		t.Fatal("managed loader was not installed")
	}
	if info, err := os.Stat(a.paths.generatedDir); err != nil || !info.IsDir() {
		t.Fatal("generated directory was not activated")
	}
}

func TestInitRequiresExplicitDecision(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	original := []byte("alias existing='yes'\n")
	if err := os.WriteFile(a.paths.loader, original, 0o600); err != nil {
		t.Fatal(err)
	}

	if err := a.init(a.paths.configFile, false, false); err == nil {
		t.Fatal("expected explicit-decision error")
	}
	got, err := os.ReadFile(a.paths.loader)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(original) {
		t.Fatal("unmanaged .zshrc was modified")
	}
	if _, err := os.Stat(a.paths.generatedDir); !os.IsNotExist(err) {
		t.Fatal("generated state changed before migration decision")
	}
}

func TestInitAdoptPreservesAndLoadsExistingConfig(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	original := []byte("alias existing='yes'\n")
	if err := os.WriteFile(a.paths.loader, original, 0o640); err != nil {
		t.Fatal(err)
	}

	if err := a.init(a.paths.configFile, true, false); err != nil {
		t.Fatal(err)
	}

	migrated := filepath.Join(a.paths.customDir, "migrated.zsh")
	got, err := os.ReadFile(migrated)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(original) {
		t.Fatal("adopted config differs from original")
	}
	loader, err := os.ReadFile(a.paths.loader)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(loader), "custom/migrated.zsh") {
		t.Fatal("managed loader does not load adopted config")
	}
	backups, err := filepath.Glob(filepath.Join(a.paths.home, ".zshrc.backup-*"))
	if err != nil || len(backups) != 1 {
		t.Fatalf("expected one backup, got %v (%v)", backups, err)
	}
}

func TestInitReplaceBacksUpWithoutAdopting(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	original := []byte("alias existing='yes'\n")
	if err := os.WriteFile(a.paths.loader, original, 0o600); err != nil {
		t.Fatal(err)
	}

	if err := a.init(a.paths.configFile, false, true); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(a.paths.customDir, "migrated.zsh")); !os.IsNotExist(err) {
		t.Fatal("replace unexpectedly created migrated.zsh")
	}
	backups, err := filepath.Glob(filepath.Join(a.paths.home, ".zshrc.backup-*"))
	if err != nil || len(backups) != 1 {
		t.Fatalf("expected one backup, got %v (%v)", backups, err)
	}
	backup, err := os.ReadFile(backups[0])
	if err != nil {
		t.Fatal(err)
	}
	if string(backup) != string(original) {
		t.Fatal("backup differs from original")
	}
}

func TestApplyValidationFailurePreservesActiveState(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	if err := a.apply(a.paths.configFile); err != nil {
		t.Fatal(err)
	}
	before := readDirFiles(a.paths.generatedDir)

	broken := filepath.Join(a.paths.customDir, "broken.zsh")
	if err := os.MkdirAll(a.paths.customDir, 0o700); err != nil {
		t.Fatal(err)
	}
	// An unterminated quote is rejected consistently by Zsh on macOS and Linux.
	if err := os.WriteFile(broken, []byte("print 'unterminated\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	badConfig := filepath.Join(a.paths.configDir, "broken.yaml")
	content := "version: 1\nshell:\n  prompt: false\n  aliases:\n    path: " + broken + "\n"
	if err := os.WriteFile(badConfig, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}

	if err := a.apply(badConfig); err == nil {
		t.Fatal("expected invalid Zsh to fail")
	}
	after := readDirFiles(a.paths.generatedDir)
	if len(before) != len(after) {
		t.Fatal("active generated state changed after failed validation")
	}
	for name, content := range before {
		if after[name] != content {
			t.Fatalf("active file %s changed after failed validation", name)
		}
	}
}

func TestGeneratedPermissions(t *testing.T) {
	a, _ := newTestApp(t)
	writeDefaultConfig(t, a.paths.configFile)
	if err := a.apply(a.paths.configFile); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(a.paths.generatedDir)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm()&0o077 != 0 {
		t.Fatalf("generated directory is too permissive: %o", info.Mode().Perm())
	}
	entries, err := os.ReadDir(a.paths.generatedDir)
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			t.Fatal(err)
		}
		if info.Mode().Perm()&0o077 != 0 {
			t.Fatalf("generated file %s is too permissive: %o", entry.Name(), info.Mode().Perm())
		}
	}
}

func TestStatusReportsMissingState(t *testing.T) {
	a, _ := newTestApp(t)
	if err := a.status(a.paths.configFile); err != nil {
		t.Fatal(err)
	}
	output := readOutput(t, a.out)
	if !strings.Contains(output, "Loader:    missing") || !strings.Contains(output, "Generated: missing") {
		t.Fatalf("unexpected status output:\n%s", output)
	}
}
