---@diagnostic disable: duplicate-set-field
local assert = require("luassert")
local commands = require("lua.commands")

_G.vim = require("test.fixtures").vim_commands_fixtures
_G.string.is_empty_or_whitespace = function(s)
	return not not s:match("^%s*$")
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

describe("commands", function()
	describe("build", function()
		it("runs build command", function()
			local msgs = {}
			vim.uv.fs_stat = function()
				return { type = "directory" }
			end
			vim.system = function(cmd, o)
				assert.same({ "make", "install" }, cmd)
				assert.same({ cwd = "/tmp/data/packages/test" }, o)
				return {
					wait = function()
						return { code = 0, stdout = "ok" }
					end,
				}
			end
			vim.notify = function(m, l)
				msgs[#msgs + 1] = { m, l }
			end
			commands.build({ { src = "test", data = { build = "make install" } } })
			assert.same("Building test...", msgs[1][1])
			assert.same("ok", msgs[2][1])
		end)

		it("skips if no build cmd", function()
			local called = false
			vim.system = function()
				called = true
			end
			commands.build({ { src = "test" } })
			assert.False(called)
		end)

		it("notifies error on failure", function()
			local msgs = {}
			vim.uv.fs_stat = function()
				return { type = "directory" }
			end
			vim.system = function()
				return {
					wait = function()
						return { code = 1, stderr = "fail" }
					end,
				}
			end
			vim.notify = function(m, l)
				msgs[#msgs + 1] = { m, l }
			end
			commands.build({ { src = "test", data = { build = "x" } } })
			assert.same("fail", msgs[2][1])
			assert.same(vim.log.levels.ERROR, msgs[2][2])
		end)
	end)

	describe("clean", function()
		it("removes packages not in specs", function()
			package.loaded["plugins.a"] = { src = "/tmp/data/packages/a" }
			vim.fn.glob = function(p)
				if p:match("plugins/") then
					return { "/tmp/config/plugins/a.lua" }
				else
					return { "/tmp/data/packages/a/", "/tmp/data/packages/b/" }
				end
			end
			local deleted
			vim.pack.del = function(pkgs)
				deleted = pkgs
			end
			commands.clean()
			assert.same({ "b" }, deleted)
		end)
	end)

	describe("load", function()
		it("adds and configures immediately", function()
			local cfg = false
			package.loaded["plugins.a"] = {
				src = "a",
				config = function()
					cfg = true
				end,
			}
			vim.fn.glob = function()
				return { "/tmp/config/plugins/a.lua" }
			end
			vim.fn.fnamemodify = function(_, _)
				return "a"
			end
			local added
			vim.pack.add = function(specs)
				added = specs
			end
			commands.load()
			assert.is_not_nil(added)
			assert.True(cfg)
		end)

		it("defers config when defer=true", function()
			local ran = false
			package.loaded["plugins.b"] = {
				src = "b",
				defer = true,
				config = function()
					ran = true
				end,
			}
			vim.fn.glob = function()
				return { "/tmp/config/plugins/b.lua" }
			end
			vim.fn.fnamemodify = function(_, _)
				return "b"
			end
			local scheduled
			vim.schedule = function(f)
				scheduled = f
			end
			commands.load()
			assert.is_function(scheduled)
			scheduled()
			assert.True(ran)
		end)
	end)

	describe("pull", function()
		it("pulls if unpack dir exists", function()
			local called
			vim.uv.fs_stat = function()
				return { type = "directory" }
			end
			vim.fn.jobstart = function(cmd, opts)
				called = { cmd = cmd, opts = opts }
			end
			commands.pull()
			assert.same({ "git", "pull", "--force" }, called.cmd)
			assert.same({ cwd = "/tmp/data/unpack/" }, called.opts)
		end)

		it("does nothing if unpack dir missing", function()
			local called = false
			vim.uv.fs_stat = function()
				return {}
			end
			vim.fn.jobstart = function()
				called = true
			end
			commands.pull()
			assert.False(called)
		end)
	end)

	describe("update", function()
		it("calls pack.update with options", function()
			local called, opts
			vim.pack.update = function(_, o)
				called, opts = true, o
			end
			commands.update()
			assert.True(called)
			assert.same({}, opts)
		end)
	end)
end)
