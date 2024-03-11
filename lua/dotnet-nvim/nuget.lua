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

--- @type { name: string, uri: string, enabled: boolean, web: boolean, endpoints: { [string]: string[] } }[]
M._nuget_sources = {}

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


--- @param source string
--- @param uri string
--- @return { name: string, uri: string, enabled: boolean, web: boolean }
--- @usage
--- M.parse_source("1. nuget.org [Enabled]", "https://api.nuget.org/v3/index.json")
M.parse_source = function(source, uri)
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


M.fetch_sources = function()
    local result = job:new({ command = "dotnet", args = { "nuget", "list", "source" } }):sync()
    local sources = {}
    for i = 2, #result, 2 do
        table.insert(sources, M.parse_source(result[i], result[i + 1]))
    end

    for _, v in pairs(sources) do
        if v.web then
            v.endpoints = M._query_source(v)
        end
    end

    M._nuget_sources = sources
end

M._query_source = function(source)
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

--- @param endpoint string
--- @return { user: string, password: string } | nil
local function find_auth(endpoint)
    for key, v in pairs(M._options.auth) do
        if string.match(endpoint, key) then
            return v
        end
    end

    return nil
end

--- @param package_name string
--- @param is_prerelease boolean
M.search_package = function(package_name, is_prerelease)
    local results = { };
    for _, v in pairs(M._nuget_sources) do
        if v.web then
            local result = M.search_package_web(v.endpoints.search, package_name, is_prerelease)
            if result.success then
                results[v.name] = result.packages
            else
                print('failed')
            end
        end
    end

    return results
end

--- @param package_name string
--- @param version string | nil
M.install_package = function(package_name, version)
    local args = { "add", "package", package_name }
    if version then
        table.insert(args, "-v")
        table.insert(args, version)
    end

    job:new({ command = "dotnet", args = args }):sync()
end

--- @param search_endpoints string[]
--- @param package_name string
--- @param is_prerelease boolean
--- @return { success: boolean, message: string, packages: { [string]: string }[] }
M.search_package_web = function(search_endpoints, package_name, is_prerelease)
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
            return {
                success = false,
                message = "authentication failed",
                packages = {}
            }
        end

        if result.status >= 200 and result.status < 300 then
            return {
                success = true,
                message = "",
                packages = vim.fn.json_decode(result.body).data
            }
        end
    end

    return {
        success = false,
        message = "couldn't receive packages",
        packages = {}
    }
end

return M
