local lib = require("filetree.lib")

vim.api.nvim_create_user_command("Filetree", function()
    if lib.buf.open == true then
        print("Tree already open")
        return
    end

    vim.cmd("highlight TreeDirectoryIcon guifg=#83a598")

    vim.cmd("split")
    vim.cmd("wincmd H")
    vim.api.nvim_win_set_width(0, 25)

    lib.buf.num = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, lib.buf.num)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

    vim.bo[lib.buf.num].modifiable = false
    vim.wo.wrap = false
    vim.wo.cursorline = true
    vim.opt_local.fillchars:append({ eob = " " })

    lib.buf.open = true

    lib.refresh()
    require("filetree.keymaps") -- x buf keymaps
    require("filetree.autocmd") -- x buf cmds
end, {})

vim.keymap.set("n", "<leader>ot", ":Filetree<CR>",
    { noremap = true, silent = true })
