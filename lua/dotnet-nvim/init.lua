local M = {}
local job = require("plenary.job")
local curl = require("plenary.curl")

local function trim(s)
    return string.match(s, "^%s*(.-)%s*$")
end

M._options = {
    -- dotnet-nvim settings
    search = {
        take = 50,
    },
    auth = { }
}

local function escape_pattern(s)
    return (s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'))
end

M.setup = function(options)
    -- escape auth keys
    for key, value in pairs(options.auth) do
        options.auth[key] = nil
        key = escape_pattern(key)
        options.auth[key] = value
    end

    M._options = vim.tbl_deep_extend("force", M._options, options or {})
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

    local endpoints = {
        ["search"] = {},
        ["autocomplete"] = {}
    }

    local result = curl.get(source.uri)
    local success, parsed = pcall(vim.fn.json_decode, result.body)
    -- we only support for now v3 api's
    if not success then
        -- todo: log fail parsing
        return {}
    end

    --[[ Example Format { resources: 
    { {
      ["@id"] = "https://azuresearch-usnc.nuget.org/query",
      ["@type"] = "SearchQueryService",
      comment = "Query endpoint of NuGet Search service (primary)"
    }, {
      ["@id"] = "https://azuresearch-ussc.nuget.org/query",
      ["@type"] = "SearchQueryService",
      comment = "Query endpoint of NuGet Search service (secondary)"
    }, ... } ... }
    --]]
    for _, v in pairs(parsed.resources) do
        local target = nil
        if v["@type"] == "SearchQueryService" then
            target = endpoints["search"]
        elseif v["@type"] == "SearchAutocompleteService" then
            target = endpoints["autocomplete"]
        end

        if target ~= nil then
            table.insert(target, #target, v["@id"])
        end
    end

    return endpoints
end

local function find_auth(endpoint)
    for key, v in pairs(M._options.auth) do
        if string.match(endpoint, key) then
            return v
        end
    end

    return nil
end

M.search_package = function(search_endpoints, package_name, is_prerelease)
    is_prerelease = is_prerelease or false
    for _, v in ipairs(search_endpoints) do
        local query = v .. "?q=" .. package_name
        .. "&prerelease=" .. tostring(is_prerelease)
        .. "&take=" .. tostring(M._options.search.take)

        local options = {}
        local auth = find_auth(v)
        if auth then
            options.auth = auth.user .. ":" .. auth.password
        end

        local result = curl.get(query, options)
        if result.status == 401 then
            -- todo: log
            print("unauthorized")
        end

        if result.status == 200 then
            return vim.fn.json_decode(result.body).data
        end
    end

    print("Package not found")
    return {}
end

return M
