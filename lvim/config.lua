-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

lvim.plugins = {
  {
    "catppuccin/nvim",
    name = "catppuccin",
  },

}
-- Default Copy Paste keybinds
vim.keymap.set({ "n", "v" }, "<D-c>", '"+y')
vim.keymap.set({ "n", "v" }, "<D-v>", '"+p')
vim.keymap.set("i", "<D-v>", '<Esc>"+pa')

-- Undo redo
vim.keymap.set("n", "<D-z>", "u")
vim.keymap.set("n", "<D-S-z>", "<C-r>")

-- Use system clipboard
vim.opt.clipboard = "unnamedplus"

lvim.colorscheme = "catppuccin-mocha"
lvim.transparent_window = true

