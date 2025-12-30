local M = {}

M.buf = { open = false }
M.hidden = false
M.ignored = true

function M.add_icon_data(output)
    for _, line in ipairs(output.lines) do
        if line.text:match(line.icon) then
            local start_col, end_col = line.text:find(line.icon)
            if start_col then
                line.icon = { hl = line.hl, start_col = start_col, end_col = end_col }
            end
        end
    end
end

function M.print_to_buffer(output)
    local lines = { output.header.text }
    local modified_output = {}
    for _, line in ipairs(output.lines) do

        if M.hidden then
            if line.dotfile then
                goto continue
            end
        end

        table.insert(modified_output, line)
        table.insert(lines, line.text)

        ::continue::
    end
    vim.api.nvim_buf_set_lines(M.buf.num, 0, -1, false, lines)

    for i, line in ipairs(modified_output) do

        local ns = vim.api.nvim_create_namespace("filetree-highlights")

        if line.icon ~= nil then
            vim.hl.range(
                M.buf.num, ns, line.icon.hl,
                { (i + 1) - 1, line.icon.start_col - 1 },
                { (i + 1) - 1, line.icon.start_col - 1 }
            )
        end

    end
end

function M.get_dir_content(dir)
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

        local line = {}
        line.name = name
        line.type = type
        line.path = vim.fn.getcwd() .. "/" .. name

        if line.type == "directory" then
            line.icon = ""
            line.hl = "TreeDirectoryIcon"
        else
            line.icon, line.hl = require("nvim-web-devicons").get_icon(
                name, nil, { default = true }
            )
        end

        local str = ""
        if line.type == "directory" then
            str = str .. "  " .. name
            line.path = line.path .. "/"
            line.text = str
            table.insert(directories, line)
        elseif type == "file" then
            str = str .. " " .. line.icon .. " " .. name
            line.text = str
            table.insert(files, line)
        end

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

function M.refresh()
    local output = M.get_dir_content(vim.fn.getcwd())
    if output == -1 then
        return -1
    end

    M.add_icon_data(output)

    vim.bo[M.buf.num].modifiable = true
    M.print_to_buffer(output)
    vim.bo[M.buf.num].modifiable = false
end

return M
