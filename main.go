package main

import (
	"bytes"
	"embed"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

const marker = "# managed-by: zshenv"

var segments = []string{"core", "paths", "completion", "integrations", "remote", "aliases", "prompt", "ux"}
var optionalCommands = []string{"fzf", "zoxide", "mise", "docker", "kubectl", "tmux", "ssh"}

//go:embed dot_config/zsh/*.zsh dot_zshrc config/shell.default.yaml
var assets embed.FS

type paths struct {
	home, configDir, configFile, generatedDir, customDir, loader string
}

type config struct {
	Version int                  `yaml:"version"`
	Shell   map[string]yaml.Node `yaml:"shell"`
}

type segmentMode int

const (
	modeDefault segmentMode = iota
	modeDisabled
	modeReplace
	modeExtend
)

type segmentSpec struct {
	Name   string
	Mode   segmentMode
	Custom string
}

type app struct {
	paths paths
	out   *os.File
	err   *os.File
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "zshenv:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	p, err := resolvePaths()
	if err != nil {
		return err
	}
	a := app{paths: p, out: os.Stdout, err: os.Stderr}
	if len(args) == 0 {
		return errors.New("usage: zshenv [--config PATH] <init|check|diff|apply|status>")
	}

	global := flag.NewFlagSet("zshenv", flag.ContinueOnError)
	global.SetOutput(a.err)
	configPath := global.String("config", p.configFile, "configuration file")
	if err := global.Parse(args); err != nil {
		return err
	}
	rest := global.Args()
	if len(rest) == 0 {
		return errors.New("missing command")
	}

	switch rest[0] {
	case "init":
		set := flag.NewFlagSet("init", flag.ContinueOnError)
		set.SetOutput(a.err)
		adopt := set.Bool("adopt", false, "preserve and load existing .zshrc")
		replace := set.Bool("replace", false, "replace existing .zshrc after backup")
		if err := set.Parse(rest[1:]); err != nil {
			return err
		}
		if *adopt && *replace {
			return errors.New("--adopt and --replace are mutually exclusive")
		}
		return a.init(*configPath, *adopt, *replace)
	case "check":
		return a.check(*configPath)
	case "diff":
		return a.diff(*configPath)
	case "apply":
		return a.apply(*configPath)
	case "status":
		return a.status(*configPath)
	default:
		return fmt.Errorf("unknown command: %s", rest[0])
	}
}

func resolvePaths() (paths, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return paths{}, fmt.Errorf("resolve home: %w", err)
	}
	configHome := os.Getenv("XDG_CONFIG_HOME")
	if configHome == "" {
		configHome = filepath.Join(home, ".config")
	}
	configDir := filepath.Join(configHome, "zsh")
	return paths{
		home:         home,
		configDir:    configDir,
		configFile:   filepath.Join(configDir, "shell.yaml"),
		generatedDir: filepath.Join(configDir, "generated"),
		customDir:    filepath.Join(configDir, "custom"),
		loader:       filepath.Join(home, ".zshrc"),
	}, nil
}

func loadConfig(path string) (config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return config{}, fmt.Errorf("read config: %w", err)
	}
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	var cfg config
	if err := dec.Decode(&cfg); err != nil {
		return config{}, fmt.Errorf("invalid YAML: %w", err)
	}
	if cfg.Version != 1 || cfg.Shell == nil {
		return config{}, errors.New("config must contain `version: 1` and a `shell` mapping")
	}
	allowed := map[string]bool{}
	for _, name := range segments {
		allowed[name] = true
	}
	for name := range cfg.Shell {
		if !allowed[name] {
			return config{}, fmt.Errorf("unknown shell segment: %s", name)
		}
	}
	return cfg, nil
}

