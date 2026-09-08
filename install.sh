#!/usr/bin/env bash
set -euo pipefail

# Absolute path to this repo
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Git setup flags (optional)
ENABLE_GIT=0
GIT_NAME=""
GIT_EMAIL=""

# GPG commit signing (optional; enabled by passing --gpg-key)
GPG_KEY=""

log() { printf "\n==> %s\n" "$1"; }

usage() {
  cat <<'EOF'
Usage: ./install.sh [--git --git-name "Name" --git-email "email@example.com"] [--gpg-key KEYID]

Options:
  --git                 Enable git setup (rewrites git/gitconfig, links ~/.gitconfig)
  --git-name "NAME"     Git user.name (required with --git)
  --git-email "EMAIL"   Git user.email (required with --git)
  --gpg-key "KEYID"     Enable GPG commit signing with this key (requires --git).
                        List your keys: gpg --list-secret-keys --keyid-format=long
  -h, --help            Show help
EOF
}

# Parse CLI flags.
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --git) ENABLE_GIT=1; shift ;;
      --git-name) GIT_NAME="${2:-}"; shift 2 ;;
      --git-email) GIT_EMAIL="${2:-}"; shift 2 ;;
      --gpg-key) GPG_KEY="${2:-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
  done

  # If git enabled, require identity.
  if [ "$ENABLE_GIT" -eq 1 ] && { [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; }; then
    echo "Error: --git requires --git-name and --git-email" >&2
    exit 2
  fi

  # Signing config is written into the generated gitconfig.
  if [ -n "$GPG_KEY" ] && [ "$ENABLE_GIT" -eq 0 ]; then
    echo "Error: --gpg-key requires --git (signing is written into the generated git config)" >&2
    exit 2
  fi
}

# Backup existing file if it isn't already the correct symlink.
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

# Create symlink src -> dst.
# Safe to rerun. Skips if already correct.
link() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    local cur
    cur="$(readlink "$dst" || true)"
    if [ "$cur" = "$src" ]; then
      log "Already linked $dst"
      return 0
    fi
  fi

  backup_if_needed "$dst" "$src"
  ln -s "$src" "$dst"
  log "Linked $dst -> $src"
}

# If repo file missing but system file exists, copy it into repo.
# Used for first-time migration.
adopt_if_missing() {
  local repo_file="$1"
  local system_file="$2"
  mkdir -p "$(dirname "$repo_file")"

  if [ ! -e "$repo_file" ] && [ -f "$system_file" ] && [ ! -L "$system_file" ]; then
    log "Adopting existing config: $system_file"
    cp "$system_file" "$repo_file"
  fi
}

# Generate git/gitconfig from template.
# Always overwrites. Validates before linking.
render_gitconfig() {
  local template="$DOTFILES_DIR/git/gitconfig.template"
  local out="$DOTFILES_DIR/git/gitconfig"
  mkdir -p "$(dirname "$out")"

  if [ ! -f "$template" ]; then
    echo "Missing template: $template" >&2
    exit 1
  fi

  log "Rendering git config"
  GIT_NAME="$GIT_NAME" GIT_EMAIL="$GIT_EMAIL" \
    perl -pe 's/__GIT_NAME__/$ENV{GIT_NAME}/g; s/__GIT_EMAIL__/$ENV{GIT_EMAIL}/g' \
    "$template" > "$out"

  # Validate before touching ~/.gitconfig
  if ! git config --file "$out" --list >/dev/null 2>&1; then
    echo "Generated git config is invalid." >&2
    exit 1
  fi
}

# Install gpg + a macOS pinentry, and point gpg-agent at it.
# Also fixes the classic "Inappropriate ioctl for device" signing failure,
# which happens when gpg has no terminal to show its passphrase prompt on.
setup_gpg() {
  log "Setting up GPG"

  command -v gpg >/dev/null 2>&1 || brew install gnupg
  [ -x "$(brew --prefix)/bin/pinentry-mac" ] || brew install pinentry-mac

  mkdir -p "$HOME/.gnupg"
  chmod 700 "$HOME/.gnupg"

  local agent_conf="$HOME/.gnupg/gpg-agent.conf"
  local pinentry="$(brew --prefix)/bin/pinentry-mac"

  touch "$agent_conf"
  if grep -q "^pinentry-program" "$agent_conf"; then
    perl -pi -e "s|^pinentry-program.*|pinentry-program $pinentry|" "$agent_conf"
  else
    printf "pinentry-program %s\n" "$pinentry" >> "$agent_conf"
  fi
  chmod 600 "$agent_conf"

  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
}

# Verify the requested signing key actually exists in the keyring.
verify_gpg_key() {
  if gpg --list-secret-keys "$GPG_KEY" >/dev/null 2>&1; then
    return 0
  fi

  cat >&2 <<EOF

No secret key matching "$GPG_KEY" found in your keyring.

List your keys with:

  gpg --list-secret-keys --keyid-format=long

Or create one with:

  gpg --full-generate-key

EOF
  exit 1
}

# Append signing settings to the generated gitconfig.
append_gpg_gitconfig() {
  local out="$DOTFILES_DIR/git/gitconfig"

  log "Enabling commit signing with key $GPG_KEY"
  cat >> "$out" <<EOF

[user]
  signingkey = $GPG_KEY

[commit]
  gpgsign = true

[tag]
  gpgsign = true

[gpg]
  program = $(command -v gpg)
EOF

  if ! git config --file "$out" --list >/dev/null 2>&1; then
    echo "Generated git config is invalid after adding GPG settings." >&2
    exit 1
  fi
}

# Ensure Homebrew exists and is on PATH.
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
  if command -v lvim >/dev/null 2>&1; then
    log "LunarVim already installed"
    return 0
  fi

  log "Installing LunarVim"
  LV_BRANCH='release-1.4/neovim-0.9' \
    bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.4/neovim-0.9/utils/installer/install.sh) \
    -y --no-install-dependencies
}

main() {
  ensure_homebrew

  # Install Brew packages (idempotent)
  if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    log "Installing Brewfile packages"
    brew bundle --file "$DOTFILES_DIR/Brewfile"
  fi

  # First-time adoption of configs into repo
  adopt_if_missing "$DOTFILES_DIR/ghostty/config" \
    "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

  adopt_if_missing "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
  adopt_if_missing "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
  adopt_if_missing "$DOTFILES_DIR/lvim/config.lua" "$HOME/.config/lvim/config.lua"

  # Generate starship config if missing
  if [ ! -e "$DOTFILES_DIR/starship/starship.toml" ] && command -v starship >/dev/null 2>&1; then
    log "Generating starship preset"
    mkdir -p "$DOTFILES_DIR/starship"
    starship preset nerd-font-symbols -o "$DOTFILES_DIR/starship/starship.toml"
  fi

  install_oh_my_zsh
  clone_omz_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
  clone_omz_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
  clone_omz_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

  # Link configs
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

  # Optional Git setup
  if [ "$ENABLE_GIT" -eq 1 ]; then
    render_gitconfig

    # Optional GPG commit signing (appends to the freshly rendered config)
    if [ -n "$GPG_KEY" ]; then
      setup_gpg
      verify_gpg_key
      append_gpg_gitconfig
    fi

    log "Linking git"
    link "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
  fi

  log "Done. Restart your terminal."
}

parse_args "$@"
main

