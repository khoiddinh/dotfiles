#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf "\n==> %s\n" "$1"; }

# If dst exists and is NOT the exact symlink we want, back it up.
backup_if_needed() {
  local dst="$1"
  local want_src="$2"

  if [ -L "$dst" ]; then
    local cur
    cur="$(readlink "$dst" || true)"
    if [ "$cur" = "$want_src" ]; then
      return 0
    fi
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
    log "Backing up $dst -> $backup"
    mv "$dst" "$backup"
  fi
}

# Symlink src -> dst (idempotent).
link() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  backup_if_needed "$dst" "$src"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

# Adopt: if repo file missing but system file exists, copy it into repo.
adopt_if_missing() {
  local repo_file="$1"
  local system_file="$2"
  mkdir -p "$(dirname "$repo_file")"

  if [ ! -e "$repo_file" ] && [ -f "$system_file" ] && [ ! -L "$system_file" ]; then
    log "Adopting existing config: $system_file -> $repo_file"
    cp "$system_file" "$repo_file"
  fi
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

clone_omz_plugin() {
  local name="$1"
  local url="$2"
  local dir="$HOME/.oh-my-zsh/custom/plugins/$name"
  if [ -d "$dir/.git" ]; then
    log "OMZ plugin exists: $name"
  else
    log "Cloning OMZ plugin: $name"
    git clone --depth=1 "$url" "$dir"
  fi
}

install_lunarvim() {
  # If lvim already exists, skip.
  if [ -x "$HOME/.local/bin/lvim" ] || command -v lvim >/dev/null 2>&1; then
    log "LunarVim already installed"
    return 0
  fi

  log "Installing LunarVim (stable release 1.4 / Neovim 0.9)"
  # -y disables prompts; --no-install-dependencies because we use brew bundle
  LV_BRANCH='release-1.4/neovim-0.9' \
    bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) \
    -y --no-install-dependencies
}

main() {
  ensure_homebrew

  # 1) Brew packages (idempotent)
  if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    log "Installing Brewfile packages"
    brew bundle --file "$DOTFILES_DIR/Brewfile"
  else
    log "No Brewfile found at $DOTFILES_DIR/Brewfile (skipping brew bundle)"
  fi

  # 2) Adopt configs into repo (migration mode) if repo files missing
  # Ghostty
  adopt_if_missing "$DOTFILES_DIR/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  # Zsh
  adopt_if_missing "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  adopt_if_missing "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
  # LunarVim
  adopt_if_missing "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"
  # Starship
  if [ ! -e "$DOTFILES_DIR/starship/starship.toml" ] && command -v starship >/dev/null 2>&1; then
    log "Generating starship preset into repo"
    mkdir -p "$DOTFILES_DIR/starship"
    starship preset nerd-font-symbols -o "$DOTFILES_DIR/starship/starship.toml"
  fi

  # 3) Oh My Zsh + plugins
  install_oh_my_zsh
  clone_omz_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
  clone_omz_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
  clone_omz_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

  # 4) Link configs (repo -> system)
  log "Linking zsh"
  [ -f "$DOTFILES_DIR/zsh/zshrc" ] && link "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  [ -f "$DOTFILES_DIR/zsh/zprofile" ] && link "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"

  log "Linking starship"
  if [ -f "$DOTFILES_DIR/starship/starship.toml" ]; then
    link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
  fi

  log "Linking Ghostty"
  # Ghostty loads macOS path first, then XDG path; linking both keeps them consistent. :contentReference[oaicite:4]{index=4}
  link "$DOTFILES_DIR/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  link "$DOTFILES_DIR/ghostty/config" \
    "$HOME/.config/ghostty/config"

  # 5) LunarVim automatic install + link config
  install_lunarvim
  if [ -f "$DOTFILES_DIR/lvim/config.lua" ]; then
    link "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"
  fi

  log "All set. Restart Ghostty + open a new shell."
}

main "$@"