func parseSegment(name string, node yaml.Node, home string) (segmentSpec, error) {
	spec := segmentSpec{Name: name, Mode: modeDefault}
	if node.Kind == 0 || (node.Kind == yaml.MappingNode && len(node.Content) == 0) {
		return spec, nil
	}
	if node.Kind == yaml.ScalarNode && node.Tag == "!!bool" && node.Value == "false" {
		spec.Mode = modeDisabled
		return spec, nil
	}
	if node.Kind != yaml.MappingNode {
		return spec, fmt.Errorf("shell.%s must be an object or false", name)
	}

	fields := map[string]*yaml.Node{}
	for i := 0; i < len(node.Content); i += 2 {
		fields[node.Content[i].Value] = node.Content[i+1]
	}
	if name == "prompt" {
		for key := range fields {
			if key != "engine" && key != "path" {
				return spec, fmt.Errorf("unknown shell.prompt field: %s", key)
			}
		}
		engine := "starship"
		if n := fields["engine"]; n != nil {
			if n.Kind != yaml.ScalarNode {
				return spec, errors.New("shell.prompt.engine must be a string")
			}
			engine = n.Value
		}
		if engine != "starship" {
			return spec, fmt.Errorf("unsupported prompt engine: %s", engine)
		}
		if n := fields["path"]; n != nil {
			path, err := expandPath(n.Value, home)
			if err != nil {
				return spec, fmt.Errorf("shell.prompt.path: %w", err)
			}
			spec.Mode, spec.Custom = modeReplace, path
		}
		return spec, nil
	}

	for key := range fields {
		if key != "path" && key != "extend" {
			return spec, fmt.Errorf("unknown shell.%s field: %s", name, key)
		}
	}
	if fields["path"] != nil && fields["extend"] != nil {
		return spec, fmt.Errorf("shell.%s cannot contain both path and extend", name)
	}
	if n := fields["path"]; n != nil {
		path, err := expandPath(n.Value, home)
		if err != nil {
			return spec, fmt.Errorf("shell.%s.path: %w", name, err)
		}
		spec.Mode, spec.Custom = modeReplace, path
		return spec, nil
	}
	if n := fields["extend"]; n != nil {
		if n.Kind != yaml.MappingNode || len(n.Content) != 2 || n.Content[0].Value != "path" {
			return spec, fmt.Errorf("shell.%s.extend must contain only path", name)
		}
		path, err := expandPath(n.Content[1].Value, home)
		if err != nil {
			return spec, fmt.Errorf("shell.%s.extend.path: %w", name, err)
		}
		spec.Mode, spec.Custom = modeExtend, path
		return spec, nil
	}
	return spec, nil
}

func expandPath(value, home string) (string, error) {
	if value == "" {
		return "", errors.New("path must be non-empty")
	}
	if strings.ContainsAny(value, "$`*?[]") || strings.Contains(value, "://") {
		return "", fmt.Errorf("path must not contain shell expansion, glob syntax, or URL: %s", value)
	}
	if strings.HasPrefix(value, "~/") {
		value = filepath.Join(home, strings.TrimPrefix(value, "~/"))
	}
	if !filepath.IsAbs(value) {
		return "", fmt.Errorf("path must be absolute or start with ~/: %s", value)
	}
	return filepath.Clean(value), nil
}

func resolve(cfg config, home string) ([]segmentSpec, error) {
	result := make([]segmentSpec, 0, len(segments))
	for _, name := range segments {
		node := cfg.Shell[name]
		spec, err := parseSegment(name, node, home)
		if err != nil {
			return nil, err
		}
		result = append(result, spec)
	}
	return result, nil
}

func render(cfg config, home, output string) error {
	specs, err := resolve(cfg, home)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(output, 0o700); err != nil {
		return err
	}
	for i, spec := range specs {
		if spec.Mode == modeDisabled {
			continue
		}
		if spec.Custom != "" {
			info, err := os.Stat(spec.Custom)
			if err != nil || info.IsDir() {
				return fmt.Errorf("custom file not found: %s", spec.Custom)
			}
		}
		var content strings.Builder
		content.WriteString("# Generated by zshenv. Do not edit.\n")
		if spec.Name == "prompt" && spec.Mode == modeReplace {
			if _, err := exec.LookPath("starship"); err != nil {
				return errors.New("starship is selected with a custom config but is not installed")
			}
			content.WriteString("export STARSHIP_CONFIG=" + quoteZsh(spec.Custom) + "\n")
			content.WriteString("eval \"$(starship init zsh)\"\n")
		} else {
			if spec.Mode == modeDefault || spec.Mode == modeExtend {
				data, err := fs.ReadFile(assets, "dot_config/zsh/"+spec.Name+".zsh")
				if err != nil {
					return fmt.Errorf("read embedded default %s: %w", spec.Name, err)
				}
				content.Write(data)
				if len(data) > 0 && data[len(data)-1] != '\n' {
					content.WriteByte('\n')
				}
			}
			if spec.Mode == modeReplace || spec.Mode == modeExtend {
				content.WriteString(sourceCustom(spec.Custom))
			}
		}
		name := fmt.Sprintf("%02d-%s.zsh", 10+i, spec.Name)
		if err := os.WriteFile(filepath.Join(output, name), []byte(content.String()), 0o600); err != nil {
			return err
		}
	}
	return nil
}

