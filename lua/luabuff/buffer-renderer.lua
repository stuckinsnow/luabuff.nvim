local M = {}

local cache = require("luabuff.cache")

-- Dependencies that will be injected
local config = nil
local get_bg_color = nil
local create_separator_highlight = nil
local get_buffer_highlight = nil
local is_pinned = nil

-- Setup function to inject dependencies
function M.setup(deps)
	config = deps.config or {}

	-- Set default values for missing config fields
	config.max_visible_buffers = config.max_visible_buffers or 10
	config.modified_icon = config.modified_icon or "●"
	config.pin_icon = config.pin_icon or "📌"
	config.active_separators = config.active_separators or ""
	config.inactive_separators = config.inactive_separators or "|"

	get_bg_color = deps.get_bg_color
	create_separator_highlight = deps.create_separator_highlight
	get_buffer_highlight = deps.get_buffer_highlight
	is_pinned = deps.is_pinned
end

-- Get buffer name without icon
local function get_buffer_display_name(bufnr, position)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "[No Name]"
	end

	name = vim.fn.fnamemodify(name, ":t")
	return string.format("%d - %s", position, name)
end

-- Calculate visible buffer range with scrolling
local function calculate_visible_range(buffers, current_buf)
	local total_buffers = #buffers

	if not config or not config.max_visible_buffers or total_buffers <= config.max_visible_buffers then
		return 1, total_buffers, false, false
	end

	-- Find the index of the active buffer
	local active_index = nil
	for i, bufnr in ipairs(buffers) do
		if bufnr == current_buf then
			active_index = i
			break
		end
	end

	if not active_index then
		return 1, config.max_visible_buffers, false, total_buffers > config.max_visible_buffers
	end

	-- Try to center the active buffer
	local half_visible = math.floor(config.max_visible_buffers / 2)
	local start_pos = math.max(1, active_index - half_visible)
	local end_pos = math.min(total_buffers, start_pos + config.max_visible_buffers - 1)

	-- Adjust if we're near the end
	if end_pos - start_pos + 1 < config.max_visible_buffers then
		start_pos = math.max(1, end_pos - config.max_visible_buffers + 1)
	end

	local has_more_before = start_pos > 1
	local has_more_after = end_pos < total_buffers

	return start_pos, end_pos, has_more_before, has_more_after
end

