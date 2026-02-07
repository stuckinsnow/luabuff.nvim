local M = {}

local cache = require("luabuff.cache")
local pin_manager = require("luabuff.pin-manager")

function M.setup(luabuff, config, get_sorted_buffers, custom_order, save_positions)
	vim.api.nvim_create_user_command("LuaBuffMoveLeft", function() luabuff.move_buffer(-1) end, { desc = "Move buffer left" })
	vim.api.nvim_create_user_command("LuaBuffMoveRight", function() luabuff.move_buffer(1) end, { desc = "Move buffer right" })

	vim.api.nvim_create_user_command("LuaBuffSortBy", function(opts)
		local args = vim.split(opts.args, "%s+")
		config.sort_by = args[1]
		if args[2] == "asc" or args[2] == "desc" then
			config.sort_direction = args[2]
		end
		-- Clear custom order and persisted positions
		for k in pairs(custom_order) do custom_order[k] = nil end
		vim.g.LuaBuffPositions = nil
		cache.invalidate()
		require("lualine").refresh()
	end, { nargs = "+", complete = function(_, line)
		local args = vim.split(line, "%s+")
		if #args <= 2 then return { "id", "modified" } end
		return { "asc", "desc" }
	end, desc = "Set buffer sort order" })

	vim.api.nvim_create_user_command("LuaBuffSortByGitDate", function(opts)
		local desc = opts.args == "desc"
		local buffers = get_sorted_buffers()
		local timestamps = {}
		for _, buf in ipairs(buffers) do
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				local ts = vim.fn.system({ "git", "log", "--format=%at", "-1", "--", name })
				timestamps[buf] = tonumber(vim.trim(ts)) or 0
			else
				timestamps[buf] = 0
			end
		end
		table.sort(buffers, function(a, b)
			local a_pinned = pin_manager.is_pinned(a)
			local b_pinned = pin_manager.is_pinned(b)
			if a_pinned and not b_pinned then return true end
			if b_pinned and not a_pinned then return false end
			if desc then return timestamps[a] < timestamps[b] end
			return timestamps[a] > timestamps[b]
		end)
		for k in pairs(custom_order) do custom_order[k] = nil end
		for i, buf in ipairs(buffers) do
			custom_order[buf] = i
		end
		save_positions()
		cache.invalidate()
		require("lualine").refresh()
	end, { nargs = "?", complete = function() return { "asc", "desc" } end, desc = "One-time sort by git commit date" })
end

return M
