local scandir = require('plenary.scandir')
local path = require('plenary.path')
local job = require('plenary.job')

local M = {}

M._sln = { }

--- @param directory string
M.open = function(directory)
    local files = scandir.scan_dir(directory,
    {
        hidden = false,
        only_dirs = false,
        search_pattern = '*.sln',
    })

    if #files == 0 then
        return
    end

    M._sln = path:new(files[1])
end

--- @param name string
--- @param type string
M.new_project = function(name, type)
    job:new({
        command = "dotnet",
        args = { "new", type, "-o", name }
    }):sync()

    job:new({
        command = "dotnet",
        args = { "sln", M._sln.filename, "add", name .. "/" .. name .. ".csproj" }
    }):sync()
end

--- @param project string
--- @param reference string
M.reference = function(project, reference)
    job:new({
        command = "dotnet",
        args = { "add", project, "reference", reference }
    }):sync()
end

--- @return string[]
M.get_projects = function()
    local result = job:new({ command = "dotnet", args = { "sln", M._sln.filename, "list" } }):sync()
    local projects = {}
    for i = 2, #result, 2 do
        table.insert(projects, result[i])
    end

    return projects
end

return M
