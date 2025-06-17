return {
	name = "luabuff",
	dir = vim.fn.stdpath("config") .. "/lua/luabuff",
	lazy = false,
	priority = 1000,
	config = function()
		local luabuff = require("luabuff")
		luabuff.setup({
			max_visible_buffers = 6,
			active_separators = "",
			inactive_separators = "╲",
			pinned_key = "LuaBuffPinnedBuffers",
			pin_icon = "📌",
			modified_icon = "●",
			updatetime = 1000,
		})
	end,
}
