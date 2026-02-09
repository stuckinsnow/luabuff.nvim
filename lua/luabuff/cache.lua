local M = {}

-- Cache variables
local cached_buffer_string = nil
local cache_valid = false
local last_buffer_count = 0
local last_current_buf = nil
local last_mode = nil

-- Check if we're in normal mode
local function is_normal_mode()
	local mode = vim.api.nvim_get_mode().mode
	return mode == "n" or mode == "no" or mode == "nov" or mode == "noV" or mode == "noCTRL-V"
end

-- Invalidate cache
function M.invalidate()
	cache_valid = false
	cached_buffer_string = nil
end

-- Check if we need to refresh cache
function M.should_refresh()
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

-- Get cached result
function M.get()
	if cache_valid and cached_buffer_string then
		return cached_buffer_string
	end
	return nil
end

-- Set cached result
function M.set(result)
	cached_buffer_string = result
	cache_valid = true
end

-- Setup caching with events
function M.setup_events(config)
	local group = vim.api.nvim_create_augroup("LuaBuffCache", { clear = true })

	-- Refresh cache on cursor hold (when idle)
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		callback = function()
			if M.should_refresh() then
				M.invalidate()
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
		callback = function()
			M.invalidate()
			-- Force refresh on buffer add/delete to show immediately
			vim.schedule(function()
				require("lualine").refresh()
			end)
		end,
	})

	-- Handle window events
	vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "WinNew", "WinClosed" }, {
		group = group,
		callback = M.invalidate,
	})

	-- Handle mode changes
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			M.invalidate()
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
				M.invalidate()
			end
		end,
	})

	-- Handle git status changes (if using gitsigns) - only in normal mode
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "GitSignsUpdate",
		callback = function()
			if is_normal_mode() then
				M.invalidate()
			end
		end,
	})

	-- Set a reasonable updatetime for CursorHold (default is 4000ms)
	if vim.o.updatetime > config.updatetime then
		vim.o.updatetime = config.updatetime
	end
end

function M.is_normal_mode()
	return is_normal_mode()
end

return M
