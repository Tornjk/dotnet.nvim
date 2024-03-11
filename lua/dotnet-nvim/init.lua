local nuget = require('dotnet-nvim.nuget')
local M = {}


--- @param options { nuget: {} }
M.setup = function(options)
    nuget.setup(options.nuget)
end

M.install_package = function()
    vim.ui.input({ prompt = "Package name: " }, function(package_name)
        if not package_name then
            return
        end

        local result = nuget.search_package(package_name, false)
        local packages = {}
        for _, v in pairs(result) do
            for _, p in pairs(v) do
                print(p.id)
                table.insert(packages, p.id)
            end
        end

        vim.ui.select(packages, { prompt = "Select package" }, function(package)
            nuget.install_package(package)
        end)
    end)
end

return M
