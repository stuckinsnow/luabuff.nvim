local M = {}

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

-- Pinned buffers storage
local pinned_buffers = {}

-- Cache variables
local cached_buffer_string = nil
local cache_valid = false
local last_buffer_count = 0
local last_current_buf = nil
local last_mode = nil

-- Store the position map globally for keymap access
local buffer_position_map = {}

-- Check if we're in normal mode
local function is_normal_mode()
	local mode = vim.api.nvim_get_mode().mode
	return mode == "n" or mode == "no" or mode == "nov" or mode == "noV" or mode == "noCTRL-V"
end

-- Setup function
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Initialize pinned buffers
	if vim.tbl_isempty(pinned_buffers) then
		local saved = vim.g[config.pinned_key]
		if saved and saved ~= "" then
			pinned_buffers = vim.split(saved, ",")
			for i, buf in ipairs(pinned_buffers) do
				pinned_buffers[i] = tostring(buf)
			end
		end
	end

	-- Set updatetime
	if vim.o.updatetime > config.updatetime then
		vim.o.updatetime = config.updatetime
	end
end

-- Initialize pinned buffers from vim.g
local function init_pinned_buffers()
	local saved = vim.g[config.pinned_key]
	if saved and saved ~= "" then
		pinned_buffers = vim.split(saved, ",")
		-- Convert to numbers
		for i, buf in ipairs(pinned_buffers) do
			pinned_buffers[i] = tostring(buf)
		end
	end
end

-- Save pinned buffers to vim.g
local function save_pinned_buffers()
	local buf_strings = {}
	for _, buf in ipairs(pinned_buffers) do
		table.insert(buf_strings, tostring(buf))
	end
	vim.g[config.pinned_key] = table.concat(buf_strings, ",")
end

-- Invalidate cache
local function invalidate_cache()
	cache_valid = false
	cached_buffer_string = nil
end

-- Check if we need to refresh cache
local function should_refresh_cache()
	if not cache_valid then
		return true
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local current_mode = vim.api.nvim_get_mode().mode
	local buffer_count = #vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf)
	end, vim.api.nvim_list_bufs())

	-- Refresh if buffer changed, buffer count changed, or mode changed
	if current_buf ~= last_current_buf or buffer_count ~= last_buffer_count or current_mode ~= last_mode then
		last_current_buf = current_buf
		last_buffer_count = buffer_count
		last_mode = current_mode
		return true
	end

	return false
end

-- Setup caching with events
local function setup_cache_events()
	local group = vim.api.nvim_create_augroup("LuaBuffCache", { clear = true })

	-- Refresh cache on cursor hold (when idle)
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		callback = function()
			if should_refresh_cache() then
				invalidate_cache()
				-- Trigger lualine refresh after a short delay to batch updates
				vim.defer_fn(function()
					require("lualine").refresh()
				end, 50)
			end
		end,
	})

	-- Invalidate cache on buffer events
	vim.api.nvim_create_autocmd({
		"BufAdd",
		"BufDelete",
		"BufWipeout",
		"BufNew",
		"BufEnter",
		"BufLeave",
		"BufModifiedSet",
	}, {
		group = group,
		callback = invalidate_cache,
	})

	-- Handle window events
	vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "WinNew", "WinClosed" }, {
		group = group,
		callback = invalidate_cache,
	})

	-- Handle mode changes
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			invalidate_cache()
			-- Refresh lualine when entering/leaving normal mode
			vim.defer_fn(function()
				require("lualine").refresh()
			end, 50)
		end,
	})

	-- Handle diagnostic changes (only invalidate if in normal mode)
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function()
			if is_normal_mode() then
				invalidate_cache()
			end
		end,
	})

	-- Handle git status changes (if using gitsigns) - only in normal mode
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "GitSignsUpdate",
		callback = function()
			if is_normal_mode() then
				invalidate_cache()
			end
		end,
	})

	-- Set a reasonable updatetime for CursorHold (default is 4000ms)
	if vim.o.updatetime > config.updatetime then
		vim.o.updatetime = config.updatetime
	end
end