-- Main buffer rendering function
function M.render_buffers(buffers, buffer_position_map, buffer_movement)
	-- Return cached version if still valid
	local cached_result = cache.get()
	if cached_result then
		return cached_result
	end

	-- Setup buffer movement with current position map
	if buffer_movement and buffer_movement.setup then
		buffer_movement.setup(buffer_position_map)
	end

	local current_buf = vim.api.nvim_get_current_buf()

	-- Calculate visible range
	local start_pos, end_pos, has_more_before, has_more_after = calculate_visible_range(buffers, current_buf)

	local buffer_strings = {}

	-- Add "more before" indicator
	if has_more_before then
		local indicator = string.format("%%#LualineBufferScrollIndicator# ‹‹ %d %%*", start_pos - 1)
		table.insert(buffer_strings, indicator)
	end

	-- Find the index of the active buffer within visible range
	local active_index_in_visible = nil
	for i = start_pos, end_pos do
		if buffers[i] == current_buf then
			active_index_in_visible = i - start_pos + 1 + (has_more_before and 1 or 0)
			break
		end
	end

	-- Process visible buffers
	for i = start_pos, end_pos do
		local bufnr = buffers[i]
		local display_name = get_buffer_display_name(bufnr, i)
		local highlight = get_buffer_highlight and get_buffer_highlight(bufnr) or "Normal"
		local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
		local is_active = (bufnr == current_buf)
		local visible_index = i - start_pos + 1 + (has_more_before and 1 or 0)
		local is_last_visible = (i == end_pos and not has_more_after)
		local is_first_visible = (i == start_pos and not has_more_before)
		local is_after_active = (active_index_in_visible and visible_index == active_index_in_visible + 1)

		-- Add modified indicator
		if is_modified and config and config.modified_icon then
			display_name = display_name .. " " .. config.modified_icon
		end

		-- Add pin indicator
		if is_pinned and is_pinned(bufnr) and config and config.pin_icon then
			display_name = config.pin_icon .. " " .. display_name
		end

		local buffer_str
		local current_bg = get_bg_color and get_bg_color(highlight) or "#000000"

		if is_active then
			if is_last_visible then
				-- Last active buffer - no right separator
				if is_first_visible then
					-- First and active buffer - no left separator
					buffer_str = string.format("%%#%s# %s %%*", highlight, display_name)
				else
					-- Active buffer with left separator only
					local prev_bufnr = buffers[i - 1]
					local prev_highlight = get_buffer_highlight and get_buffer_highlight(prev_bufnr) or "Normal"
					local prev_bg = get_bg_color and get_bg_color(prev_highlight) or "#000000"
					local left_sep_hl = create_separator_highlight
							and create_separator_highlight(prev_bg, current_bg, "left")
						or "Normal"
					local active_sep = (config and config.active_separators) or ""
					buffer_str =
						string.format("%%#%s#%s%%#%s# %s %%*", left_sep_hl, active_sep, highlight, display_name)
				end
			else
				-- Regular active buffer with separators
				if is_first_visible then
					-- First active buffer - no left separator, only right
					local next_bufnr = buffers[i + 1]
					local next_highlight = get_buffer_highlight and get_buffer_highlight(next_bufnr) or "Normal"
					local next_bg = get_bg_color and get_bg_color(next_highlight) or "#000000"
					local right_sep_hl = create_separator_highlight
							and create_separator_highlight(current_bg, next_bg, "right")
						or "Normal"
					local active_sep = (config and config.active_separators) or ""
					buffer_str =
						string.format("%%#%s# %s %%#%s#%s%%*", highlight, display_name, right_sep_hl, active_sep)
				else
					-- Regular active buffer with both separators
					local prev_bufnr = buffers[i - 1]
					local next_bufnr = buffers[i + 1]
					local prev_highlight = get_buffer_highlight and get_buffer_highlight(prev_bufnr) or "Normal"
					local next_highlight = get_buffer_highlight and get_buffer_highlight(next_bufnr) or "Normal"
					local prev_bg = get_bg_color and get_bg_color(prev_highlight) or "#000000"
					local next_bg = get_bg_color and get_bg_color(next_highlight) or "#000000"
					local left_sep_hl = create_separator_highlight
							and create_separator_highlight(prev_bg, current_bg, "left")
						or "Normal"
					local right_sep_hl = create_separator_highlight
							and create_separator_highlight(current_bg, next_bg, "right")
						or "Normal"
					local active_sep = (config and config.active_separators) or ""
					buffer_str = string.format(
						"%%#%s#%s%%#%s# %s %%#%s#%s%%*",
						left_sep_hl,
						active_sep,
						highlight,
						display_name,
						right_sep_hl,
						active_sep
					)
				end
			end
		else
			-- Inactive buffer - add left separator only if NOT first and NOT directly after active buffer
			if is_first_visible or is_after_active then
				-- First buffer or buffer immediately after active - no left separator
				buffer_str = string.format("%%#%s# %s %%*", highlight, display_name)
			else
				-- Regular inactive buffer with left separator
				local inactive_sep = (config and config.inactive_separators) or "|"
				buffer_str =
					string.format("%%#LualineBufferSeparator#%s%%#%s# %s %%*", inactive_sep, highlight, display_name)
			end
		end

		-- Make it clickable using position instead of buffer number
		buffer_str = string.format("%%%d@v:lua.require'luabuff'.switch_to_buffer_by_position@%s%%T", i, buffer_str)

		table.insert(buffer_strings, buffer_str)
	end

	-- Add "more after" indicator
	if has_more_after then
		local remaining = #buffers - end_pos
		local inactive_sep = (config and config.inactive_separators) or "|"
		local indicator = string.format(
			"%%#LualineBufferSeparator#%s%%#LualineBufferScrollIndicator# %d ›› %%*",
			inactive_sep,
			remaining
		)
		table.insert(buffer_strings, indicator)
	end

	-- Cache the result and mark as valid
	local result = table.concat(buffer_strings, "")
	cache.set(result)

	return result
end

return M
