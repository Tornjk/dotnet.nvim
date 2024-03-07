local M = {}
local job = require("plenary.job")
local curl = require("plenary.curl")

local function trim(s)
    return string.match(s, "^%s*(.-)%s*$")
end

M.parse_source = function(source, uri)
--[[
example:
    source: 1. nuget.org [Enabled]
    uri: https://api.nuget.org/v3/index.json
--]]
    local s = {}
    local prefix = string.match(source, "%s+%d+%.%s")
    source = string.sub(source, #prefix + 1)
    --
    -- match the name and remove trailing whitespaces
    s.name = trim(string.match(source, "[%s%a%.]+"))
    s.enabled = string.match(source, "%[Enabled%]") ~= nil
    s.uri = trim(uri)
    s.web = string.match(uri, "[http?s]://") ~= nil
    return s
end

M._nuget_sources = {}

M.fetch_sources = function()
    local result = job:new({ command = "dotnet", args = { "nuget", "list", "source" } }):sync()
    local sources = {}
    for i = 2, #result, 2 do
        table.insert(sources, M.parse_source(result[i], result[i + 1]))
    end

    M._nuget_sources = sources
end

M.query_source = function(source)
    if not source.web then
        return {}
    end

    local result = curl.get(source.uri)
    P(vim.fn.json_decode(result.body))
    return {}
end

return M
