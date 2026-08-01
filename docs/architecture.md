# Architecture

`zshenv` is a local configuration compiler for Zsh.

## Ownership

- Embedded defaults are owned by the project.
- `~/.config/zsh/generated/` is derived state and may be replaced atomically.
- Files referenced by YAML and files under `custom/` are user-owned and are never modified or deleted.
- `~/.zshrc` is replaced only after an explicit migration choice and backup.

## Apply flow

```text
shell.yaml
  -> parse and validate
  -> resolve effective segments
  -> render into a staging directory
  -> validate with `zsh -n`
  -> atomically activate generated state
```

If validation or activation fails, the previous generated state remains active.

## Segment contract

- Missing or `{}`: embedded default.
- `path`: replace with a user-owned file.
- `extend.path`: embedded default followed by a user-owned file.
- `false`: disabled.

Prompt configuration uses an engine-specific native configuration file and is not composed as two simultaneous prompts.

## Trust boundary

YAML is declarative and cannot contain shell interpolation, URLs, globs, or commands. User-provided Zsh files are executable code; the tool validates syntax but cannot prove their safety or absence of side effects.

## Non-goals

The project is not a package manager, dotfiles synchronizer, remote-code loader, dynamic plugin runtime, or general-purpose shell framework.
