local test_files = {
	"tests/test_app_launch.lua",
	"tests/test_clipboard_center.lua",
	"tests/test_break_reminder.lua",
	"tests/test_init.lua",
	"tests/test_keep_awake.lua",
}

local passed = 0

for _, test_file in ipairs(test_files) do
	io.write(string.format("Running %s...\n", test_file))

	local ok, loader = pcall(loadfile, test_file)

	if ok ~= true then
		io.stderr:write(string.format("Failed to load %s: %s\n", test_file, tostring(loader)))
		os.exit(1)
	end

	local load_ok, test_module = pcall(loader)

	if load_ok ~= true then
		io.stderr:write(string.format("Failed to execute %s: %s\n", test_file, tostring(test_module)))
		os.exit(1)
	end

	local run_ok, run_error = pcall(test_module.run)

	if run_ok ~= true then
		io.stderr:write(string.format("Test failed in %s: %s\n", test_file, tostring(run_error)))
		os.exit(1)
	end

	passed = passed + 1
end

print(string.format("Passed %d test modules.", passed))
