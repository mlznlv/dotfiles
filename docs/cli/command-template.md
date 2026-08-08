# Documenting a command

Command pages are for people using the CLI. Keep architecture, implementation,
and test details in contributor documentation or the pull request.

## Writing rules

1. Lead with the outcome: explain what the command helps the user do.
2. Show exact syntax before describing internals.
3. Prefer one realistic success example over several minor variations.
4. State prerequisites, side effects, and destructive behavior plainly.
5. Document current behavior only; link planned work to the roadmap.
6. Reuse common guidance by linking to the command guide instead of copying it.
7. Keep paragraphs short and use tables only when they improve scanning.

## Standard page order

Use this order so readers can scan every command page the same way:

1. Breadcrumb back to the command guide.
2. Task-oriented title and one-sentence summary.
3. Availability, effect, and primary requirement.
4. Usage syntax.
5. Arguments or options, when present.
6. Copy-paste examples.
7. Output and important behavior.
8. Common failures and exit codes.
9. Safety notes and related commands.

Omit a section when it adds no useful information.

## Minimal template

~~~markdown
[Command guide](README.md) / Command name

# Verb + outcome

One sentence explaining when to use the command.

**Available · Read-only or mutating · Main requirement**

## Usage

    dotfiles command <argument> [--option <value>]

## Options

| Option | Meaning |
| --- | --- |
| `--option <value>` | Explain the value and default |

## Example

Show one command and the output a user should expect.

## What it returns

Explain output, ordering, files changed, provider calls, and idempotency only
when relevant to the user.

## Common failures

List likely failures and the next corrective action.

## Exit codes

- `0` — success.
- Other documented codes and their meaning.

End with links to the next useful command and the command guide.
~~~

## Review checklist

Before merging a command page, verify:

- Syntax, flags, defaults, output, and exit codes against the real CLI.
- Examples are safe, current, sanitized, and copyable.
- Read-only or mutating behavior is unmistakable.
- Network, privilege, provider, file, privacy, and secret effects are stated.
- Interactive prompts and non-interactive requirements are covered when used.
- Errors tell the reader what to do next.
- Navigation links work and the page does not duplicate shared guidance.
- Behavior and help-output tests ship with the command implementation.
