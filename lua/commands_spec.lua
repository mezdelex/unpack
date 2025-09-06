_G.vim = _G.vim
	or {
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
				if not fpath then
					return nil
				end
				local filename = fpath:match("([^/\\\\]+)$") or fpath
				if modifier == ":t" then
					return filename
				elseif modifier == ":r" or modifier == ":t:r" then
					return filename:match("^(.-)%.?[^.]*$") or filename
				end
				return fpath
			end,
			jobstart = function() end,
		},
		notify = function() end,
		pack = {
			del = function() end,
			add = function() end,
			update = function() end,
		},
		system = function()
			return {
				wait = function()
					return { code = 0, stdout = "" }
				end,
			}
		end,
		log = {
			levels = {
				INFO = 1,
				WARN = 2,
				ERROR = 3,
			},
		},
		schedule = function(f)
			f()
		end,
		split = function(s, sep)
			return {}
		end,
		trim = function(s)
			return s
		end,
	}

_G.string = _G.string or {}
_G.string.is_empty_or_whitespace = _G.string.is_empty_or_whitespace or function(s)
	return not not s:match("^%s*$")
end

local assert = require("luassert")
local commands = require("lua.commands")

describe("commands", function()
	local uv_fs_stat_original
	local fn_jobstart_original
	local notify_original
	local pack_del_original
	local pack_add_original
	local pack_update_original
	local system_original
	local fn_glob_original
	local fn_fnamemodify_original
	local schedule_original
	local split_original
	local trim_original
	local is_empty_or_whitespace_original

	before_each(function()
		uv_fs_stat_original = _G.vim.uv.fs_stat
		fn_jobstart_original = _G.vim.fn.jobstart
		notify_original = _G.vim.notify
		pack_del_original = _G.vim.pack.del
		pack_add_original = _G.vim.pack.add
		pack_update_original = _G.vim.pack.update
		system_original = _G.vim.system
		fn_glob_original = _G.vim.fn.glob
		fn_fnamemodify_original = _G.vim.fn.fnamemodify
		schedule_original = _G.vim.schedule
		split_original = _G.vim.split
		trim_original = _G.vim.trim
		is_empty_or_whitespace_original = _G.string.is_empty_or_whitespace
		_G.string.is_empty_or_whitespace = function(s)
			return not not s:match("^%s*$")
		end
		_G.vim.uv.fs_stat = function() end
		_G.vim.inspect = function(tbl)
			return "table: " .. tostring(tbl)
		end
		_G.vim.fn.jobstart = function() end
		_G.vim.notify = function() end

		_G.vim.pack.del = function() end
		_G.vim.pack.add = function() end
		_G.vim.pack.update = function() end
		_G.vim.system = function() end
		_G.vim.schedule = function(f)
			f()
		end
		_G.vim.fn.fnamemodify = function(fpath, modifier)
			if not fpath then
				return nil
			end
			local filename = fpath:match("([^/\\]+)$") or fpath
			if modifier == ":t" then
				return filename
			elseif modifier == ":r" or modifier == ":t:r" then
				return filename:match("^(.-)%.?[^.]*$") or filename
			end
			return fpath
		end
		package.loaded["config"] = {
			opts = {
				config_path = "/tmp/config/",
				plugins_rpath = "plugins/",
				data_path = "/tmp/data/",
				packages_rpath = "packages/",
				unpack_rpath = "unpack/",
				add_options = {},
				update_options = {},
			},
		}
		_G.vim.split = function(s, sep)
			local t = {}
			for word in s:gmatch("%S+") do
				table.insert(t, word)
			end
			return t
		end
		_G.vim.trim = function(s)
			return s:match("^%s*(.*%S?)%s*$")
		end
	end)

	after_each(function()
		_G.vim.uv.fs_stat = uv_fs_stat_original
		_G.vim.fn.jobstart = fn_jobstart_original
		_G.vim.notify = notify_original
		_G.vim.pack.del = pack_del_original
		_G.vim.pack.add = pack_add_original
		_G.vim.pack.update = pack_update_original
		_G.vim.system = system_original
		_G.vim.fn.glob = fn_glob_original
		_G.vim.fn.fnamemodify = fn_fnamemodify_original
		_G.vim.schedule = schedule_original
		_G.vim.split = split_original
		_G.vim.trim = trim_original
		_G.string.is_empty_or_whitespace = is_empty_or_whitespace_original

		package.loaded["config"] = nil
	end)

	describe("pull", function()
		it("should pull if unpack directory exists", function()
			local jobstart_called = false
			vim.uv.fs_stat = function(fpath)
				if fpath == "/tmp/data/unpack/" then
					return { type = "directory" }
				end
				return nil
			end
			vim.fn.jobstart = function(cmd, opts)
				jobstart_called = true
				assert.are.same({ "git", "pull", "--force" }, cmd)
				assert.are.same({ cwd = "/tmp/data/unpack/" }, opts)
			end

			commands.pull()

			assert.True(jobstart_called)
		end)

		it("should not pull if unpack directory does not exist", function()
			local jobstart_called = false
			vim.uv.fs_stat = function(fpath)
				return nil
			end
			vim.fn.jobstart = function(cmd, opts)
				jobstart_called = true
			end

			commands.pull()

			assert.False(jobstart_called)
		end)
	end)

	describe("update", function()
		it("should call vim.pack.update with options", function()
			local pack_update_called = false
			local update_options = nil

			_G.vim.pack.update = function(_, options)
				pack_update_called = true
				update_options = options
			end

			commands.update()

			assert.True(pack_update_called)
			assert.are.same({}, update_options)
		end)
	end)

	describe("build", function()
		it("should build specified plugins", function()
			local system_called = false
			local notify_messages = {}

			_G.vim.uv.fs_stat = function(fpath)
				if fpath == "/tmp/data/packages/test-plugin" then
					return { type = "directory" }
				end
				return nil
			end

			_G.vim.system = function(cmd, opts)
				system_called = true
				assert.are.same({ "make", "install" }, cmd)
				assert.are.same({ cwd = "/tmp/data/packages/test-plugin" }, opts)
				return {
					wait = function()
						return { code = 0, stdout = "Build successful" }
					end,
				}
			end

			_G.vim.notify = function(message, level)
				table.insert(notify_messages, { message, level })
			end

			local specs = {
				{ src = "test-plugin", data = { build = "make install" } },
			}
			commands.build(specs)

			assert.True(system_called)
			assert.are.same(2, #notify_messages)
			assert.are.same("Building test-plugin...", notify_messages[1][1])
			assert.are.same(vim.log.levels.WARN, notify_messages[1][2])
			assert.are.same("Build successful", notify_messages[2][1])
			assert.are.same(vim.log.levels.INFO, notify_messages[2][2])
		end)

		it("should not build if no build command is specified", function()
			local system_called = false

			_G.vim.system = function()
				system_called = true
			end

			local specs = {
				{ src = "test-plugin" },
			}
			commands.build(specs)

			assert.False(system_called)
		end)

		it("should handle build failure", function()
			local notify_messages = {}

			vim.uv.fs_stat = function(fpath)
				if fpath == "/tmp/data/packages/test-plugin" then
					return { type = "directory" }
				end
				return nil
			end

			_G.vim.system = function(cmd, opts)
				return {
					wait = function()
						return { code = 1, stderr = "Build failed" }
					end,
				}
			end

			_G.vim.notify = function(message, level)
				table.insert(notify_messages, { message, level })
			end

			local specs = {
				{ src = "test-plugin", data = { build = "make install" } },
			}
			commands.build(specs)

			assert.are.same(2, #notify_messages)
			assert.are.same("Build failed", notify_messages[2][1])
			assert.are.same(vim.log.levels.ERROR, notify_messages[2][2])
		end)

		it("should get specs and names if no specs are provided", function()
			local get_specs_and_names_called = false

			_G.vim.fn.glob = function(pattern, ...)
				get_specs_and_names_called = true
				if pattern:match("plugins/%.lua") then
					return {}
				end
				return {}
			end

			commands.build()

			assert.True(get_specs_and_names_called)
		end)
	end)
end)
