dotnet.nvim
========================================

Neovim plugin for developing with dotnet.
Currently nothing more than some basic methods to parse nuget v3 endpoints.

Plan is to create a plugin that can help with development with dotnet and provide some
functionality similar to VS / VSCode or Rider.
First goal is to make it as easy as possible to use nuget packages.

Dependencies
------------
- dotnet cli in path
- plenary.nvim

Installation
------------

Example with lazy.nvim
```lua
{ 'tornjk/dotnet.nvim', init = function() require('dotnet-nvim').setup() end }
```

```lua
options = {
    nuget {
        -- options for v3 search endpoint
        search = {
            -- amount of results to query
            take = 50
        },
        -- basic authentication credentials for nuget apis
        auth = { 
            ['https://my-nuget.server'] = { user = 'user', password = 'password' }
        }
    }
}
```


Roadmap
-------
- Query available nuget packages with search term
- Show window with available nuget packages and their respective versions
- Match package with installed package in csproj
- Make it possible to upgrade / downgrade package in csproj
- Upgrade all packages in csproj

Ideas
-----
- Create UI for dotnet templates (e.g. create new project, add Directory.Build.props or .gitignore)
- Provide shortcuts for dotnet build / dotnet run together with launchprofiles similar to VSCode
- Helper methods for MSBuild (Resolve OutDir / ArtifactsPath etc)
- Attach nuget capability autocomplete to nvim-cmp
- Parse authentication from top level nuget.config
