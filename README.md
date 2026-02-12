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

The goal:

Clone → run install.sh → identical environment.

---

## Setup

First, clone the repo:

```
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Restart your terminal after installation.

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

---

## Structure

dotfiles/
  install.sh
  Brewfile
  zsh/
  ghostty/
  starship/
  lvim/

All configs are symlinked from this repository.

Re-running install.sh is safe.

---

## Notes

Local machine-only overrides go in ~/.zsh_custom  
SSH keys are not managed here  
Fonts are installed via Homebrew

## Extras

# Ghosty Quick Terminal
The keybind (cmd + \) is already included in the ghostty config files on installation. 
However, to make this work on MacOS you need to allow additional permissions. As of writing (Feb 12, 2026), these are found in System Settings > Privacy and Security > Accessibility.
<img width="411" height="165" alt="image" src="https://github.com/user-attachments/assets/73897969-77bb-4933-8f9b-ebe00e2b5201" />

# VS Code
This is not included in the dotfiles. However, I use Vira theme (Vira Teal High Contrast)
To take advantage of nerd fonds, do:
```
brew install --cask font-hack-nerd-font
```
Then, go to the terminal settings under fonts and replace with: Hack Nerd Font, Menlo, Monaco, Courier New, monospace

