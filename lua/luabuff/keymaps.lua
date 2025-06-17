local M = {}

function M.setup(luabuff_module)
	-- Change buffers using position-based navigation
	vim.keymap.set("n", "<M-s>", function()
		luabuff_module.goto_previous_buffer()
	end, { noremap = true, silent = true, desc = "Previous buffer by position" })

	vim.keymap.set("n", "<M-f>", function()
		luabuff_module.goto_next_buffer()
	end, { noremap = true, silent = true, desc = "Next buffer by position" })

	-- Delete buffers to the left and right using the same sorting as lualine
	local function delete_buffers(direction)
		local current_buf = vim.api.nvim_get_current_buf()

		-- Get the same sorted buffer list as used in lualine
		local buffers = luabuff_module.get_sorted_buffers()

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
			local bufnr = luabuff_module.get_buffer_by_position(i)
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_set_current_buf(bufnr)
			end
		end, { desc = "Go to buffer " .. i })
	end

	-- Pin/unpin current buffer
	vim.keymap.set("n", "<leader>bp", function()
		luabuff_module.toggle_pin_current()
	end, { desc = "Toggle pin current buffer" })
end

return M
