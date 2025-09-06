local M = {}

M.vim_commands_fixtures = {
	uv = {
		fs_stat = function()
			return nil
		end,
	},
	fn = {
		glob = function()
			return {}
		end,
		fnamemodify = function(fpath, modifier)
			if modifier == ":t" then
				return fpath:match("([^/]+)$")
			end
			if modifier == ":t:r" then
				return fpath:match("([^/]+)%.lua$")
			end
			return fpath
		end,
		jobstart = function() end,
	},
	notify = function() end,
	pack = { del = function() end, add = function() end, update = function() end },
	system = function()
		return {
			wait = function()
				return { code = 0, stdout = "" }
			end,
		}
	end,
	log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
	schedule = function(f)
		f()
	end,
	split = function(s)
		local t = {}
		for w in s:gmatch("%S+") do
			t[#t + 1] = w
		end
		return t
	end,
	trim = function(s)
		return (s:gsub("^%s*(.-)%s*$", "%1"))
	end,
}
M.vim_config_fixtures = {
	fn = {
		stdpath = function(kind)
			return "/tmp/" .. kind
		end,
	},
	deepcopy = function(v)
		if type(v) ~= "table" then
			return v
		end
		local t = {}
		for k, val in pairs(v) do
			t[k] = vim.deepcopy(val)
		end
		return t
	end,
	tbl_deep_extend = function(mode, base, override)
		assert(mode == "force", "only 'force' is used in these tests")
		local function merge(b, o)
			local out = {}
			for k, v in pairs(b or {}) do
				out[k] = vim.deepcopy(v)
			end
			for k, v in pairs(o or {}) do
				if type(v) == "table" and type(out[k]) == "table" then
					out[k] = merge(out[k], v)
				else
					out[k] = vim.deepcopy(v)
				end
			end
			return out
		end
		return merge(base, override)
	end,
}
M.vim_unpack_fixtures = {
	api = {
		nvim_create_augroup = function(name, opts)
			return { name = name, opts = opts }
		end,
		nvim_create_autocmd = function(event, opts)
			_G.__last_autocmd = { event = event, opts = opts }
		end,
		nvim_create_user_command = function(name, fn, opts)
			_G.__last_user_command = _G.__last_user_command or {}
			_G.__last_user_command[name] = { fn = fn, opts = opts }
		end,
	},
	tbl_contains = function(tbl, val)
		for _, v in ipairs(tbl) do
			if v == val then
				return true
			end
		end
		return false
	end,
}

return M
