local M = {}

M.commands_fixtures = {
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

return M
