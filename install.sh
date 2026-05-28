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

echo "Installation complete!"
