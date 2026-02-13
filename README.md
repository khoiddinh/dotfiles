# dotfiles

Welcome to my personal macOS development environment!

This repository installs and configures:

- Ghostty (Catppuccin Mocha + custom UI)
- Oh My Zsh + plugins
- Starship prompt
- pyenv
- LunarVim
- Core CLI tooling (fzf, lazygit, btop, fastfetch)
- JetBrains Mono Nerd Font
- Optional Git configuration (aliases + defaults)

---

## Setup

First, clone the repo:

```
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```
To add execute permissions to the installer, you may need to run:
```
chmod +x install.sh
```

Restart your terminal after installation.

---

## Optional: Git Setup

Git configuration is opt-in.

If you want this repo to manage your global git config (including aliases and pull defaults), run:

```
./install.sh --git --git-name "Your Name" --git-email "you@example.com"
```

This will:

- Generate `git/gitconfig` from a template
- Overwrite it on re-run (safe to fix mistakes)
- Symlink it to `~/.gitconfig`

Re-running with different name/email will update your identity.

If `--git` is not passed, your existing `~/.gitconfig` is untouched.

---

## What gets configured

### Terminal
Ghostty with:
- Catppuccin Mocha
- Nerd Font
- Blur + opacity

### Shell
- Oh My Zsh
- zsh-autosuggestions
- zsh-syntax-highlighting
- fzf-tab
- Starship prompt
- fastfetch on startup

### Editor
- Neovim
- LunarVim (release 1.4)
- ripgrep / node / python / rust

### Python
- pyenv

### Git (if enabled)

#### Defaults

- `pull.rebase = true`  
  Makes `git pull` use rebase instead of merge.  
  Keeps history linear and avoids unnecessary merge commits.

- `rebase.autoStash = true`  
  Automatically stashes uncommitted changes before rebasing and reapplies them afterward.  
  Prevents pull failures due to a dirty working directory.

- `push.default = current`  
  Pushes the current branch to its upstream counterpart only.  
  Safer than older default behaviors.

- `merge.conflictstyle = zdiff3`  
  Shows base/ours/theirs during merge conflicts.  
  Makes resolving conflicts much clearer.

- `credential.helper = osxkeychain`  
  Uses macOS keychain for storing Git credentials securely.

---

#### Aliases

##### Navigation / Status

- `git st`  
  Short for `git status -sb`  
  Shows concise branch + status information.

- `git br`  
  Short for `git branch`

- `git co`  
  Short for `git checkout`

- `git sw`  
  Short for `git switch`

---

##### Logs

- `git lg`  
  Compact visual commit graph with timestamps.  
  Good daily driver log view.

- `git lga`  
  Full repository graph across all branches.  
  Useful for understanding overall history.

- `git lgb`  
  Detailed branch-focused graph showing:
  - Commit hash
  - Branch decorations
  - Relative time
  - Author name

  Good for reviewing feature branch history before merging.

---

##### Commit Helpers

- `git amend`  
  Amends the previous commit without editing the message.  
  Useful for quick fixes.

- `git undo`  
  Equivalent to `git reset --soft HEAD~1`  
  Removes the last commit but keeps changes staged.

---

##### File Inspection

- `git changed`  
  Shows modified (unstaged) file names only.

- `git changedstaged`  
  Shows staged file names only.

---

## Structure
```
dotfiles/
  install.sh
  Brewfile
  zsh/
  ghostty/
  starship/
  lvim/
  git/
```

All configs are automatically symlinked from this repository.

Re-running install.sh is safe.

---

## Notes

Local machine-only overrides go in ~/.zsh_custom  
SSH keys are not managed here  
Fonts are installed via Homebrew  

---

# Extras

## Ghostty Quick Terminal
The keybind (cmd + \) is already included in the ghostty config files on installation.  
However, to make this work on MacOS you need to allow additional permissions. As of writing (Feb 12, 2026), these are found in:

System Settings > Privacy and Security > Accessibility

## VS Code
This is not included in the dotfiles. However, I use Vira theme (Vira Teal High Contrast).  
To take advantage of nerd fonts, do:

```
brew install --cask font-hack-nerd-font
```

Then go to the terminal settings under fonts and replace with:

Hack Nerd Font, Menlo, Monaco, Courier New, monospace
