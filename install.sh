#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf "\n==> %s\n" "$1"; }

backup_if_exists() {
  local dst="$1"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backing up $dst -> $backup"
    mv "$dst" "$backup"
  fi
}

link() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    log "Already linked: $dst"
    return 0
  fi
  backup_if_exists "$dst"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

ensure_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

install_oh_my_zsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

clone_plugin() {
  local name="$1"
  local url="$2"
  local dir="$HOME/.oh-my-zsh/custom/plugins/$name"
  if [ -d "$dir/.git" ]; then
    log "Plugin exists: $name"
  else
    log "Cloning plugin: $name"
    git clone --depth=1 "$url" "$dir"
  fi
}

main() {
  ensure_homebrew

  if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    log "Installing Brewfile packages"
    brew bundle --file "$DOTFILES_DIR/Brewfile"
  fi

  install_oh_my_zsh

  # OMZ plugins
  clone_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
  clone_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
  clone_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

  # Link Zsh
  log "Linking zsh files"
  link "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  link "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"

  # Starship
  log "Linking starship"
  mkdir -p "$HOME/.config"
  link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

  # Ghostty (macOS path)
  log "Linking Ghostty config"
  GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$GHOSTTY_DIR"
  link "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_DIR/config"

  # Optional XDG path too
  mkdir -p "$HOME/.config/ghostty"
  link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"

  # LunarVim config
  log "Linking LunarVim config"
  mkdir -p "$HOME/.config/lvim"
  link "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"

  log "Done. Restart terminal + Ghostty."
  log "If LunarVim isn't installed yet, run its installer once (see below)."
}

main "$@"

