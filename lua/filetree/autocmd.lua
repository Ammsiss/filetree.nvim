local lib = require("filetree.lib")

vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
        if lib.buf.open == true then
            local current_buf = vim.api.nvim_get_current_buf()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == lib.buf.num then
                    vim.api.nvim_set_current_win(win)
                end
            end
            lib.refresh()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == current_buf then
                    vim.api.nvim_set_current_win(win)
                end
            end
        end
    end,
    desc = "Refreshes filetee on save"
})

vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = lib.buf.num,
    callback = function()
        lib.buf.open = false
    end,
    desc = "Closes file tree on buf close"
})
