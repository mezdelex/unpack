local assert = require("luarocks.busted.assert")
local commands = require("commands")

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
		uv_fs_stat_original = vim.uv.fs_stat
		fn_jobstart_original = vim.fn.jobstart
		notify_original = vim.notify
		pack_del_original = vim.pack.del
		pack_add_original = vim.pack.add
		pack_update_original = vim.pack.update
		system_original = vim.system
		fn_glob_original = vim.fn.glob
		fn_fnamemodify_original = vim.fn.fnamemodify
		schedule_original = vim.schedule
		split_original = vim.split
		trim_original = vim.trim
		is_empty_or_whitespace_original = string.is_empty_or_whitespace
		string.is_empty_or_whitespace = function(s)
			return not not s:match("^%s*$")
		end
		vim.uv.fs_stat = function() end
		vim.fn.jobstart = function() end
		vim.notify = function() end
		vim.pack.del = function() end
		vim.pack.add = function() end
		vim.pack.update = function() end
		vim.system = function() end
		vim.fn.glob = function() end
		vim.fn.fnamemodify = function() end
		vim.schedule = function(f)
			f()
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
		vim.split = function(s, sep)
			local t = {}
			for word in s:gmatch("%S+") do
				table.insert(t, word)
			end
			return t
		end
		vim.trim = function(s)
			return s:match("^%s*(.*%S?)%s*$")
		end
	end)

	after_each(function()
		vim.uv.fs_stat = uv_fs_stat_original
		vim.fn.jobstart = fn_jobstart_original
		vim.notify = notify_original
		vim.pack.del = pack_del_original
		vim.pack.add = pack_add_original
		vim.pack.update = pack_update_original
		vim.system = system_original
		vim.fn.glob = fn_glob_original
		vim.fn.fnamemodify = fn_fnamemodify_original
		vim.schedule = schedule_original
		vim.split = split_original
		vim.trim = trim_original
		string.is_empty_or_whitespace = is_empty_or_whitespace_original

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

	describe("clean", function()
		it("should delete packages that are not in specs", function()
			local pack_del_called_with = nil

			vim.fn.glob = function(pattern, ...) -- Mock vim.fn.glob
				if pattern:match("plugins/%.lua") then
					return { "/tmp/config/plugins/plugin1.lua", "/tmp/config/plugins/plugin2.lua" }
				elseif pattern:match("packages/%*/") then
					return { "/tmp/data/packages/plugin1/", "/tmp/data/packages/plugin3/" }
				end
				return {}
			end

			vim.fn.fnamemodify = function(fpath, modifier) -- Mock vim.fn.fnamemodify
				if modifier == ":t:r" then
					if fpath == "/tmp/config/plugins/plugin1.lua" then
						return "plugin1"
					elseif fpath == "/tmp/config/plugins/plugin2.lua" then
						return "plugin2"
					end
				elseif modifier == ":t" and fpath:match("packages/%a+/$") then
					return fpath:match("packages/(%a+)/$")
				elseif modifier == ":t" and fpath:match("plugin%d") then
					return fpath
				end
				return fpath
			end

			package.loaded["plugins.plugin1"] = { src = "plugin1" } -- Only src is needed for the clean command.
			package.loaded["plugins.plugin2"] = { src = "plugin2" } -- Only src is needed for the clean command.

			-- Mock unpack module
			package.loaded["unpack"] = {
				Spec = {},
				init = function() end,
			}

			vim.pack.del = function(packages)
				pack_del_called_with = packages
			end

			commands.clean()

			assert.are.same({ "plugin3" }, pack_del_called_with)

			package.loaded["plugins.plugin1"] = nil
			package.loaded["plugins.plugin2"] = nil
			package.loaded["unpack"] = nil
		end)
	end)

	describe("load", function()
		it("should add packages and execute configs", function()
			local pack_add_called_with_specs = nil
			local pack_add_called_with_options = nil
			local config_executed = false
			local defer_config_executed = false

			vim.fn.glob = function(pattern, ...) -- Mock vim.fn.glob
				if pattern:match("plugins/%.lua") then
					return { "/tmp/config/plugins/pluginA.lua", "/tmp/config/plugins/pluginB.lua" }
				end
				return {}
			end

			vim.fn.fnamemodify = function(fpath, modifier) -- Mock vim.fn.fnamemodify
				if modifier == ":t:r" then
					if fpath == "/tmp/config/plugins/pluginA.lua" then
						return "pluginA"
					elseif fpath == "/tmp/config/plugins/pluginB.lua" then
						return "pluginB"
					end
				elseif modifier == ":t" then
					return fpath -- Mock for spec.src
				end
				return fpath
			end

			package.loaded["plugins.pluginA"] = {
				src = "pluginA",
				config = function()
					config_executed = true
				end,
			}
			package.loaded["plugins.pluginB"] = {
				src = "pluginB",
				config = function()
					defer_config_executed = true
				end,
				defer = true,
			}

			vim.pack.add = function(specs, options)
				pack_add_called_with_specs = specs
				pack_add_called_with_options = options
			end

			commands.load()

			assert.are.same(2, #pack_add_called_with_specs)
			assert.are.same({}, pack_add_called_with_options)
			assert.True(config_executed)
			assert.True(defer_config_executed)

			package.loaded["plugins.pluginA"] = nil
			package.loaded["plugins.pluginB"] = nil
			package.loaded["unpack"] = nil
		end)
	end)

	describe("update", function()
		it("should call vim.pack.update with options", function()
			local pack_update_called = false
			local update_options = nil

			vim.pack.update = function(_, options)
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

			vim.uv.fs_stat = function(fpath)
				if fpath == "/tmp/data/packages/test-plugin" then
					return { type = "directory" }
				end
				return nil
			end

			vim.system = function(cmd, opts)
				system_called = true
				assert.are.same({ "make", "install" }, cmd)
				assert.are.same({ cwd = "/tmp/data/packages/test-plugin" }, opts)
				return {
					wait = function()
						return { code = 0, stdout = "Build successful" }
					end,
				}
			end

			vim.notify = function(message, level)
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

			vim.system = function()
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

			vim.system = function(cmd, opts) -- Mock vim.system
				return {
					wait = function()
						return { code = 1, stderr = "Build failed" }
					end,
				}
			end

			vim.notify = function(message, level) -- Mock vim.notify
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

			vim.fn.glob = function(pattern, ...) -- Mock vim.fn.glob
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
