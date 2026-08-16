# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **dotfiles repository for Coder workspaces** (coder.com), tailored for Zephyr RTOS embedded development. It is not a buildable project — there is no build, lint, or test step. The only "command" is the install script, which Coder runs automatically.

## How installation works (the big picture)

Coder consumes this repo via `coder dotfiles`. The default Coder behavior symlinks every dotfile into `$HOME`, but there are two important deviations encoded here:

- **`install.sh` overrides the default.** When an `install.sh` exists at the repo root, Coder runs it *instead of* symlinking. The script's own comment explains why: Coder's symlink loop only backs up *regular files*, so a dotfile whose destination is a pre-existing *directory* (like `~/.vscode-server`) can never be symlinked. The script exists to own the whole setup idempotently.

- **Two install paths**, each chosen for a different reason:
  1. **Bash completions** (`git`, `west`), via two cooperating pieces:
     - Symlinked into the bash-completion user dir (`~/.local/share/bash-completion/completions/`): `.git-completion.bash` → `git` and `.west-completion.bash` → `west`. Entries are named `git`/`west` (not their dotfile names) because that's what `bash_completion`'s lazy loader matches; the `git` entry deliberately shadows the system `/usr/share/bash-completion/completions/git`.
     - The image's default `.bashrc` only lazy-loads that dir *if* `bash_completion` is installed — which it isn't here (the loader `/usr/share/bash-completion/bash_completion` is absent even though the data dir ships). So `install.sh` also appends a marker-delimited block to `~/.bashrc` that sources every script in the user dir directly. Each script is self-contained (defines its own helpers and ends in `complete -F ...`), so this works with or without `bash_completion`. The block is replaced, not duplicated, on each run.
  2. **Copied on every start**: `extensions.json` → `~/workspace/.vscode/extensions.json`. This is the path VS Code actually reads for *recommendations* (not `~/.vscode-server/extensions/`, which is the server's own installed-extension metadata). Re-copying each start means a dotfiles update propagates to all new workspaces.

## File responsibilities

- `install.sh` — entry point, run by `coder dotfiles` on every workspace start. Must stay **idempotent** (safe to run repeatedly, which it is on every workspace launch). Uses `set -euo pipefail`. Symlinks completion scripts into the user completion dir, then appends a marker-delimited block to `~/.bashrc` that sources that dir directly (the block is replaced, not duplicated, on each run).
- `.git-completion.bash`, `.west-completion.bash` — vendored upstream completion scripts (Git's core completion, GPL-2.0; west's completion). Treat as third-party; don't hand-edit. `install.sh` symlinks them into `~/.local/share/bash-completion/completions/` as `git`/`west`, and the `~/.bashrc` block sources that dir directly.
- `extensions.json` — VS Code `recommendations` for Zephyr (`ac6.zephyr-workbench`, `editorconfig.editorconfig`, `ms-vscode.cpptools-extension-pack`). This is the canonical copy; `install.sh` copies it into place.

## Making changes

- To change how a dotfile is installed (completions-dir symlink vs. copy), edit `install.sh`. Keep it idempotent and guard every step against the destination being an existing directory, a symlink, or absent.
- To add a new completion script, add a `name:file` pair to the `for spec in ...` loop in `install.sh`; it gets symlinked into the bash-completion user dir under `name` and is sourced automatically by the `~/.bashrc` block (which sources the whole dir). The script must register completion when sourced (e.g. end in `complete -F ... <name>`).
- Manually test the install with `./install.sh` from the repo root; it logs each action as `[dotfiles] ...`.
