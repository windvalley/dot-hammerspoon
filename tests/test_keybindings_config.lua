local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

local function reset_modules()
	loaded_modules["keybindings_config"] = nil
end

function _M.run()
	reset_modules()

	local config = require("keybindings_config")
	local break_reminder = config.break_reminder or {}

	assert_equal(break_reminder.mode, "soft", "default break reminder mode should remain soft")
	assert_equal(break_reminder.overlay_opacity, 0.32, "soft mode default opacity should stay translucent")
	assert_equal(break_reminder.start_next_cycle, "on_input", "default next cycle mode should wait for input")
	assert_equal(break_reminder.menubar_skin, "hourglass", "default menubar skin should match documented example")

	reset_modules()
end

return _M
