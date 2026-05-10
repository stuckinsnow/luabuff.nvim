local M = {}

local cache = require("luabuff.cache")

function M.move_buffer(direction, get_sorted_buffers, custom_order, save_positions)
	local buffers = get_sorted_buffers()
	local current_buf = vim.api.nvim_get_current_buf()
	local idx
	for i, b in ipairs(buffers) do
		if b == current_buf then
			idx = i
			break
		end
	end
	if not idx then
		return
	end

	local swap_idx = idx + direction
	if swap_idx < 1 or swap_idx > #buffers then
		return
	end

	-- Ensure both buffers have explicit order values, then swap
	for i, b in ipairs(buffers) do
		if not custom_order[b] then
			custom_order[b] = i
		end
	end
	custom_order[buffers[idx]], custom_order[buffers[swap_idx]] =
		custom_order[buffers[swap_idx]], custom_order[buffers[idx]]
	save_positions()
	cache.invalidate()
	require("lualine").refresh()
end

return M
