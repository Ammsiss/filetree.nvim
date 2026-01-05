local buf = { open = false }
local hidden = false

local function add_icon_data(output)
    for _, line in ipairs(output.lines) do
        if line.icon then
            if line.text:match(line.icon) then
                local start_col, end_col = line.text:find(line.icon)
                if start_col then
                    line.icon = {
                        hl = line.hl, start_col = start_col, end_col = end_col
                    }
                end
            end
        end
    end
end

local function print_to_buffer(output)
    local lines = { output.header.text }
    local modified_output = {}
    for _, line in ipairs(output.lines) do

        if hidden then
            if line.dotfile then
                goto continue
            end
        end

        table.insert(modified_output, line)
        table.insert(lines, line.text)

        ::continue::
    end
    vim.api.nvim_buf_set_lines(buf.num, 0, -1, false, lines)

    for i, line in ipairs(modified_output) do

        local ns = vim.api.nvim_create_namespace("filetree-highlights")

        if line.icon ~= nil then
            vim.hl.range(
                buf.num, ns, line.icon.hl,
                { (i + 1) - 1, line.icon.start_col - 1 },
                { (i + 1) - 1, line.icon.start_col - 1 }
            )
        end

    end
end

local function get_dir_content(dir)
    local scandir = vim.uv.fs_scandir(dir)
    if not scandir then
        print("Unable to read directory")
        return -1
    end

    local cwd = vim.fn.getcwd()
    local user = vim.fn.getenv("USER")
    if cwd:find("/Users/" .. user) then
        cwd = cwd:gsub("^/Users/" .. user, "~")
    end

    local output = { lines = {}, header = { text = cwd } }
    local directories = {}
    local files = {}

    while true do
        local name, type = vim.uv.fs_scandir_next(scandir)
        if not name then break end

        if not type then
            local lsb = vim.uv.fs_lstat(name)
            if not lsb then
                local sb = vim.uv.fs_stat(name)
                if not sb then
                    type = "?"
                else
                    type = sb.type
                end
            else
                type = lsb.type
            end
        end

        local line = {}
        line.name = name
        line.type = type
        line.path = vim.fn.getcwd() .. "/" .. name

        if line.type == "directory" then
            line.icon = ""
            line.hl = "TreeDirectoryIcon"
        elseif line.type == "link" then
            local stat_table = vim.uv.fs_stat(line.name)

            if stat_table == nil then
                line.icon = ""
                line.hl = "TreeBrokenLinkIcon"
            elseif stat_table.type == "directory" then
                line.icon = ""
                line.hl = "TreeDirLinkIcon"
            else
                line.icon = ""
                line.hl = "TreeFileLinkIcon"
            end
        elseif line.type == "fifo" then
            line.icon = "󰈲"
            line.hl = "TreeFifoIcon"
        elseif line.type == "socket" then
            line.icon = "󰆨"
            line.hl = "TreeSocketIcon"
        elseif line.type == "char" then
            line.icon = ""
            line.hl = "TreeCharDevIcon"
        elseif line.type == "block" then
            line.icon = "󰜫"
            line.hl = "TreeBlockDevIcon"
        elseif line.type == "?" then
            line.icon = "?"
            line.hl = "TreeUnknownIcon"
        else
            line.icon, line.hl = require("nvim-web-devicons").get_icon(
                name, nil, { default = true }
            )
        end

        local str = " " .. line.icon .. " " .. name
        line.text = str
        table.insert(files, line)

        if name:sub(1, 1) == "." then
            line.dotfile = true
        end
    end

    table.sort(directories, function(a, b) return a.name < b.name end)
    table.sort(files, function(a, b) return a.name < b.name end)

    for _, line in ipairs(directories) do
        table.insert(output.lines, line)
    end

    for _, line in ipairs(files) do
        table.insert(output.lines, line)
    end

    return output
end


local function refresh()
    local output = get_dir_content(vim.fn.getcwd())
    if output == -1 then
        return -1
    end

    add_icon_data(output)

    vim.bo[buf.num].modifiable = true
    print_to_buffer(output)
    vim.bo[buf.num].modifiable = false

    vim.cmd("normal! gg")
end

local function define_mappings()

    vim.keymap.set("n", "q", function()
        vim.cmd("close")
    end, { buffer = buf.num })

    vim.keymap.set("n", "<C-i>", function()
        local line = vim.api.nvim_get_current_line()
        ---@diagnostic disable-next-line: param-type-mismatch
        local target = line:sub(vim.str_byteindex(line, 4, false))

        if line:match("") then
            local code = pcall(function()
                vim.cmd("lcd " .. target)
            end)
            if not code then
                vim.notify("Can't open that!", vim.log.levels.INFO)
                return
            end

            if refresh() == -1 then
                vim.cmd("lcd ..")
            end
        end
    end, { buffer = buf.num })

    vim.keymap.set("n", "<C-o>", function()
        vim.cmd("lcd ..")
        refresh()
    end, { buffer = buf.num })

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
    end, { buffer = buf.num })

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
                                refresh()
                            end
                        end)
                    else
                        if vim.fn.isdirectory(target) == 1 then
                            delete(target, "d")
                        else
                            delete(target)
                        end

                        refresh()
                    end
                end
            end)
        end
    end, { buffer = buf.num })

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

            refresh()
        end)
    end, { buffer = buf.num })

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
                        refresh()
                    else
                        vim.api.nvim_echo({ { "Failed to rename!" } }, false, {})
                    end
                else
                    vim.api.nvim_echo({ { "That already exists!" } }, false, {})
                end
            end)
        end
    end, { buffer = buf.num })

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
    end, { buffer = buf.num })

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
    end, { buffer = buf.num })

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
        refresh()

    end, { buffer = buf.num })

    vim.keymap.set("n", "H", function()
        hidden = not hidden
        refresh()
    end, { buffer = buf.num, silent = true })

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
    end, { buffer = buf.num, silent = true })
