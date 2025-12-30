local core = require("filetree.lib")

local function define_mappings()

    vim.keymap.set("n", "q", function()
        vim.cmd("close")
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "<C-i>", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        if line:match("") then
            vim.cmd("lcd " .. target)
            if core.refresh() == -1 then
                vim.cmd("lcd ..")
            end
        elseif line:sub(1, 1) == " " then
            local wd = vim.fn.getcwd()
            vim.cmd("close")
            vim.cmd("e " .. wd .. "/" .. target)
        end
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "<C-o>", function()
        vim.cmd("lcd ..")
        core.refresh()
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "<Tab>", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        if not line:match("") and line:sub(1, 1) == " " then
            local wd = vim.fn.getcwd()
            vim.cmd("wincmd l")
            vim.cmd("e " .. wd .. "/" .. target)
            vim.cmd("wincmd h")
        end
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "d", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        local function delete(path, flag)
            local return_code
            if flag == nil then
                return_code = vim.fn.delete(path)
            else
                return_code = vim.fn.delete(path, flag)
            end

            if return_code == -1 then
                vim.api.nvim_echo({ { "Failed to delete!" } }, false, {})
            else
                vim.api.nvim_echo({ { path .. " successfully deleted!" } }, false, {})
            end
        end

        if line:sub(1, 1) == " " then
            vim.ui.input({ prompt = "Delete " .. target .. " (y/N): " }, function(input)
                if input == "y" then
                    if vim.fn.empty(vim.fn.glob(target .. "/*")) == 0 then
                        vim.ui.input({ prompt = "Directory has contents (y/N): " }, function(input2)
                            if input2 == "y" then
                                delete(target, "rf")
                                vim.api.nvim_echo({ { target .. " successfully deleted" } }, false, {})
                                core.refresh()
                            end
                        end)
                    else
                        if vim.fn.isdirectory(target) == 1 then
                            delete(target, "d")
                        else
                            delete(target)
                        end

                        core.refresh()
                    end
                end
            end)
        end
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "a", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))
        local cwd

        if line:match("") then
            cwd = vim.fn.getcwd() .. "/" .. target .. "/"
        else
            cwd = vim.fn.getcwd() .. "/"
        end

        vim.ui.input({ prompt = "Create file ", default = cwd }, function(input)

            if input == "" or input == nil then
                vim.api.nvim_echo({ { "Aborted!" } }, false, {})
                return
            end

            if input:sub(-1) == "/" then
                if vim.fn.isdirectory(input) == 0 then
                    if vim.fn.mkdir(input, "p") == 0 then
                        vim.api.nvim_echo({ { "Failed to make directory!" } }, false, {})
                    else
                        vim.api.nvim_echo({ { "Successfully created directory!" } }, false, {})
                    end
                else
                    vim.api.nvim_echo({ { "Directory/file already exists!" } }, false, {})
                end
            else
                if vim.fn.filereadable(input) == 0 then
                    if vim.fn.writefile({}, input) == -1 then
                        vim.api.nvim_echo({ { "Failed to create file!" } }, false, {})
                    else
                        vim.api.nvim_echo({ { "Successfully created file!" } }, false, {})
                    end
                else
                    vim.api.nvim_echo({ { "Directory/file already exists!" } }, false, {})
                end
            end

            core.refresh()
        end)
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "r", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        if line:sub(1, 1) == " " then
            vim.ui.input({ prompt = "Rename to: " }, function(input)

                if input == nil then
                    vim.api.nvim_echo({ { "Aborted!" } }, false, {})
                    return
                end

                if vim.fn.filereadable(input) == 0 and vim.fn.isdirectory(input) == 0 then
                    if vim.fn.rename(target, input) == 0 then
                        vim.api.nvim_echo({ { "Success!" } }, false, {})
                        core.refresh()
                    else
                        vim.api.nvim_echo({ { "Failed to rename!" } }, false, {})
                    end
                else
                    vim.api.nvim_echo({ { "That already exists!" } }, false, {})
                end
            end)
        end
    end, { buffer = core.buf.num })

    local copy = { name = "", from = "", type = "" }

    vim.keymap.set("n", "c", function()
        local line = vim.api.nvim_get_current_line()

        if line:sub(1, 1) == " " then
            ---@diagnostic disable-next-line: param-type-mismatch
            local file_name = line:sub(vim.str_byteindex(line, 4, false))
            local path = vim.fn.getcwd() .. "/" .. file_name

            copy.name = file_name
            copy.from = path
            copy.type = "copy"
            vim.api.nvim_echo({ { "Copied " .. copy.from } }, false, {})
        end
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "x", function()
        local line = vim.api.nvim_get_current_line()

        if line:sub(1, 1) == " " then
            ---@diagnostic disable-next-line: param-type-mismatch
            local file_name = line:sub(vim.str_byteindex(line, 4, false))
            local path = vim.fn.getcwd() .. "/" .. file_name

            copy.name = file_name
            copy.from = path
            copy.type = "cut"
            vim.api.nvim_echo({ { "Cut " .. copy.from } }, false, {})
        end
    end, { buffer = core.buf.num })

    vim.keymap.set("n", "p", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        local dest
        if line:match("") then
            dest = vim.fn.getcwd() .. "/" .. target .. "/" .. copy.name
        else
            dest = vim.fn.getcwd() .. "/" .. copy.name
        end

        if copy.type == "copy" then
            vim.fn.system({ "cp", "-R", copy.from, dest })
        elseif copy.type == "cut" then
            if vim.fn.rename(copy.from, dest) == 0 then
                vim.api.nvim_echo({ {"Successfully moved!" } }, false, {})
            else
                vim.api.nvim_echo({ { "Move failed!" } }, false, {})
            end
        end

        print("cp " .. copy.from .. " " .. dest)
        core.refresh()

    end, { buffer = core.buf.num })

    vim.keymap.set("n", "H", function()
        core.hidden = not core.hidden
        core.refresh()
    end, { buffer = core.buf.num, silent = true })

    vim.keymap.set("n", "I", function()
        core.ignored = not core.ignored
        core.refresh()
    end, { buffer = core.buf.num, silent = true })

    vim.keymap.set("n", "s", function()
        local line = vim.api.nvim_get_current_line()
        if line:sub(1, 1) ~= " " then
            return
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))
        local path = vim.fn.getcwd() .. "/" .. target

        local open_cmd
        if vim.fn.has("macunix") == 1 then
            open_cmd = "open"
        elseif vim.fn.has("unix") == 1 then
            open_cmd = "xdg-open"
        end

        print(open_cmd)

        vim.system({ open_cmd, path }, { detach = true })
    end, { buffer = core.buf.num, silent = true })
end

local function define_autocmds()
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function()
            if core.buf.open == true then
                local current_buf = vim.api.nvim_get_current_buf()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    if vim.api.nvim_win_get_buf(win) == core.buf.num then
                        vim.api.nvim_set_current_win(win)
                    end
                end
                core.refresh()
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
        buffer = core.buf.num,
        callback = function()
            core.buf.open = false
        end,
        desc = "Closes file tree on buf close"
    })
end

vim.api.nvim_create_user_command("Filetree", function()
    if core.buf.open == true then
        print("Tree already open")
        return
    end

    vim.cmd("highlight TreeDirectoryIcon guifg=#83a598")


    vim.cmd("split")
    vim.cmd("wincmd H")
    vim.api.nvim_win_set_width(0, 25)

    core.buf.num = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(0, core.buf.num)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

    vim.bo[core.buf.num].modifiable = false
    vim.wo.wrap = false
    vim.wo.cursorline = true
    vim.opt_local.fillchars:append({ eob = " " })

    core.buf.open = true

    core.refresh()
    define_mappings()
    define_autocmds()
end, {})

vim.keymap.set("n", "<leader>ot", ":Filetree<CR>", { noremap = true, silent = true })