-- Check if buffer is pinned
local function is_pinned(bufnr)
	return vim.tbl_contains(pinned_buffers, bufnr)
end

-- Toggle pin status of buffer
local function toggle_pin(bufnr)
	if is_pinned(bufnr) then
		pinned_buffers = vim.tbl_filter(function(b)
			return b ~= bufnr
		end, pinned_buffers)
	else
		table.insert(pinned_buffers, bufnr)
	end
	save_pinned_buffers()
	invalidate_cache() -- Invalidate when pins change
end

-- Get buffer state (active, visible, inactive)
local function get_buffer_state(bufnr)
	local current_buf = vim.api.nvim_get_current_buf()

	if bufnr == current_buf then
		return "active"
	end

	-- Check if buffer is visible in any window
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			return "visible"
		end
	end

	return "inactive"
end

-- Get buffer diagnostics (only in normal mode)
local function get_buffer_diagnostics(bufnr)
	-- Only check diagnostics in normal mode
	if not is_normal_mode() then
		return { error = 0, warn = 0, info = 0, hint = 0 }, nil
	end

	local diagnostics = vim.diagnostic.get(bufnr)
	local counts = { error = 0, warn = 0, info = 0, hint = 0 }
	local max_severity = nil

	for _, diag in ipairs(diagnostics) do
		if diag.severity == vim.diagnostic.severity.ERROR then
			counts.error = counts.error + 1
			max_severity = max_severity or "error"
		elseif diag.severity == vim.diagnostic.severity.WARN then
			counts.warn = counts.warn + 1
			max_severity = max_severity or "warn"
		elseif diag.severity == vim.diagnostic.severity.INFO then
			counts.info = counts.info + 1
			max_severity = max_severity or "info"
		elseif diag.severity == vim.diagnostic.severity.HINT then
			counts.hint = counts.hint + 1
			max_severity = max_severity or "hint"
		end
	end

	return counts, max_severity
end

-- Get git status for buffer (only in normal mode)
local function get_git_status(bufnr)
	-- Only check git status in normal mode
	if not is_normal_mode() then
		return nil
	end

	local gitsigns = vim.b[bufnr].gitsigns_status_dict
	if not gitsigns then
		return nil
	end

	if gitsigns.added and gitsigns.added > 0 then
		return "added"
	end
	if gitsigns.changed and gitsigns.changed > 0 then
		return "changed"
	end
	if gitsigns.removed and gitsigns.removed > 0 then
		return "deleted"
	end

	return nil
end

-- Get background color from highlight group
local function get_bg_color(highlight_group)
	local hl = vim.api.nvim_get_hl(0, { name = highlight_group })
	if hl.bg then
		return string.format("#%06x", hl.bg)
	end

	-- Fallback to getting colors from your theme's highlight groups
	local fallback_groups = {
		Error = "LualineBufferActiveError",
		Warn = "LualineBufferActiveWarn",
		Info = "LualineBufferActiveInfo",
		Hint = "LualineBufferActiveHint",
		GitAdded = "LualineBufferActiveGitAdded",
		GitChanged = "LualineBufferActiveGitChanged",
		GitDeleted = "LualineBufferActiveGitDeleted",
		Normal = "lualine_buffer_normal",
		Inactive = "lualine_buffer_inactive",
	}

	-- Try to match highlight group to fallback
	for pattern, fallback_group in pairs(fallback_groups) do
		if highlight_group:match(pattern) then
			local fallback_hl = vim.api.nvim_get_hl(0, { name = fallback_group })
			if fallback_hl.bg then
				return string.format("#%06x", fallback_hl.bg)
			end
		end
	end

	-- Final fallback to lualine_buffer_normal background
	local normal_hl = vim.api.nvim_get_hl(0, { name = "lualine_buffer_normal" })
	if normal_hl.bg then
		return string.format("#%06x", normal_hl.bg)
	end

	-- Ultimate fallback if nothing works
	return "#1A1B26"
end

