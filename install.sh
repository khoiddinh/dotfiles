#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENABLE_GIT=0
GIT_NAME=""
GIT_EMAIL=""

log() { printf "\n==> %s\n" "$1"; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [--git --git-name "Name" --git-email "email@example.com"]

Options:
  --git                 Enable git setup (rewrites git/gitconfig, links ~/.gitconfig)
  --git-name "NAME"     Git user.name (required with --git)
  --git-email "EMAIL"   Git user.email (required with --git)
  -h, --help            Show help
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --git) ENABLE_GIT=1; shift ;;
      --git-name) GIT_NAME="${2:-}"; shift 2 ;;
      --git-email) GIT_EMAIL="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
  done

  if [ "$ENABLE_GIT" -eq 1 ] && { [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; }; then
    echo "Error: --git requires --git-name and --git-email" >&2
    usage >&2
    exit 2
  fi
}

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

# Render git/gitconfig from template
render_gitconfig() {
  local template="$DOTFILES_DIR/git/gitconfig.template"
  local out="$DOTFILES_DIR/git/gitconfig"
  mkdir -p "$(dirname "$out")"

  if [ ! -f "$template" ]; then
    echo "Error: missing $template" >&2
    exit 1
  fi

  log "Rendering git config -> $out"
  perl -pe \
    "s/__GIT_NAME__/\Q$GIT_NAME\E/g; s/__GIT_EMAIL__/\Q$GIT_EMAIL\E/g" \
    "$template" > "$out"
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
  if [ -x "$HOME/.local/bin/lvim" ] || command -v lvim >/dev/null 2>&1; then
    log "LunarVim already installed"
    return 0
  fi

  log "Installing LunarVim (stable release 1.4 / Neovim 0.9)"
  LV_BRANCH='release-1.4/neovim-0.9' \
    bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) \
    -y --no-install-dependencies
}

main() {
  ensure_homebrew

  # 1) Brew packages
  if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    log "Installing Brewfile packages"
    brew bundle --file "$DOTFILES_DIR/Brewfile"
  else
    log "No Brewfile found at $DOTFILES_DIR/Brewfile (skipping brew bundle)"
  fi

  # 2) Adopt configs
  adopt_if_missing "$DOTFILES_DIR/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

  adopt_if_missing "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  adopt_if_missing "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
  adopt_if_missing "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"

  if [ ! -e "$DOTFILES_DIR/starship/starship.toml" ] && command -v starship >/dev/null 2>&1; then
    log "Generating starship preset into repo"
    mkdir -p "$DOTFILES_DIR/starship"
    starship preset nerd-font-symbols -o "$DOTFILES_DIR/starship/starship.toml"
  fi

  # 3) Oh My Zsh
  install_oh_my_zsh
  clone_omz_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
  clone_omz_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
  clone_omz_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

  # 4) Linking
  log "Linking zsh"
  [ -f "$DOTFILES_DIR/zsh/zshrc" ] && link "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  [ -f "$DOTFILES_DIR/zsh/zprofile" ] && link "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"

  log "Linking starship"
  [ -f "$DOTFILES_DIR/starship/starship.toml" ] && \
    link "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

  log "Linking Ghostty"
  link "$DOTFILES_DIR/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  link "$DOTFILES_DIR/ghostty/config" \
    "$HOME/.config/ghostty/config"

  install_lunarvim
  [ -f "$DOTFILES_DIR/lvim/config.lua" ] && \
    link "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"

  # 5) Optional Git
  if [ "$ENABLE_GIT" -eq 1 ]; then
    render_gitconfig
    log "Linking git"
    link "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
  fi

  log "All set. Restart Ghostty + open a new shell."
}

parse_args "$@"
main

