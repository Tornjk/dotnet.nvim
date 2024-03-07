describe("dotnet-nvim", function()
    local dotnet = require("dotnet-nvim")
    it("should fetch sources", function()
        dotnet.fetch_sources()
        assert.truthy(next(dotnet._nuget_sources))
    end)

    it("should parse source nuget.org", function()
        local source = "    1. nuget.org [Enabled]"
        local uri = "     https://api.nuget.org/v3/index.json"
        local expected = {
            name = "nuget.org",
            uri = "https://api.nuget.org/v3/index.json",
            enabled = true,
            web = true
        }

        local parsed = dotnet.parse_source(source, uri)
        assert.are.same(expected, parsed)
    end)

    it("should parse source random http", function()
        local source = "    2. My Source [Enabled]"
        local uri = "     http://local.nuget.source/v3/index.json"
        local expected = {
            name = "My Source",
            uri = "http://local.nuget.source/v3/index.json",
            enabled = true,
            web = true
        }

        local parsed = dotnet.parse_source(source, uri)
        assert.are.same(expected, parsed)
    end)

    it("should parse source local filesystem path", function()
        local source = "    2. My Source [Enabled]"
        local uri = "     ~/.nuget/sources"
        local expected = {
            name = "My Source",
            uri = "~/.nuget/sources",
            enabled = true,
            web = false
        }

        local parsed = dotnet.parse_source(source, uri)
        assert.are.same(expected, parsed)
    end)

    it("should parse disabled", function()
        local source = "    2. My Source [Disabled]"
        local uri = "     ~/.nuget/sources"
        local expected = {
            name = "My Source",
            uri = "~/.nuget/sources",
            enabled = false,
            web = false
        }

        local parsed = dotnet.parse_source(source, uri)
        assert.are.same(expected, parsed)
    end)

    it("should query source", function()
        local index = "https://api.nuget.org/v3/index.json"
        dotnet.query_source({ uri = index, web = true })
    end)
end)
