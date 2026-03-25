local function discover_test_files()
	local handle = io.popen("find tests -maxdepth 1 -type f -name 'test_*.lua' | sort")

	if handle == nil then
		error("failed to discover test files")
	end

	local files = {}

	for line in handle:lines() do
		table.insert(files, line)
	end

	local ok, _, exit_code = handle:close()

	if ok ~= true then
		error(string.format("failed to discover test files (exit code: %s)", tostring(exit_code)))
	end

	return files
end

local test_files = discover_test_files()

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
