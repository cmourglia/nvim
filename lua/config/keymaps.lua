--
vim.keymap.set('n', '<leader>pv', vim.cmd.Ex)

-- Yank to clipboard
vim.keymap.set('n', '<leader>y', '"+y')
vim.keymap.set('v', '<leader>y', '"+y')
vim.keymap.set('n', '<leader>Y', '"+Y')

-- Delete to void
vim.keymap.set('n', '<leader>d', '"_d')
vim.keymap.set('v', '<leader>d', '"_d')

-- Move selected line up and down
-- vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
-- vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- TODO: Add UndoTree plugin
-- vim.keymap.set('n', '<leader>u', ':UndotreeShow<CR>')

-- When navigating with C-d and C-u, keep the curson in the middle of the buffer
vim.keymap.set('n', '<C-d>', '<C-d>zz')
vim.keymap.set('n', '<C-u>', '<C-u>zz')

-- When navigating the search, keep the curson in the middle of the buffer
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- When pasting over some selected text, keep the yanked data
-- in the paste buffer, instead of relacing with the pasted-on data
vim.keymap.set('x', '<leader>p', '"_dP')

-- Reformat
-- vim.keymap.set('n', '<leader>f', function()
--vim.lsp.buf.format()
--end)

-- Quickfix navigation
vim.keymap.set('n', '<C-k>', '<cmd>cnext<CR>zz')
vim.keymap.set('n', '<C-j>', '<cmd>cprev<CR>zz')
vim.keymap.set('n', '<leader>k', '<cmd>lnext<CR>zz')
vim.keymap.set('n', '<leader>j', '<cmd>lprev<CR>zz')

-- Search and replace the word under the cursor
-- TODO: Find a keybind
-- vim.keymap.set('n', '<leader>s', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Escape terminal easier
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>')

vim.keymap.set('n', '<C-s>', ':w<CR>')
vim.keymap.set('i', '<C-s>', '<Esc>:w<CR>a')

-- Toggle between header and source file
vim.keymap.set('n', '<M-o>', '<cmd>ClangdSwitchSourceHeader<CR>')
vim.keymap.set('i', '<M-o>', '<ESC><cmd>ClangdSwitchSourceHeader<CR>')
