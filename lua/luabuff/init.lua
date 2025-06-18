-- lua/luabuff/init.lua
local M = {}

local cache = require("luabuff.cache")
local buffer_renderer = require("luabuff.buffer-renderer")
local buffer_state = require("luabuff.buffer-state")
local pin_manager = require("luabuff.pin-manager")
local highlights = require("luabuff.highlights")

-- Default configuration
local config = {
	max_visible_buffers = 6,
	active_separators = "",
	inactive_separators = "╲",
	pinned_key = "LuaBuffPinnedBuffers",
	pin_icon = "📌",
	modified_icon = "●",
	updatetime = 1000,
}

-- Initialize buffer movement module
local buffer_movement = require("luabuff.buffer-movement")

-- Setup function
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Setup cache events
	cache.setup_events(config)

	-- Setup pin manager
	pin_manager.setup(config)

	-- Set updatetime
	if vim.o.updatetime > config.updatetime then
		vim.o.updatetime = config.updatetime
	end
end

-- Create buffer position mapping
local function create_buffer_position_map(buffers)
	local position_map = {}
	for i, bufnr in ipairs(buffers) do
		position_map[i] = bufnr
	end
	return position_map
end

-- Setup buffer renderer with dependencies
buffer_renderer.setup({
	config = config,
	get_buffer_state = buffer_state.get_buffer_state,
	get_buffer_diagnostics = buffer_state.get_buffer_diagnostics,
	get_git_status = buffer_state.get_git_status,
	get_bg_color = highlights.get_bg_color,
	create_separator_highlight = highlights.create_separator_highlight,
	get_buffer_highlight = highlights.get_buffer_highlight,
	is_pinned = pin_manager.is_pinned,
})

-- Get sorted buffers helper
local function get_sorted_buffers()
	local buffers = vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf)
	end, vim.api.nvim_list_bufs())

	table.sort(buffers, function(a, b)
		local a_pinned = pin_manager.is_pinned(a)
		local b_pinned = pin_manager.is_pinned(b)

		if a_pinned and not b_pinned then
			return true
		end
		if b_pinned and not a_pinned then
			return false
		end

		return a < b
	end)

	return buffers
end

-- Main function to get custom buffers
function M.custom_buffers()
	local buffers = get_sorted_buffers()
	local buffer_position_map = create_buffer_position_map(buffers)
	return buffer_renderer.render_buffers(buffers, buffer_position_map, buffer_movement)
end

-- Export functions
function M.get_buffers()
	return M.custom_buffers()
end

function M.get_sorted_buffers()
	return get_sorted_buffers()
end

function M.goto_previous_buffer()
	return buffer_movement.goto_previous_buffer()
end

function M.goto_next_buffer()
	return buffer_movement.goto_next_buffer()
end

function M.switch_to_buffer_by_position(position)
	return buffer_movement.switch_to_buffer_by_position(position)
end

function M.get_buffer_by_position(position)
	return buffer_movement.get_buffer_by_position(position)
end

function M.switch_to_buffer(bufnr)
	return buffer_movement.switch_to_buffer(bufnr)
end

function M.toggle_pin_current()
	pin_manager.toggle_pin_current()
end

-- Setup keymaps
require("luabuff.keymaps").setup(M)

return M
