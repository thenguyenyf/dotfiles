#!/usr/bin/env bash
# Dotfiles install script — run by `coder dotfiles` on every workspace start.
#
# Why this exists instead of plain dotfile symlinking:
#   The built-in `coder dotfiles` symlink loop only backs up *regular files*
#   (cli/dotfiles.go: isRegular() -> fi.Mode().IsRegular()). If a dotfile's
#   destination already exists as a *directory* (e.g. ~/.vscode-server, which
#   the environment pre-creates with data/Machine), the symlink fails with
#   "symlink: file exists" and `coder dotfiles` aborts. So a `.vscode-server`
#   dotfile entry can never work on a fresh workspace.
#
#   When an install script exists, Coder runs it INSTEAD of symlinking, so we
#   own the whole setup here (and make it idempotent).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '[dotfiles] %s\n' "$*"; }

# 1) Install bash completions into the user bash-completion dir, where the
#    image's default .bashrc (via bash_completion) lazy-loads them by command
#    name. Files are named `git`/`west` so the loader finds them.
COMP_DIR="$HOME/.local/share/bash-completion/completions"
mkdir -p "$COMP_DIR"
for spec in "git:.git-completion.bash" "west:.west-completion.bash"; do
    name="${spec%%:*}"
    file="${spec#*:}"
    src="$REPO_DIR/$file"
    [ -f "$src" ] || continue
    dst="$COMP_DIR/$name"
    if [ -L "$dst" ]; then
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.bak"
    fi
    ln -s "$src" "$dst"
    log "linked $dst -> $src"
done

# 2) Install recommended VS Code extensions where VS Code actually reads them:
#    <workspace-root>/.vscode/extensions.json. (NOT ~/.vscode-server/extensions/,
#    which is the server's own installed-extension metadata and is ignored for
#    recommendations.) Re-copied on every start, so a dotfiles update
#    automatically propagates to every new workspace.
if [ -f "$REPO_DIR/extensions.json" ]; then
    if [ -d "$HOME/workspace" ]; then
        mkdir -p "$HOME/workspace/.vscode"
        cp "$REPO_DIR/extensions.json" "$HOME/workspace/.vscode/extensions.json"
        log "wrote recommended extensions to ~/workspace/.vscode/extensions.json"
    else
        log "no ~/workspace directory found; skipped extension recommendations"
    fi
fi

log "done"
