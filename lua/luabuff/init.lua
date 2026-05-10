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
	sort_by = "id", -- "id" or "modified"
	sort_direction = "asc", -- "asc" or "desc"
}

local buffer_movement = require("luabuff.buffer-movement")

function M.setup(opts)
	for k, v in pairs(vim.tbl_deep_extend("force", config, opts or {})) do
		config[k] = v
	end

	cache.setup_events(config)

	pin_manager.setup(config)

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

-- Custom buffer order: maps bufnr -> sort index for manual reordering
local custom_order = {}
local positions_key = "LuaBuffPositions"

-- Restore buffer order from vim.g
local function restore_positions()
	local str = vim.g[positions_key]
	if not str then
		return
	end
	local ok, paths = pcall(vim.fn.json_decode, str)
	if not ok or type(paths) ~= "table" or #paths == 0 then
		return
	end
	for k in pairs(custom_order) do
		custom_order[k] = nil
	end
	for i, path in ipairs(paths) do
		local bufnr = vim.fn.bufnr("^" .. vim.fn.fnameescape(path) .. "$")
		if bufnr ~= -1 then
			custom_order[bufnr] = i
		end
	end
end

vim.api.nvim_create_autocmd("BufRead", {
	callback = function()
		restore_positions()
	end,
})

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

		-- Custom manual order takes priority
		if custom_order[a] or custom_order[b] then
			local a_order = custom_order[a] or a
			local b_order = custom_order[b] or b
			return a_order < b_order
		end

		if config.sort_by == "modified" then
			local a_name = vim.api.nvim_buf_get_name(a)
			local b_name = vim.api.nvim_buf_get_name(b)
			local a_stat = a_name ~= "" and vim.uv.fs_stat(a_name)
			local b_stat = b_name ~= "" and vim.uv.fs_stat(b_name)
			local a_mtime = a_stat and a_stat.mtime.sec or 0
			local b_mtime = b_stat and b_stat.mtime.sec or 0
			if config.sort_direction == "desc" then
				return a_mtime < b_mtime
			end
			return a_mtime > b_mtime
		end

		if config.sort_direction == "desc" then
			return a > b
		end
		return a < b
	end)

	return buffers
end

local function save_positions()
	local buffers = get_sorted_buffers()
	local paths = vim.tbl_map(function(id)
		return vim.api.nvim_buf_get_name(id)
	end, buffers)
	vim.g[positions_key] = vim.fn.json_encode(paths)
end

-- Main function to get custom buffers
function M.custom_buffers()
	local buffers = get_sorted_buffers()
	local buffer_position_map = create_buffer_position_map(buffers)
	return buffer_renderer.render_buffers(buffers, buffer_position_map, buffer_movement)
end

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

local buffer_order = require("luabuff.buffer-order")

function M.move_buffer(direction)
	buffer_order.move_buffer(direction, get_sorted_buffers, custom_order, save_positions)
end

-- User commands
require("luabuff.commands").setup(M, config, get_sorted_buffers, custom_order, save_positions)

-- Setup keymaps
require("luabuff.keymaps").setup(M)

return M
