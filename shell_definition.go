package main

import "fmt"

// shellDefinition contains shell-specific metadata used by the generic
// configuration lifecycle. It is intentionally small: render and migration
// abstractions will be added only when a second shell is implemented.
type shellDefinition interface {
	Name() string
	Segments() []string
	OptionalCommands() []string
	LoaderFile() string
	ConfigDirectory() string
	GeneratedExtension() string
}

type zshDefinition struct{}

func (zshDefinition) Name() string { return "zsh" }

func (zshDefinition) Segments() []string {
	return []string{"core", "paths", "completion", "integrations", "remote", "aliases", "prompt", "ux"}
}

func (zshDefinition) OptionalCommands() []string {
	return []string{"fzf", "zoxide", "mise", "docker", "kubectl", "tmux", "ssh"}
}

func (zshDefinition) LoaderFile() string         { return ".zshrc" }
func (zshDefinition) ConfigDirectory() string    { return "zsh" }
func (zshDefinition) GeneratedExtension() string { return ".zsh" }

var shellDefinitions = map[string]shellDefinition{
	"zsh": zshDefinition{},
}

var activeShell = mustShellDefinition("zsh")

func mustShellDefinition(name string) shellDefinition {
	definition, ok := shellDefinitions[name]
	if !ok {
		panic(fmt.Sprintf("unsupported shell definition: %s", name))
	}
	return definition
}

func init() {
	// Keep the existing lifecycle unchanged while making its shell metadata
	// originate from one explicit boundary.
	segments = activeShell.Segments()
	optionalCommands = activeShell.OptionalCommands()
}
