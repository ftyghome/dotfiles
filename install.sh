#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing dotfiles from $DOTFILES_DIR"

# Clean up existing tmux configurations
echo "Cleaning up existing tmux configurations..."
rm -rf ~/.tmux ~/.tmux.conf ~/.config/tmux

# Clean up existing vim configurations
echo "Cleaning up existing vim configurations..."
rm -rf ~/.vimrc ~/.vim ~/.config/vim

# Create necessary directories
echo "Creating directories..."
mkdir -p ~/.config/tmux
mkdir -p ~/.config/vim/pack/plugins/start

# Symlink tmux configuration
echo "Linking tmux configuration..."
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" ~/.config/tmux/tmux.conf
ln -sf "$DOTFILES_DIR/tmux/dotbar.tmux" ~/.config/tmux/dotbar.tmux

# Symlink vim configuration
echo "Linking vim configuration..."
ln -sf "$DOTFILES_DIR/vim/.vimrc" ~/.vimrc
ln -sf "$DOTFILES_DIR/vim/vim-airline" ~/.config/vim/pack/plugins/start/vim-airline

# Install Claude statusline
echo "Installing Claude statusline..."
mkdir -p ~/.claude
ln -sf "$DOTFILES_DIR/claude/statusline-command.sh" ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

CLAUDE_SETTINGS=~/.claude/settings.json
STATUSLINE_CMD="bash $HOME/.claude/statusline-command.sh"
if [ -f "$CLAUDE_SETTINGS" ]; then
  tmp=$(mktemp)
  jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
else
  printf '{"statusLine":{"type":"command","command":"%s"}}\n' "$STATUSLINE_CMD" | jq . > "$CLAUDE_SETTINGS"
fi

# ---- zsh / oh-my-zsh ----
echo "Setting up zsh / oh-my-zsh..."

# Ensure oh-my-zsh is installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM_DIR/themes" "$ZSH_CUSTOM_DIR/plugins"

# powerlevel10k theme (git submodule) -> omz custom themes
echo "Linking powerlevel10k theme..."
git -C "$DOTFILES_DIR" submodule update --init zsh/custom/themes/powerlevel10k
rm -rf "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
ln -s "$DOTFILES_DIR/zsh/custom/themes/powerlevel10k" "$ZSH_CUSTOM_DIR/themes/powerlevel10k"

# external plugins: brew on macOS, vendored submodules on Linux
if [[ "$OSTYPE" == darwin* ]]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing zsh plugins via brew..."
    for p in zsh-autosuggestions zsh-syntax-highlighting; do
      brew list "$p" >/dev/null 2>&1 || brew install "$p"
    done
  else
    echo "WARNING: brew not found; zsh-autosuggestions/zsh-syntax-highlighting not installed."
  fi
else
  echo "Linking zsh plugins (submodules)..."
  git -C "$DOTFILES_DIR" submodule update --init \
    zsh/custom/plugins/zsh-autosuggestions zsh/custom/plugins/zsh-syntax-highlighting
  for p in zsh-autosuggestions zsh-syntax-highlighting; do
    rm -rf "$ZSH_CUSTOM_DIR/plugins/$p"
    ln -s "$DOTFILES_DIR/zsh/custom/plugins/$p" "$ZSH_CUSTOM_DIR/plugins/$p"
  done
fi

# Idempotently source the shared zsh config from the tail of ~/.zshrc
ZSHRC="$HOME/.zshrc"
MARKER="# >>> dotfiles zsh shared >>>"
if [ -f "$ZSHRC" ] && grep -qF "$MARKER" "$ZSHRC"; then
  echo "~/.zshrc already sources the shared config; skipping."
else
  echo "Appending shared zsh config source to ~/.zshrc..."
  cat >> "$ZSHRC" <<EOF

$MARKER
source "$DOTFILES_DIR/zsh/zshrc.shared"
# <<< dotfiles zsh shared <<<
EOF
fi

echo "Installation complete!"