end

local function define_autocmds()
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function()
            if buf.open == true then
                local current_buf = vim.api.nvim_get_current_buf()
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                    if vim.api.nvim_win_get_buf(win) == buf.num then
                        vim.api.nvim_set_current_win(win)
                    end
                end
                refresh()
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
        buffer = buf.num,
        callback = function()
            buf.open = false
        end,
        desc = "Closes file tree on buf close"
    })
end

vim.api.nvim_create_user_command("Filetree", function()
    if buf.open == true then
        print("Tree already open")
        return
    end

    local gb = require("custom.color").gruvbox

    vim.api.nvim_set_hl(0, "TreeDirectoryIcon", { fg = gb.bright_blue })
    vim.api.nvim_set_hl(0, "TreeFileLinkIcon", { fg = gb.bright_aqua })
    vim.api.nvim_set_hl(0, "TreeDirLinkIcon", { fg = gb.bright_aqua })
    vim.api.nvim_set_hl(0, "TreeBrokenLinkIcon", { fg = gb.bright_red })
    vim.api.nvim_set_hl(0, "TreeFifoIcon", { fg = gb.faded_yellow })
    vim.api.nvim_set_hl(0, "TreeSocketIcon", { fg = gb.bright_purple })
    vim.api.nvim_set_hl(0, "TreeCharDevIcon", { fg = gb.bright_yellow })
    vim.api.nvim_set_hl(0, "TreeBlockDevIcon", { fg = gb.bright_yellow })
    vim.api.nvim_set_hl(0, "TreeUnknownIcon", { fg = gb.gray })

    vim.cmd("split")
    vim.cmd("wincmd H")
    vim.api.nvim_win_set_width(0, 25)

    buf.num = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(0, buf.num)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

    vim.bo[buf.num].modifiable = false
    vim.wo.wrap = false
    vim.wo.cursorline = true
    vim.opt_local.fillchars:append({ eob = " " })

    buf.open = true

    refresh()
    define_mappings()
    define_autocmds()
end, {})

vim.keymap.set("n", "<leader>ot", ":Filetree<CR>", { noremap = true, silent = true })

-- local function add_git_data(output)
--
--     local result = vim.system({ "git", "status", "--porcelain", "--ignored" }, { text = true }):wait()
--     local git_output = vim.split(result.stdout, "\n", { trimempty = true })
--     local git_root = vim.trim(vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait().stdout)
--
--     for _, git_line in ipairs(git_output) do
--
--         if git_line:match("fatal") then
--             break
--         end
--
--         local path = git_line:sub(4)
--         local node_path = git_root .. "/" .. path
--         local nodes = vim.split(path, "/")
--
--         for _, line in ipairs(output.lines) do
--
--             -- handle all files and directories at end of node list
--             for _, node in ipairs(nodes) do
--                 -- if line.path == node_path then
--                 --     print("line " .. line.path)
--                 --     print("node " .. node_path)
--                 -- end
--                 if line.path == node_path then
--                     if git_line:match("^ M ") then
--                         line.git_status = "TreeGitModified"
--                     elseif git_line:match("^!! ") then
--                         line.git_status = "TreeGitIgnored"
--                     elseif git_line:match("^%?%? ") then
--                         line.git_status = "TreeGitUntracked"
--                     elseif git_line:match("^A  ") then
--                         line.git_status = "TreeGitAdded"
--                     end
--                 -- handle directories not at end of node list
--                 elseif line.type == "directory" and line.name == node then
--                     if git_line:match("^ M ") then
--                         line.git_status = "TreeGitModified"
--                     end
--                 end
--             end
--         end
--     end
-- end

-- if line.git_status ~= nil then
--     vim.hl.range(
--         buf.num, ns, line.git_status,
--         ---@diagnostic disable-next-line: param-type-mismatch
--         { (i + 1) - 1, vim.str_byteindex(line.text, 3, false) },
--         { (i + 1) - 1, -1 }
--     )
-- end
--
-- if ignored then
--     if line.git_status ~= nil then
--         if line.git_status == "TreeGitIgnored" then
--             goto continue
--         end
--     end
-- end
--
--
-- vim.cmd("highlight TreeGitModified guifg=#fabd2f")
-- vim.cmd("highlight TreeGitUntracked guifg=#fb4934")
-- vim.cmd("highlight TreeGitAdded guifg=#b8bb26")
-- vim.cmd("highlight TreeGitIgnored guifg=#5c6370")
--
--
-- vim.keymap.set("n", "I", function()
--     ignored = not ignored
--     refresh()
-- end, { buffer = buf.num, silent = true })