func quoteZsh(value string) string { return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'" }

func sourceCustom(path string) string {
	q := quoteZsh(path)
	return fmt.Sprintf("if [[ ! -r %s ]]; then\n  print -u2 -- %s\n  return 1\nfi\nsource %s\n", q, quoteZsh("zshenv: unreadable file: "+path), q)
}

func validateZsh(dir string) error {
	if _, err := exec.LookPath("zsh"); err != nil {
		return errors.New("zsh is not installed")
	}
	files, err := filepath.Glob(filepath.Join(dir, "*.zsh"))
	if err != nil {
		return err
	}
	sort.Strings(files)
	for _, file := range files {
		cmd := exec.Command("zsh", "-n", file)
		if out, err := cmd.CombinedOutput(); err != nil {
			return fmt.Errorf("invalid generated Zsh %s: %s", filepath.Base(file), strings.TrimSpace(string(out)))
		}
	}
	return nil
}

func (a app) check(configPath string) error {
	cfg, err := loadConfig(configPath)
	if err != nil {
		return err
	}
	temp, err := os.MkdirTemp("", "zshenv-check-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(temp)
	if err := render(cfg, a.paths.home, temp); err != nil {
		return err
	}
	if err := validateZsh(temp); err != nil {
		return err
	}
	fmt.Fprintln(a.out, "[ok] configuration")
	fmt.Fprintln(a.out, "[ok] generated Zsh syntax")
	for _, command := range optionalCommands {
		state := "ok"
		if _, err := exec.LookPath(command); err != nil {
			state = "skip"
		}
		fmt.Fprintf(a.out, "[%s] %s\n", state, command)
	}
	return nil
}

func (a app) apply(configPath string) error {
	cfg, err := loadConfig(configPath)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(a.paths.configDir, 0o700); err != nil {
		return err
	}
	staging, err := os.MkdirTemp(a.paths.configDir, ".generated.")
	if err != nil {
		return err
	}
	defer os.RemoveAll(staging)
	if err := render(cfg, a.paths.home, staging); err != nil {
		return err
	}
	if err := validateZsh(staging); err != nil {
		return err
	}
	previous := filepath.Join(a.paths.configDir, ".generated.previous")
	_ = os.RemoveAll(previous)
	if _, err := os.Stat(a.paths.generatedDir); err == nil {
		if err := os.Rename(a.paths.generatedDir, previous); err != nil {
			return fmt.Errorf("preserve previous generated state: %w", err)
		}
	}
	if err := os.Rename(staging, a.paths.generatedDir); err != nil {
		if _, statErr := os.Stat(previous); statErr == nil {
			_ = os.Rename(previous, a.paths.generatedDir)
		}
		return fmt.Errorf("activate generated state: %w", err)
	}
	_ = os.RemoveAll(previous)
	fmt.Fprintln(a.out, "Applied shell configuration.")
	return nil
}

func (a app) diff(configPath string) error {
	cfg, err := loadConfig(configPath)
	if err != nil {
		return err
	}
	temp, err := os.MkdirTemp("", "zshenv-diff-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(temp)
	if err := render(cfg, a.paths.home, temp); err != nil {
		return err
	}
	oldFiles := readDirFiles(a.paths.generatedDir)
	newFiles := readDirFiles(temp)
	names := map[string]bool{}
	for name := range oldFiles { names[name] = true }
	for name := range newFiles { names[name] = true }
	ordered := make([]string, 0, len(names))
	for name := range names { ordered = append(ordered, name) }
	sort.Strings(ordered)
	changed := false
	for _, name := range ordered {
		oldText, newText := oldFiles[name], newFiles[name]
		if oldText == newText { continue }
		changed = true
		fmt.Fprintf(a.out, "--- a/%s\n+++ b/%s\n", name, name)
		fmt.Fprint(a.out, simpleDiff(oldText, newText))
	}
	if !changed { fmt.Fprintln(a.out, "No generated changes.") }
	return nil
}

func readDirFiles(dir string) map[string]string {
	result := map[string]string{}
	entries, err := os.ReadDir(dir)
	if err != nil { return result }
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".zsh") { continue }
		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err == nil { result[entry.Name()] = string(data) }
	}
	return result
}

func simpleDiff(oldText, newText string) string {
	var b strings.Builder
	if oldText != "" {
		for _, line := range strings.Split(strings.TrimSuffix(oldText, "\n"), "\n") { b.WriteString("-"+line+"\n") }
	}
	if newText != "" {
		for _, line := range strings.Split(strings.TrimSuffix(newText, "\n"), "\n") { b.WriteString("+"+line+"\n") }
	}
	return b.String()
}

func (a app) init(configPath string, adopt, replace bool) error {
	existing, unmanaged, err := inspectLoader(a.paths.loader)
	if err != nil { return err }
	conflicts := []string{}
	if existing && unmanaged { conflicts = detectConflicts(a.paths.loader) }
	if existing && unmanaged && !adopt && !replace {
		fmt.Fprintln(a.out, "Existing ~/.zshrc detected. No active files were changed.")
		if len(conflicts) > 0 {
			fmt.Fprintln(a.out, "Potential conflicts:")
			for _, item := range conflicts { fmt.Fprintln(a.out, "  -", item) }
		}
		fmt.Fprintln(a.out, "Choose: `zshenv init --adopt` or `zshenv init --replace`.")
		return errors.New("existing unmanaged .zshrc requires an explicit decision")
	}
	if err := os.MkdirAll(a.paths.customDir, 0o700); err != nil { return err }
	if _, err := os.Stat(configPath); errors.Is(err, os.ErrNotExist) {
		data, readErr := fs.ReadFile(assets, "config/shell.default.yaml")
		if readErr != nil { return readErr }
		if err := atomicWrite(configPath, data, 0o600); err != nil { return err }
	} else if err != nil { return err }

	if existing && unmanaged {
		stamp := time.Now().UTC().Format("20060102T150405Z")
		backup := filepath.Join(a.paths.home, ".zshrc.backup-"+stamp)
		data, err := os.ReadFile(a.paths.loader)
		if err != nil { return err }
		if err := atomicWrite(backup, data, 0o600); err != nil { return err }
		fmt.Fprintln(a.out, "Backup:", backup)
		if adopt {
			migrated := filepath.Join(a.paths.customDir, "migrated.zsh")
			if _, err := os.Stat(migrated); err == nil { return fmt.Errorf("refusing to overwrite existing migration: %s", migrated) }
			if err := atomicWrite(migrated, data, 0o600); err != nil { return err }
			fmt.Fprintln(a.out, "Preserved existing config:", migrated)
		}
	}
	if err := a.apply(configPath); err != nil { return err }
	loader, err := fs.ReadFile(assets, "dot_zshrc")
	if err != nil { return err }
	if err := atomicWrite(a.paths.loader, loader, 0o600); err != nil { return err }
	if len(conflicts) > 0 { fmt.Fprintln(a.out, "Potential conflicts remain user-owned; zshenv did not resolve them.") }
	return nil
}

func inspectLoader(path string) (exists, unmanaged bool, err error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) { return false, false, nil }
	if err != nil { return false, false, err }
	return true, !strings.Contains(string(data), marker), nil
}

