local inspect = require("inspect")
local assert = require("luarocks.busted.assert")

describe("commands", function()
	it("should be true", function()
		assert.True(true)
	end)
end)
