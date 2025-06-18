local M = {}

local buffer_state = require("luabuff.buffer-state")
local pin_manager = require("luabuff.pin-manager")

-- Get background color from highlight group
function M.get_bg_color(highlight_group)
	local hl = vim.api.nvim_get_hl(0, { name = highlight_group })
	if hl.bg then
		return string.format("#%06x", hl.bg)
	end

	-- Final fallback
	return "#1A1B26"
end

-- Create dynamic separator highlight
function M.create_separator_highlight(from_bg, to_bg, separator_type)
	local hl_name =
		string.format("LualineDynamicSep_%s_%s_%s", from_bg:gsub("#", ""), to_bg:gsub("#", ""), separator_type)

	if separator_type == "left" then
		vim.api.nvim_set_hl(0, hl_name, { fg = from_bg, bg = to_bg })
	else -- right
		vim.api.nvim_set_hl(0, hl_name, { fg = from_bg, bg = to_bg })
	end

	return hl_name
end

-- Get highlight group for buffer
function M.get_buffer_highlight(bufnr)
	local state = buffer_state.get_buffer_state(bufnr)
	local pinned = pin_manager.is_pinned(bufnr)
	local _, max_severity = buffer_state.get_buffer_diagnostics(bufnr)
	local git_status = buffer_state.get_git_status(bufnr)

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

return M
