-- Tests for buffer-movement safe_switch (E211 fix)

local movement = require("luabuff.buffer-movement")

local passed, failed = 0, 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("  ✓ " .. name)
	else
		failed = failed + 1
		print("  ✗ " .. name .. ": " .. tostring(err))
	end
end

local function create_tmp_buf(content)
	local tmp = vim.fn.tempname()
	vim.fn.writefile({ content or "test" }, tmp)
	vim.cmd("edit " .. tmp)
	return vim.api.nvim_get_current_buf(), tmp
end

test("safe_switch skips deleted file without error", function()
	local bufnr, tmp = create_tmp_buf()
	vim.cmd("enew")
	local safe_buf = vim.api.nvim_get_current_buf()
	os.remove(tmp)

	movement.setup({ [1] = safe_buf, [2] = bufnr })
	movement.switch_to_buffer(bufnr)

	assert(vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()), "current buf should be valid")
end)

test("goto_next skips stale buffer and lands on valid one", function()
	local buf1, tmp1 = create_tmp_buf("file1")
	local buf2, tmp2 = create_tmp_buf("file2")
	vim.cmd("enew")
	local buf3 = vim.api.nvim_get_current_buf()

	os.remove(tmp2)
	movement.setup({ [1] = buf1, [2] = buf2, [3] = buf3 })

	vim.api.nvim_set_current_buf(buf1)
	movement.goto_next_buffer()

	assert(vim.api.nvim_get_current_buf() == buf3, "should skip stale buf2 and land on buf3")
	os.remove(tmp1)
end)

test("goto_previous skips stale buffer and lands on valid one", function()
	local buf1, tmp1 = create_tmp_buf("file1")
	local buf2, tmp2 = create_tmp_buf("file2")
	vim.cmd("enew")
	local buf3 = vim.api.nvim_get_current_buf()

	os.remove(tmp2)
	movement.setup({ [1] = buf1, [2] = buf2, [3] = buf3 })

	vim.api.nvim_set_current_buf(buf3)
	movement.goto_previous_buffer()

	assert(vim.api.nvim_get_current_buf() == buf1, "should skip stale buf2 and land on buf1")
	os.remove(tmp1)
end)

print(string.format("  %d passed, %d failed", passed, failed))
return { passed = passed, failed = failed }