-- Create dynamic separator highlight
local function create_separator_highlight(from_bg, to_bg, separator_type)
	local hl_name =
		string.format("LualineDynamicSep_%s_%s_%s", from_bg:gsub("#", ""), to_bg:gsub("#", ""), separator_type)

	if separator_type == "left" then
		-- Left separator: foreground = previous buffer bg, background = current buffer bg
		vim.api.nvim_set_hl(0, hl_name, { fg = from_bg, bg = to_bg })
	else -- right
		-- Right separator: foreground = current buffer bg, background = next buffer bg
		vim.api.nvim_set_hl(0, hl_name, { fg = from_bg, bg = to_bg })
	end

	return hl_name
end

-- Get highlight group for buffer
local function get_buffer_highlight(bufnr)
	local state = get_buffer_state(bufnr)
	local pinned = is_pinned(bufnr)
	local _, max_severity = get_buffer_diagnostics(bufnr)
	local git_status = get_git_status(bufnr)

	-- Priority: diagnostics > git > modified > pinned > state
	if max_severity then
		if state == "active" then
			return "LualineBufferActive" .. max_severity:gsub("^%l", string.upper)
		else
			return "LualineBuffer" .. max_severity:gsub("^%l", string.upper)
		end
	end

	if git_status then
		if state == "active" then
			return "LualineBufferActiveGit" .. git_status:gsub("^%l", string.upper)
		else
			return "LualineBufferGit" .. git_status:gsub("^%l", string.upper)
		end
	end

	-- Active buffer always takes precedence for remaining cases
	if state == "active" then
		if pinned then
			return "LualineBufferActivePinned"
		end
		return "lualine_buffer_normal"
	end

	if pinned then
		return "LualineBufferPinned"
	end

	-- Default state-based highlight
	if state == "visible" then
		return "LualineBufferVisible"
	end
	return "lualine_buffer_inactive"
end

-- Get buffer name without icon
local function get_buffer_display_name(bufnr, position)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "[No Name]"
	end

	name = vim.fn.fnamemodify(name, ":t")
	-- Use sequential position instead of buffer number
	return string.format("%d - %s", position, name)
end

-- Create buffer position mapping
local function create_buffer_position_map(buffers)
	local position_map = {}
	for i, bufnr in ipairs(buffers) do
		position_map[i] = bufnr
	end
	return position_map
end

-- Calculate visible buffer range with scrolling
local function calculate_visible_range(buffers, current_buf)
	local total_buffers = #buffers

	if total_buffers <= config.max_visible_buffers then
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

