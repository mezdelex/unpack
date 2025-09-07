<p align="center"><img src="https://github.com/user-attachments/assets/0eb27f2b-835e-4b22-b25c-80a60f99a82e" width="200" height="200"></p>
<p align="center">A minimal layer on top of <code>vim.pack</code> API to allow single file plugin configurations.</p>
<br>

> [!IMPORTANT]
>
> `vim.pack` is currently under development in the `neovim-nightly` branch.

## Installation

Add these lines to your init.lua:

```lua
local unpack_path = vim.fn.stdpath("data") .. "/site/pack/managers/start/unpack"

if not vim.uv.fs_stat(unpack_path) then
    vim.fn.system({
        'git',
        'clone',
        "--filter=blob:none",
        'https://github.com/mezdelex/unpack',
        unpack_path
    })
end
```

## Setup

Available options:

```lua
---@class UnPack.Config.UserOpts
--- Options for vim.pack.add
---@field add_options? vim.pack.keyset.add
--- Options for vim.pack.update
---@field update_options? vim.pack.keyset.update
```

Call setup right after the installation with your preferred options if you don't like the defaults.

> [!TIP]
>
> Make sure you set `vim.g.mapleader` beforehand.

```lua
require("unpack").setup({
    ...
})
```

Defaults are set with minimal interaction in mind. If you want to be notified about all the changes, set `confirm` to true and `force` to false.
See `:h vim.pack`

## Spec

This layer extends `vim.pack.Spec` to allow single file configurations.

```lua
---@class UnPack.Spec : vim.pack.Spec
---@field config? fun()
---@field defer? boolean
---@field dependencies? UnPack.Spec[]
```

It also leverages `PackChanged` event triggered by `vim.pack` internals to run plugin build hooks. The same `command` that is fired inside the event is provided as a standalone one. See `Commands` section.

Example plugin spec setups under `/lua/plugins/`:

```lua
return {
	config = function()
		...
	end,
	data = { build = "your build --command" },
	defer = true,
	src = "https://github.com/<vendor>/plugin1",
}
```

```lua
return {
	config = function()
		...
	end,
	defer = true,
	dependencies = {
		{
			defer = true,
			src = "https://github.com/<vendor>/plugin2",
		},
	},
	src = "https://github.com/<vendor>/plugin3",
}
```

### Build

UnPack expects a `build` field inside `data` table for the build hook, so make sure you add it like shown in the first example. This is because `vim.pack` handles the event trigger internally and exposes `vim.pack.Spec`, not the extended one, so we need to rely on that table.
The build hook is planned to be part of and handled by the plugin itself, that's why there's no build hook exposed on purpose, but for now this is the workaround.

For reference, this is the `autocmd` that listens to the event triggered by `vim.pack` internals whenever there's a change in any package.

> [!NOTE]
>
> This is already set, you don't need to worry about it.

```lua
vim.api.nvim_create_augroup(group, { clear = true })

vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(args)
        local kind = args.data.kind ---@type string

        if kind == "install" or kind == "update" then
            local spec = args.data.spec ---@type UnPack.Spec

            commands.build({ spec })
        end
    end,
    group = group,
})
```

### Defer

Every spec marked with `defer = true` is going to be deferred using `vim.schedule` to avoid UI render delay. Dependencies follow the same rules.

### Dependencies

The dependencies handling logic is pretty simple: the plugins are going to be loaded in order, so make sure to add the dependencies in order too.
For example, if any of your plugins relies on `plenary` as a dependency, add it in the first plugin that requires it following your `plugins` directory name order, and that's pretty much it.

## Commands

The commands provided are:

**PackBuild**: iterates over all the plugin specs and runs all the build hooks. _(This command is triggered automatically on `PackChanged` event per changed package as well)_

**PackClean**: it removes any plugin present in your packages directory that doesn't exist as a plugin spec.

**PackLoad**: it loads all the plugins in your `plugins` directory. _(This command is executed when you enter Neovim; exposed just in case any of your builds times out and you need to reload)_

**PackPull**: updates UnPack to the latest version. _(This command also runs when you enter Neovim; calls `vim.system` asynchronously to pull for changes)_

**PackUpdate**: it updates all the plugins present in your packages directory (already loaded).

You can also use them this way if you prefer:

```lua
    local commands = require("unpack.commands")

    vim.keymap.set("n", "<your-keymap>", commands.build)
    vim.keymap.set("n", "<your-keymap>", commands.clean)
    vim.keymap.set("n", "<your-keymap>", commands.load)
    vim.keymap.set("n", "<your-keymap>", commands.pull)
    vim.keymap.set("n", "<your-keymap>", commands.update)
```

## Roadmap

- [x] Single config file
- [x] Defer behavior
- [x] Simple dependency handling
- [x] Commands
- [x] UnPack auto update
- [x] Tests
  - [x] commands
  - [x] config
  - [x] extensions
  - [x] unpack
- [x] Better error handling
- [x] Performance improvements
- [ ] Automated doc generation (panvimdoc)
