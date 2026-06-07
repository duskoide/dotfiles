-- Prepend mise shims to PATH so LSPs, formatters, and linters are resolved correctly
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4

