---@class UnPack.Config.UserOpts
--- Options for vim.pack.add
---@field add_options? vim.pack.keyset.add
--- Options for vim.pack.update
---@field update_options? vim.pack.keyset.update

local M = { ---@class UnPack.Config
	add_options = { confirm = false }, ---@type vim.pack.keyset.add
	config_path = vim.fn.stdpath("config"),
	data_path = vim.fn.stdpath("data"),
	packages_rpath = "/site/pack/core/opt/",
	plugins_rpath = "/lua/plugins/",
	update_options = { force = true }, ---@type vim.pack.keyset.update
}
---@param opts? UnPack.Config.UserOpts
M.setup = function(opts)
	local merged_opts = vim.tbl_deep_extend("force", M, opts or {})

	for k, v in pairs(merged_opts) do
		M[k] = v
	end
end

return M
