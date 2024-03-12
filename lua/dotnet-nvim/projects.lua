local scandir = require('plenary.scandir')
local path = require('plenary.path')
local job = require('plenary.job')

local M = {}

M.default_choose_solution = function(solutions)
    return solutions[1]
end

--- @param options { find_working_directory: function, choose_solution: function }
M.setup = function(options)
    M._options = vim.tbl_deep_extend("force", M._options, options or {})
end

M._options = {
    -- todo: implement default find working directory
    -- probably best to use editor start location as default
    find_working_directory = vim.fn.getcwd,
    choose_solution = M.default_choose_solution
}

--- @type { directory: string, solution: string | nil }
M.working_directory = { }

M.load = function()
    local directory = M._options.find_working_directory()
    if not directory then
        return
    end

    local files = scandir.scan_dir(directory,
    {
        depth = 1,
        hidden = false,
        only_dirs = false,
        search_pattern = '%.sln$',
    })

    if #files == 0 then
        M.working_directory = { directory = directory, solution = nil }
        return
    end

    local solutions = { }
    for _, file in ipairs(files) do
        table.insert(solutions, path:new(file).filename)
    end

    local solution = M._options.choose_solution(solutions)
    if not solution then
        solution = M.default_choose_solution(solutions)
    end

    M.working_directory = { directory = directory, solution = solution }
end

--- @param name string
--- @param type string
M.new_project = function(name, type)
    job:new({
        command = "dotnet",
        cwd = M.working_directory.directory,
        args = { "new", type, "-o", name }
    }):sync()

    if M.working_directory.solution then
        job:new({
            command = "dotnet",
            cwd = M.working_directory.directory,
            args = { "sln", M.working_directory.solution, "add", name .. "/" .. name .. ".csproj" }
        }):sync()
    end
end

--- @param project string
--- @param reference string
M.reference = function(project, reference)
    job:new({
        command = "dotnet",
        cwd = M.working_directory.directory,
        args = { "add", project, "reference", reference }
    }):sync()
end

--- @return string[]
M._get_projects_from_solution = function()
    local result = job:new({ command = "dotnet",
        cwd = M.working_directory.directory,
        args = { "sln", M.working_directory.solution, "list" } }):sync()

    local projects = {}
    for i = 3, #result, 1 do
        table.insert(projects, result[i])
    end

    return projects
end

--- @return string[]
M.get_projects = function()
    if M.working_directory.solution then
        return M._get_projects_from_solution()
    end

    local files = scandir.scan_dir(M.working_directory.directory,
        {
            hidden = false,
            depth = 2,
            only_dirs = false,
            search_pattern = '%.csproj$'
        })

    local projects = {}
    for _, file in ipairs(files) do
        table.insert(projects, path:new(file).filename)
    end

    return projects
end

return M
