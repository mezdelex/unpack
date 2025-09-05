---@class UnPack.Spec : vim.pack.Spec
---@field config? fun()
---@field defer? boolean
---@field dependencies? UnPack.Spec[]

local M = {} ---@class UnPack

---@param opts? UnPack.Config.UserOpts
function M.setup(opts)
	require("extensions")

	local commands = require("commands")
	local config = require("config")
	local group = "UnPack"

	config.setup(opts)

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

	vim.api.nvim_create_user_command("PackBuild", commands.build, { desc = "UnPack: build plugins" })
	vim.api.nvim_create_user_command("PackClean", commands.clean, { desc = "UnPack: clean unmanaged packages" })
	vim.api.nvim_create_user_command("PackUpdate", commands.update, { desc = "UnPack: update all packages" })

	M.commands = commands

	commands.load()
end

return M
