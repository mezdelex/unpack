if not string.is_empty_or_whitespace then
	---@param self string
	---@return boolean
	string.is_empty_or_whitespace = function(self)
		return self:match("^%s*$")
	end
end
