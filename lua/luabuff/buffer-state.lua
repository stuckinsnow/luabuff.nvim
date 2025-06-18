local M = {}

local cache = require("luabuff.cache")

-- Get buffer state (active, visible, inactive)
function M.get_buffer_state(bufnr)
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
function M.get_buffer_diagnostics(bufnr)
	if not cache.is_normal_mode() then
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
function M.get_git_status(bufnr)
	if not cache.is_normal_mode() then
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

return M
