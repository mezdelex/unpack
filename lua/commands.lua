---@private
---@return UnPack.Spec[], string[]
local function get_specs_and_names()
	local config = require("config")
	local plugin_fpaths = vim.fn.glob(config.opts.config_path .. config.opts.plugins_rpath .. "*.lua", true, true) ---@type string[]
	local specs, names = {}, {} ---@type UnPack.Spec[], string[]

	for _, plugin_fpath in ipairs(plugin_fpaths) do
		local plugin_name = vim.fn.fnamemodify(plugin_fpath, ":t:r")
		local success, spec = pcall(require, "plugins." .. plugin_name) ---@type boolean, UnPack.Spec

		if not success then
			vim.notify(
				("UnPack: failed to load plugin spec '%s'. Error: %s"):format(plugin_name, spec),
				vim.log.levels.ERROR
			)
		else
			if spec.dependencies then
				for _, dep in ipairs(spec.dependencies) do
					specs[#specs + 1] = dep
					names[#names + 1] = vim.fn.fnamemodify(dep.src, ":t")
				end
			end
			specs[#specs + 1] = spec
			names[#names + 1] = vim.fn.fnamemodify(spec.src, ":t")
		end
	end

	return specs, names
end

---@private
---@return string[]
local function get_package_names()
	local config = require("config")
	local package_fpaths = vim.fn.glob(config.opts.data_path .. config.opts.packages_rpath .. "*/", false, true) ---@type string[]
	local package_names = {} ---@type string[]

	for _, package_fpath in ipairs(package_fpaths) do
		local package_name = vim.fn.fnamemodify(package_fpath:sub(1, -2), ":t")

		package_names[#package_names + 1] = package_name
	end

	return package_names
end

---@private
---@param spec UnPack.Spec
local function handle_build(spec)
	if
		not spec.data
		or not spec.data.build
		or not type(spec.data.build) == "string"
		or spec.data.build:is_empty_or_whitespace()
	then
		return
	end

	local config = require("config")
	local package_name = vim.fn.fnamemodify(spec.src, ":t")
	local package_fpath = config.opts.data_path .. config.opts.packages_rpath .. package_name ---@type string
	local stat = vim.uv.fs_stat(package_fpath)

	if not stat or not stat.type == "directory" then
		return
	end

	vim.notify(("Building %s..."):format(package_name), vim.log.levels.WARN)
	local response = vim.system(vim.split(spec.data.build, " "), { cwd = package_fpath }):wait()
	vim.notify(
		vim.trim(
			response.stderr and not response.stderr:is_empty_or_whitespace() and response.stderr
				or response.stdout and not response.stdout:is_empty_or_whitespace() and response.stdout
				or ("Exit code: %d"):format(response.code)
		),
		response.code ~= 0 and vim.log.levels.ERROR or vim.log.levels.INFO
	)
end

local M = {} ---@class UnPack.Commands

---@param specs? UnPack.Spec[]
M.build = function(specs)
	if not specs or #specs == 0 then
		specs, _ = get_specs_and_names()
	end

	for _, spec in ipairs(specs) do
		handle_build(spec)
	end
end
M.clean = function()
	local _, names = get_specs_and_names()
	local package_names = get_package_names()
	local names_set, packages_to_delete = {}, {} ---@type table<string, boolean>, string[]

	for _, name in ipairs(names) do
		names_set[name] = true
	end

	for _, package_name in ipairs(package_names) do
		if not names_set[package_name] then
			packages_to_delete[#packages_to_delete + 1] = package_name
		end
	end

	vim.pack.del(packages_to_delete)
end
M.load = function()
	local config = require("config")
	local specs, _ = get_specs_and_names()

	vim.pack.add(specs, config.opts.add_options)

	for _, spec in ipairs(specs) do
		if spec.config then
			if spec.defer then
				vim.schedule(spec.config)
			else
				spec.config()
			end
		end
	end
end
M.pull = function()
	local config = require("config")
	local unpack_fpath = config.opts.data_path .. config.opts.unpack_rpath
	local stat = vim.uv.fs_stat(unpack_fpath)

	if stat and stat.type == "directory" then
		vim.fn.jobstart({ "git", "pull", "--force" }, { cwd = unpack_fpath })
	end
end
M.update = function()
	local config = require("config")

	vim.pack.update(nil, config.opts.update_options)
end

return M
