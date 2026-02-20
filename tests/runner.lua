-- Test runner for luabuff
-- Run: nvim --headless -u NONE -l tests/runner.lua

-- Add plugin to runtimepath
vim.opt.rtp:prepend(".")

local total_passed, total_failed = 0, 0

local function run_spec(path)
	print("\n── " .. path .. " ──")
	local spec = dofile(path)
	if spec then
		total_passed = total_passed + (spec.passed or 0)
		total_failed = total_failed + (spec.failed or 0)
	end
end

-- Discover and run all *_spec.lua files in tests/
local specs = vim.fn.glob("tests/*_spec.lua", false, true)
table.sort(specs)

for _, spec in ipairs(specs) do
	run_spec(spec)
end

print(string.format("\n══ Total: %d passed, %d failed ══", total_passed, total_failed))
vim.cmd(total_failed > 0 and "cq" or "q")
