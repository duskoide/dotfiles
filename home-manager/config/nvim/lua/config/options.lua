-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true

-- Filetype plugins (e.g. python) set 4 spaces; force 2 everywhere
vim.g.python_recommended_style = 0
vim.g.rust_recommended_style = 0
