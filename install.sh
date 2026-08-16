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

# 1) Symlink vendored completion scripts into the user bash-completion dir,
#    named `git`/`west` so bash_completion's lazy loader would find them by
#    command name. This is the single source of truth for step 2 (which
#    sources everything in this dir directly), and stays correct on images
#    where bash_completion *is* installed.
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

# 2) Make the completions actually load. The image's .bashrc sources the
#    `bash_completion` lazy-loader *only if it is installed*, but this image
#    ships the completion data (/usr/share/bash-completion/completions/)
#    without the loader (/usr/share/bash-completion/bash_completion), so the
#    user dir is never lazy-loaded. Instead, append a marker-delimited block
#    to ~/.bashrc that sources every script in $COMP_DIR directly — each is
#    self-contained (defines its own helpers and ends in `complete -F ...`),
#    so it works with or without bash_completion. The block is replaced (not
#    duplicated) on every run, keeping this idempotent.
install_bashrc_hook() {
    local bashrc="$HOME/.bashrc"
    local start="# >>> dotfiles/bash-completions >>>"
    local end="# <<< dotfiles/bash-completions <<<"

    # Drop any block left by a previous run, then strip the trailing blank
    # lines it left behind so repeated runs leave the file byte-identical.
    if [ -f "$bashrc" ]; then
        if grep -qF "$start" "$bashrc"; then
            sed -i "\|^${start}$|,\|^${end}$|d" "$bashrc"
        fi
        # Remove trailing blank lines (GNU sed idiom).
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$bashrc"
    fi

    # Append a fresh block (also creates ~/.bashrc if it was absent).
    {
        printf '\n%s\n' "$start"
        cat <<'EOF'
for _f in "$HOME"/.local/share/bash-completion/completions/*; do
    [ -r "$_f" ] && . "$_f"
done
unset _f
EOF
        printf '%s\n' "$end"
    } >> "$bashrc"
    log "ensured ~/.bashrc sources completions from $COMP_DIR"
}
install_bashrc_hook

# 3) Install recommended VS Code extensions where VS Code actually reads them:
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
