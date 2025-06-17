local M = {}

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

		local prev_bufnr = position_map[prev_position]
		if prev_bufnr and vim.api.nvim_buf_is_valid(prev_bufnr) then
			vim.api.nvim_set_current_buf(prev_bufnr)
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

		local next_bufnr = position_map[next_position]
		if next_bufnr and vim.api.nvim_buf_is_valid(next_bufnr) then
			vim.api.nvim_set_current_buf(next_bufnr)
		end
	end

	-- Function to switch to buffer by position (for click handling)
	function M.switch_to_buffer_by_position(position)
		local bufnr = position_map[position]
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_set_current_buf(bufnr)
		end
	end

	-- Function to get buffer by position (for keymaps)
	function M.get_buffer_by_position(position)
		return position_map[position]
	end

	-- Keep the original switch_to_buffer function for backward compatibility
	function M.switch_to_buffer(bufnr)
		vim.api.nvim_set_current_buf(bufnr)
	end
end

return M