var conflictPatterns = []struct{name, pattern string}{
	{"prompt initialization", `(starship init|oh-my-posh init|powerlevel10k|p10k)`},
	{"tool integration", `(mise activate|pyenv init|nvm\.sh|zoxide init|direnv hook|atuin init)`},
	{"completion initialization", `\bcompinit\b`},
	{"aliases", `(?m)^\s*alias\s+`},
	{"keybindings", `\bbindkey\b`},
}

func detectConflicts(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil { return nil }
	text := strings.ToLower(string(data))
	var result []string
	for _, item := range conflictPatterns {
		if regexp.MustCompile(item.pattern).MatchString(text) { result = append(result, item.name) }
	}
	return result
}

func atomicWrite(path string, data []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil { return err }
	temp, err := os.CreateTemp(filepath.Dir(path), ".zshenv-write-")
	if err != nil { return err }
	name := temp.Name()
	defer os.Remove(name)
	if err := temp.Chmod(mode); err != nil { temp.Close(); return err }
	if _, err := temp.Write(data); err != nil { temp.Close(); return err }
	if err := temp.Sync(); err != nil { temp.Close(); return err }
	if err := temp.Close(); err != nil { return err }
	return os.Rename(name, path)
}

func (a app) status(configPath string) error {
	_, unmanaged, err := inspectLoader(a.paths.loader)
	if err != nil { return err }
	loader := "managed"
	if unmanaged { loader = "unmanaged" }
	if _, err := os.Stat(a.paths.loader); errors.Is(err, os.ErrNotExist) { loader = "missing" }
	generated := "missing"
	if info, err := os.Stat(a.paths.generatedDir); err == nil && info.IsDir() { generated = "present" }
	customCount := 0
	if entries, err := os.ReadDir(a.paths.customDir); err == nil { customCount = len(entries) }
	fmt.Fprintln(a.out, "Config:   ", configPath)
	fmt.Fprintln(a.out, "Loader:   ", loader)
	fmt.Fprintln(a.out, "Generated:", generated)
	fmt.Fprintf(a.out, "Custom:    %d files\n", customCount)
	return nil
}
