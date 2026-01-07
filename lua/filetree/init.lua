local buf = { open = false }
local show_dots = false
local current_data
local augroup_name = "Filetree.nvim"

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
        table.insert(modified_output, line)
        table.insert(lines, line.text)
    end
    vim.api.nvim_buf_set_lines(buf.num, 0, -1, false, lines)

    for i, line in ipairs(modified_output) do

        local ns = vim.api.nvim_create_namespace("")

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
    elseif cwd:find("/home/" .. user) then
        cwd = cwd:gsub("^/home/" .. user, "~")
    end

    local output = { lines = {}, header = { text = cwd } }
    local files = {}

    while true do
        local name, type = vim.uv.fs_scandir_next(scandir)
        if not name then break end

        if not show_dots and name:sub(1, 1) == "." then
            goto continue
        end

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
                line.type = "filelink"
            elseif stat_table.type == "directory" then
                line.icon = ""
                line.hl = "TreeDirLinkIcon"
                line.type = "dirlink"
            else
                line.icon = ""
                line.hl = "TreeFileLinkIcon"
                line.type = "filelink"
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

        ::continue::
    end

    table.sort(files, function(a, b) return a.name < b.name end)

    for _, line in ipairs(files) do
        table.insert(output.lines, line)
    end

    return output
end


local function refresh()
    current_data = get_dir_content(vim.fn.getcwd())
    if current_data == -1 then
        return -1
    end

    add_icon_data(current_data)

    vim.bo[buf.num].modifiable = true
    print_to_buffer(current_data)
    vim.bo[buf.num].modifiable = false
end

