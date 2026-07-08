-- Self-contained config for the VHS demo tape. Run from the repo root:
--   vhs demo/wind.tape
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

vim.g.mapleader = " "
vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.swapfile = false
vim.o.timeoutlen = 1500

require("wind").setup({
	breaths = { persist = false },
})
