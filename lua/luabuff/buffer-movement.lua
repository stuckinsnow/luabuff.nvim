local M = {}

local function safe_switch(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local ok = pcall(vim.api.nvim_set_current_buf, bufnr)
	if not ok then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		return false
	end
	return true
end

function M.setup(position_map)
	-- Navigate to previous buffer by position
	function M.goto_previous_buffer()
		if vim.tbl_isempty(position_map) then
			vim.cmd("bprevious")
			return
		end

		local current_buf = vim.api.nvim_get_current_buf()
		local current_position = nil

		for pos, bufnr in pairs(position_map) do
			if bufnr == current_buf then
				current_position = pos
				break
			end
		end

		if not current_position then
			vim.cmd("bprevious")
			return
		end

		local total_buffers = vim.tbl_count(position_map)
		local prev_position = current_position == 1 and total_buffers or current_position - 1

		for _ = 1, total_buffers do
			local prev_bufnr = position_map[prev_position]
			if safe_switch(prev_bufnr) then
				return
			end
			prev_position = prev_position == 1 and total_buffers or prev_position - 1
		end
	end

	-- Navigate to next buffer by position
	function M.goto_next_buffer()
		if vim.tbl_isempty(position_map) then
			vim.cmd("bnext")
			return
		end

		local current_buf = vim.api.nvim_get_current_buf()
		local current_position = nil

		for pos, bufnr in pairs(position_map) do
			if bufnr == current_buf then
				current_position = pos
				break
			end
		end

		if not current_position then
			vim.cmd("bnext")
			return
		end

		local total_buffers = vim.tbl_count(position_map)
		local next_position = current_position == total_buffers and 1 or current_position + 1

		for _ = 1, total_buffers do
			local next_bufnr = position_map[next_position]
			if safe_switch(next_bufnr) then
				return
			end
			next_position = next_position == total_buffers and 1 or next_position + 1
		end
	end

	-- Function to switch to buffer by position (for click handling)
	function M.switch_to_buffer_by_position(position)
		local bufnr = position_map[position]
		safe_switch(bufnr)
	end

	-- Function to get buffer by position (for keymaps)
	function M.get_buffer_by_position(position)
		return position_map[position]
	end

	-- Keep the original switch_to_buffer function for backward compatibility
	function M.switch_to_buffer(bufnr)
		safe_switch(bufnr)
	end
end

return M