local function define_mappings()
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(0, false)
    end, { buffer = buf.num })

    vim.keymap.set("n", "<C-i>", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end
        local line = current_data.lines[row]

        if line.type == "directory" or line.type == "dirlink" then
            local code = pcall(function()
                vim.cmd("lcd " .. line.name)
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
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end
        local line = current_data.lines[row]

        if line.type == "file" or line.type == "filelink" then
            local wd = vim.fn.getcwd()
            vim.cmd("wincmd l")
            vim.cmd("e " .. wd .. "/" .. line.name)
            vim.cmd("wincmd h")
        end
    end, { buffer = buf.num })

    vim.keymap.set("n", "d", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end
        local line = current_data.lines[row]

        local function delete(flag)
            if vim.fn.delete(line.name, flag) == -1 then
                vim.notify("Failed to delete!", vim.log.levels.WARN)
            else
                vim.notify("Deleted successfully!", vim.log.levels.INFO)
                refresh()
            end
        end

        vim.ui.input({ prompt = "Delete " .. line.name .. " [y/N]: " }, function(input)
            if input == "y" then
                if line.type == "directory" then
                    if vim.fn.delete(line.name, "d") == -1 then
                        vim.ui.input(
                            { prompt = "Are you sure? (directory has contents) [y/N]: " },
                            function(input2)
                                if input2 == "y" then
                                    delete("rf")
                                else
                                    vim.notify("Aborting!", vim.log.levels.INFO)
                                end
                            end
                        )
                    else
                        vim.notify("Deleted successfully!", vim.log.levels.INFO)
                        refresh()
                    end
                else
                    delete("")
                end
            else
                vim.notify("Aborting!", vim.log.levels.INFO)
            end
        end)
    end, { buffer = buf.num })

    vim.keymap.set("n", "a", function()
        local line = {}
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row ~= 0 then
            line = current_data.lines[row]
        else
            line.type = "file" -- if header
        end

        local path_prefix

        if line.type == "directory" then
            path_prefix = vim.fn.getcwd() .. "/" .. line.name .. "/"
        else
            path_prefix = vim.fn.getcwd() .. "/"
        end

        vim.ui.input({ prompt = "Create file ", default = path_prefix }, function(input)
            if input == "" or input == nil then
                vim.notify("Aborted!", vim.log.levels.INFO)
                return
            end

            if vim.fn.isdirectory(input) ~= 0 or vim.fn.filereadable(input) ~= 0 then
                vim.notify("Path is taken!", vim.log.levels.INFO)
                return
            end

            if input:sub(-1) == "/" then
                if vim.fn.mkdir(input, "p") ~= 0 then
                    vim.notify("Successfully created directory!", vim.log.levels.INFO)
                else
                    vim.notify("Failed to create directory!", vim.log.levels.WARN)
                end
            else
                local success = pcall(function()
                    vim.fn.writefile({}, input)
                end)

                if success then
                    vim.notify("Created file!", vim.log.levels.INFO)
                else
                    vim.notify("Failed to create file!", vim.log.levels.WARN)
                end
            end
            refresh()
        end)
    end, { buffer = buf.num })

    vim.keymap.set("n", "r", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end
        local line = current_data.lines[row]

        vim.ui.input({ prompt = "Rename to: " }, function(input)
            if input == "" or input == nil then
                vim.notify("Aborted!", vim.log.levels.INFO)
                return
            end

            if vim.fn.isdirectory(input) ~= 0 or vim.fn.filereadable(input) ~= 0 then
                vim.notify("Path is taken!", vim.log.levels.INFO)
                return
            end

            vim.system({ "mv", "-n", line.name, input }, {}):wait()
            refresh()
        end)
    end, { buffer = buf.num })

    local copy = { name = "", from = "", type = "" }

    vim.keymap.set("n", "c", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end

        local line = current_data.lines[row]
        local path = vim.fn.getcwd() .. "/" .. line.name

        copy.name = line.name
        copy.from = path
        copy.type = "copy"

        vim.notify("Copied " .. copy.from, vim.log.levels.INFO)
    end, { buffer = buf.num })

    vim.keymap.set("n", "x", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end

        local line = current_data.lines[row]
        local path = vim.fn.getcwd() .. "/" .. line.name

        copy.name = line.name
        copy.from = path
        copy.type = "cut"

        vim.notify("Cut " .. copy.from, vim.log.levels.INFO)
    end, { buffer = buf.num })

    vim.keymap.set("n", "p", function()
        local dest = vim.fn.getcwd() .. "/" .. copy.name

        if vim.fn.isdirectory(dest) ~= 0 or vim.fn.filereadable(dest) ~= 0 then
            vim.notify("Path is taken!", vim.log.levels.INFO)
            return
        end

        if copy.type == "copy" then
            vim.system({ "cp", "-Rn", copy.from, dest }, {}):wait()
        elseif copy.type == "cut" then
            vim.system({ "mv", "-n", copy.from, dest }, {}):wait()
        end

        refresh()
    end, { buffer = buf.num })

    vim.keymap.set("n", "H", function()
        show_dots = not show_dots
        refresh()
    end, { buffer = buf.num, silent = true })

    vim.keymap.set("n", "s", function()
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        if row == 0 then
            return
        end

        local line = current_data.lines[row]
        local path = vim.fn.getcwd() .. "/" .. line.name

        local open_cmd
        if vim.fn.has("macunix") == 1 then
            open_cmd = "open"
        elseif vim.fn.has("unix") == 1 then
            open_cmd = "xdg-open"
        end

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
        desc = "Refreshes filetree on save",
        group = augroup_name
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        callback = function()
            vim.api.nvim_del_augroup_by_name(augroup_name)
            buf.open = false
        end,
        buffer = buf.num,
        desc = "Closes file tree on buf close",
        group = augroup_name
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

    buf.num = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf.num)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })

    vim.bo[buf.num].modifiable = false
    vim.wo.wrap = false
    vim.wo.cursorline = true
    vim.opt_local.fillchars:append({ eob = " " })

    buf.open = true

    refresh()
    define_mappings()

    vim.api.nvim_create_augroup(augroup_name, { clear = true })
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