-- Main function to get custom buffers - this returns a single string for lualine
function M.custom_buffers()
	-- Return cached version if still valid
	if cache_valid and cached_buffer_string then
		return cached_buffer_string
	end

	-- Initialize pinned buffers on first run
	if vim.tbl_isempty(pinned_buffers) then
		init_pinned_buffers()
	end

	-- Get all valid buffers (both loaded and listed)
	local buffers = vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf)
	end, vim.api.nvim_list_bufs())

	-- Sort buffers: pinned first, then by buffer number
	table.sort(buffers, function(a, b)
		local a_pinned = is_pinned(a)
		local b_pinned = is_pinned(b)

		if a_pinned and not b_pinned then
			return true
		end
		if b_pinned and not a_pinned then
			return false
		end

		return a < b
	end)

	-- Create position mapping
	buffer_position_map = create_buffer_position_map(buffers)

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
		local highlight = get_buffer_highlight(bufnr)
		local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
		local is_active = (bufnr == current_buf)
		local visible_index = i - start_pos + 1 + (has_more_before and 1 or 0)
		local is_last_visible = (i == end_pos and not has_more_after)
		local is_first_visible = (i == start_pos and not has_more_before)
		local is_after_active = (active_index_in_visible and visible_index == active_index_in_visible + 1)

		-- Add modified indicator
		if is_modified then
			display_name = display_name .. " " .. config.modified_icon
		end

		-- Add pin indicator
		if is_pinned(bufnr) then
			display_name = config.pin_icon .. " " .. display_name
		end

		local buffer_str
		local current_bg = get_bg_color(highlight)

		if is_active then
			if is_last_visible then
				-- Last active buffer - no right separator
				if is_first_visible then
					-- First and active buffer - no left separator
					buffer_str = string.format("%%#%s# %s %%*", highlight, display_name)
				else
					-- Active buffer with left separator only
					local prev_bufnr = buffers[i - 1]
					local prev_highlight = get_buffer_highlight(prev_bufnr)
					local prev_bg = get_bg_color(prev_highlight)
					local left_sep_hl = create_separator_highlight(prev_bg, current_bg, "left")
					buffer_str = string.format(
						"%%#%s#%s%%#%s# %s %%*",
						left_sep_hl,
						config.active_separators,
						highlight,
						display_name
					)
				end
			else
				-- Regular active buffer with separators
				if is_first_visible then
					-- First active buffer - no left separator, only right
					local next_bufnr = buffers[i + 1]
					local next_highlight = get_buffer_highlight(next_bufnr)
					local next_bg = get_bg_color(next_highlight)
					local right_sep_hl = create_separator_highlight(current_bg, next_bg, "right")
					buffer_str = string.format(
						"%%#%s# %s %%#%s#%s%%*",
						highlight,
						display_name,
						right_sep_hl,
						config.active_separators
					)
				else
					-- Regular active buffer with both separators
					local prev_bufnr = buffers[i - 1]
					local next_bufnr = buffers[i + 1]
					local prev_highlight = get_buffer_highlight(prev_bufnr)
					local next_highlight = get_buffer_highlight(next_bufnr)
					local prev_bg = get_bg_color(prev_highlight)
					local next_bg = get_bg_color(next_highlight)
					local left_sep_hl = create_separator_highlight(prev_bg, current_bg, "left")
					local right_sep_hl = create_separator_highlight(current_bg, next_bg, "right")
					buffer_str = string.format(
						"%%#%s#%s%%#%s# %s %%#%s#%s%%*",
						left_sep_hl,
						config.active_separators,
						highlight,
						display_name,
						right_sep_hl,
						config.active_separators
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
				buffer_str = string.format(
					"%%#LualineBufferSeparator#%s%%#%s# %s %%*",
					config.inactive_separators,
					highlight,
					display_name
				)
			end
		end

		-- Make it clickable using position instead of buffer number
		buffer_str = string.format("%%%d@v:lua.require'luabuff.nvim'.switch_to_buffer_by_position@%s%%T", i, buffer_str)

		table.insert(buffer_strings, buffer_str)
	end

	-- Add "more after" indicator
	if has_more_after then
		local remaining = #buffers - end_pos
		local indicator = string.format(
			"%%#LualineBufferSeparator#%s%%#LualineBufferScrollIndicator# %d ›› %%*",
			config.inactive_separators,
			remaining
		)
		table.insert(buffer_strings, indicator)
	end

	-- Cache the result and mark as valid
	local result = table.concat(buffer_strings, "")
	cached_buffer_string = result
	cache_valid = true

	return result
end

-- Export the main function for lualine
function M.get_buffers()
	return M.custom_buffers()
end

-- Keep the original switch_to_buffer function for backward compatibility
function M.switch_to_buffer(bufnr)
	vim.api.nvim_set_current_buf(bufnr)
end

-- Expose function to get sorted buffers (same logic as used in custom_buffers)
function M.get_sorted_buffers()
	-- Get all valid buffers (both loaded and listed)
	local buffers = vim.tbl_filter(function(buf)
		return vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf)
	end, vim.api.nvim_list_bufs())

	-- Sort buffers: pinned first, then by buffer number
	table.sort(buffers, function(a, b)
		local a_pinned = is_pinned(a)
		local b_pinned = is_pinned(b)

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

-- Navigate to previous buffer by position
function M.goto_previous_buffer()
	if vim.tbl_isempty(buffer_position_map) then
		vim.cmd("bprevious")
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local current_position = nil

	for pos, bufnr in pairs(buffer_position_map) do
		if bufnr == current_buf then
			current_position = pos
			break
		end
	end

	if not current_position then
		vim.cmd("bprevious")
		return
	end

	local total_buffers = vim.tbl_count(buffer_position_map)
	local prev_position = current_position == 1 and total_buffers or current_position - 1

	local prev_bufnr = buffer_position_map[prev_position]
	if prev_bufnr and vim.api.nvim_buf_is_valid(prev_bufnr) then
		vim.api.nvim_set_current_buf(prev_bufnr)
	end
end

-- Navigate to next buffer by position
function M.goto_next_buffer()
	if vim.tbl_isempty(buffer_position_map) then
		vim.cmd("bnext")
		return
	end

	local current_buf = vim.api.nvim_get_current_buf()
	local current_position = nil

	for pos, bufnr in pairs(buffer_position_map) do
		if bufnr == current_buf then
			current_position = pos
			break
		end
	end

	if not current_position then
		vim.cmd("bnext")
		return
	end

	local total_buffers = vim.tbl_count(buffer_position_map)
	local next_position = current_position == total_buffers and 1 or current_position + 1

	local next_bufnr = buffer_position_map[next_position]
	if next_bufnr and vim.api.nvim_buf_is_valid(next_bufnr) then
		vim.api.nvim_set_current_buf(next_bufnr)
	end
end

-- Function to switch to buffer by position (for click handling)
function M.switch_to_buffer_by_position(position)
	local bufnr = buffer_position_map[position]
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_set_current_buf(bufnr)
	end
end

-- Function to get buffer by position (for keymaps)
function M.get_buffer_by_position(position)
	return buffer_position_map[position]
end

-- Expose toggle pin function for keymaps
function M.toggle_pin_current()
	toggle_pin(vim.api.nvim_get_current_buf())
	invalidate_cache()
	require("lualine").refresh()
end

setup_cache_events()

-- Keymaps
local function setup_keymaps()
	-- Change buffers using position-based navigation
	vim.keymap.set("n", "<M-s>", function()
		M.goto_previous_buffer()
	end, { noremap = true, silent = true, desc = "Previous buffer by position" })

	vim.keymap.set("n", "<M-f>", function()
		M.goto_next_buffer()
	end, { noremap = true, silent = true, desc = "Next buffer by position" })

	-- Delete buffers to the left and right using the same sorting as lualine
	local function delete_buffers(direction)
		local current_buf = vim.api.nvim_get_current_buf()

		-- Get the same sorted buffer list as used in lualine
		local buffers = M.get_sorted_buffers()

		-- Find current buffer's position in the sorted list
		local current_index = nil
		for i, buf_id in ipairs(buffers) do
			if buf_id == current_buf then
				current_index = i
				break
			end
		end

		if current_index then
			if direction == "left" then
				-- Delete buffers to the left
				for i = 1, current_index - 1 do
					if vim.api.nvim_buf_is_valid(buffers[i]) and not vim.bo[buffers[i]].modified then
						vim.api.nvim_buf_delete(buffers[i], { force = false })
					end
				end
			elseif direction == "right" then
				-- Delete buffers to the right
				for i = current_index + 1, #buffers do
					if vim.api.nvim_buf_is_valid(buffers[i]) and not vim.bo[buffers[i]].modified then
						vim.api.nvim_buf_delete(buffers[i], { force = false })
					end
				end
			end
		end
	end

	vim.keymap.set("n", "<leader>bl", function()
		if vim.fn.exists(":AerialClose") == 2 then
			vim.cmd("AerialClose")
		end
		delete_buffers("left")
	end, { noremap = true, silent = true, desc = "Delete Buffers to the Left" })

	vim.keymap.set("n", "<leader>br", function()
		if vim.fn.exists(":AerialClose") == 2 then
			vim.cmd("AerialClose")
		end
		delete_buffers("right")
	end, { noremap = true, silent = true, desc = "Delete Buffers to the Right" })

	-- Map Alt-1 through Alt-6 to switch to the corresponding buffer position
	for i = 1, 6 do
		vim.keymap.set("n", "<A-" .. i .. ">", function()
			local bufnr = M.get_buffer_by_position(i)
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_set_current_buf(bufnr)
			end
		end, { desc = "Go to buffer " .. i })
	end

	-- Pin/unpin current buffer
	vim.keymap.set("n", "<leader>bp", function()
		M.toggle_pin_current()
	end, { desc = "Toggle pin current buffer" })
end

setup_keymaps()

return M
