local M = {}

local cache = require("luabuff.cache")

-- Pinned buffers storage
local pinned_buffers = {}
local config = {}

function M.setup(opts)
	config = opts or {}

	-- Initialize pinned buffers from saved state
	if vim.tbl_isempty(pinned_buffers) then
		local saved = vim.g[config.pinned_key]
		if saved and saved ~= "" then
			local saved_list = vim.split(saved, ",")
			for _, buf in ipairs(saved_list) do
				local bufnr = tonumber(buf)
				if bufnr then
					table.insert(pinned_buffers, bufnr)
				end
			end
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

-- Check if buffer is pinned
function M.is_pinned(bufnr)
	return vim.tbl_contains(pinned_buffers, bufnr)
end

-- Toggle pin status of buffer
function M.toggle_pin(bufnr)
	if M.is_pinned(bufnr) then
		pinned_buffers = vim.tbl_filter(function(b)
			return b ~= bufnr
		end, pinned_buffers)
	else
		table.insert(pinned_buffers, bufnr)
	end
	save_pinned_buffers()
	cache.invalidate()
end

-- Toggle pin status of current buffer
function M.toggle_pin_current()
	M.toggle_pin(vim.api.nvim_get_current_buf())
	require("lualine").refresh()
end

return M
