package main

import (
	"reflect"
	"testing"
)

func TestZshDefinitionContract(t *testing.T) {
	definition := mustShellDefinition("zsh")

	if definition.Name() != "zsh" {
		t.Fatalf("unexpected shell name: %s", definition.Name())
	}
	if definition.LoaderFile() != ".zshrc" {
		t.Fatalf("unexpected loader file: %s", definition.LoaderFile())
	}
	if definition.ConfigDirectory() != "zsh" {
		t.Fatalf("unexpected config directory: %s", definition.ConfigDirectory())
	}
	if definition.GeneratedExtension() != ".zsh" {
		t.Fatalf("unexpected generated extension: %s", definition.GeneratedExtension())
	}

	wantSegments := []string{"core", "paths", "completion", "integrations", "remote", "aliases", "prompt", "ux"}
	if !reflect.DeepEqual(definition.Segments(), wantSegments) {
		t.Fatalf("unexpected segments: %#v", definition.Segments())
	}
}

func TestShellDefinitionReturnsIndependentSlices(t *testing.T) {
	definition := mustShellDefinition("zsh")
	first := definition.Segments()
	first[0] = "changed"
	second := definition.Segments()
	if second[0] != "core" {
		t.Fatal("shell definition exposed mutable shared metadata")
	}
}
