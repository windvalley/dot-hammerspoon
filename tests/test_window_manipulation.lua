local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function reset_modules()
	loaded_modules["window_manipulation"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["window_lib"] = nil
	loaded_modules["hotkey_helper"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		bindings = {},
		deleted_bindings = 0,
		move_and_resize = {},
		direction_resize = {},
		step_move = {},
		move_to_screen = {},
		minimize_calls = 0,
		unminimize_calls = 0,
		close_calls = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					d = function() end,
				}
			end,
		},
	}

	local function hotkey(prefix, key, message)
		return {
			prefix = prefix,
			key = key,
			message = message,
		}
	end

	loaded_modules["keybindings_config"] = {
		window_position = {
			center = hotkey({ "Ctrl", "Option" }, "C", "Center Window"),
			left = hotkey({ "Ctrl", "Option" }, "H", "Left Half of Screen"),
			right = hotkey({ "Ctrl", "Option" }, "L", "Right Half of Screen"),
			up = hotkey({ "Ctrl", "Option" }, "K", "Up Half of Screen"),
			down = hotkey({ "Ctrl", "Option" }, "J", "Down Half of Screen"),
			top_left = hotkey({ "Ctrl", "Option" }, "Y", "Top Left Corner"),
			top_right = hotkey({ "Ctrl", "Option" }, "O", "Top Right Corner"),
			bottom_left = hotkey({ "Ctrl", "Option" }, "U", "Bottom Left Corner"),
			bottom_right = hotkey({ "Ctrl", "Option" }, "I", "Bottom Right Corner"),
			left_1_3 = hotkey({ "Ctrl", "Option" }, "Q", "Left or Top 1/3"),
			right_1_3 = hotkey({ "Ctrl", "Option" }, "W", "Right or Bottom 1/3"),
			left_2_3 = hotkey({ "Ctrl", "Option" }, "E", "Left or Top 2/3"),
			right_2_3 = hotkey({ "Ctrl", "Option" }, "R", "Right or Bottom 2/3"),
		},
		window_movement = {
			to_up = hotkey({ "Ctrl", "Option", "Command" }, "K", "Move Upward"),
			to_down = hotkey({ "Ctrl", "Option", "Command" }, "J", "Move Downward"),
			to_left = hotkey({ "Ctrl", "Option", "Command" }, "H", "Move Leftward"),
			to_right = hotkey({ "Ctrl", "Option", "Command" }, "L", "Move Rightward"),
		},
		window_resize = {
			max = hotkey({ "Ctrl", "Option" }, "M", "Max Window"),
			stretch = hotkey({ "Ctrl", "Option" }, "=", "Stretch Outward"),
			shrink = hotkey({ "Ctrl", "Option" }, "-", "Shrink Inward"),
			stretch_up = hotkey({ "Ctrl", "Option", "Command", "Shift" }, "K", "Bottom Side Stretch Upward"),
			stretch_down = hotkey({ "Ctrl", "Option", "Command", "Shift" }, "J", "Bottom Side Stretch Downward"),
			stretch_left = hotkey({ "Ctrl", "Option", "Command", "Shift" }, "H", "Right Side Stretch Leftward"),
			stretch_right = hotkey({ "Ctrl", "Option", "Command", "Shift" }, "L", "Right Side Stretch Rightward"),
		},
		window_batch = {
			minimize_all_windows = hotkey({ "Ctrl", "Option", "Command" }, "M", "Minimize All Windows"),
			un_minimize_all_windows = hotkey({ "Ctrl", "Option", "Command" }, "U", "Unminimize All Windows"),
			close_all_windows = hotkey({ "Ctrl", "Option", "Command" }, "Q", "Close All Windows"),
		},
		window_monitor = {
			to_above_screen = hotkey({ "Ctrl", "Option", "Command" }, "Up", "Move to Above Screen"),
			to_below_screen = hotkey({ "Ctrl", "Option", "Command" }, "Down", "Move to Below Screen"),
			to_left_screen = hotkey({ "Ctrl", "Option", "Command" }, "Left", "Move to Left Screen"),
			to_right_screen = hotkey({ "Ctrl", "Option", "Command" }, "Right", "Move to Right Screen"),
			to_next_screen = hotkey({ "Ctrl", "Option", "Command" }, "N", "Move to Next Screen"),
		},
	}

	loaded_modules["window_lib"] = {
		moveAndResize = function(option)
			table.insert(recorded.move_and_resize, option)
		end,
		directionStepResize = function(direction)
			table.insert(recorded.direction_resize, direction)
		end,
		stepMove = function(direction)
			table.insert(recorded.step_move, direction)
		end,
		moveToScreen = function(direction)
			table.insert(recorded.move_to_screen, direction)
		end,
		minimizeAllWindows = function()
			recorded.minimize_calls = recorded.minimize_calls + 1
		end,
		unMinimizeAllWindows = function()
			recorded.unminimize_calls = recorded.unminimize_calls + 1
		end,
		closeAllWindows = function()
			recorded.close_calls = recorded.close_calls + 1
		end,
	}

	loaded_modules["hotkey_helper"] = {
		bind = function(modifiers, key, message, pressedfn, _, repeatfn)
			local binding = {
				modifiers = modifiers,
				key = key,
				message = message,
				pressedfn = pressedfn,
				repeatfn = repeatfn,
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
				end,
			}

			table.insert(recorded.bindings, binding)

			return binding
		end,
	}

	local window_manipulation = require("window_manipulation")

	assert_true(window_manipulation.start(), "window_manipulation.start() should succeed")
	assert_equal(#recorded.bindings, 32, "module should register all window manipulation bindings")

	recorded.bindings[1].pressedfn()
	recorded.bindings[14].pressedfn()
	recorded.bindings[17].repeatfn()
	recorded.bindings[21].pressedfn()
	recorded.bindings[27].pressedfn()
	recorded.bindings[30].pressedfn()
	recorded.bindings[31].pressedfn()
	recorded.bindings[32].pressedfn()

	assert_equal(recorded.move_and_resize[1], "center", "first binding should center window")
	assert_equal(recorded.move_and_resize[2], "max", "resize binding should delegate to moveAndResize")
	assert_equal(recorded.direction_resize[1], "up", "stretch repeat should resize in requested direction")
	assert_equal(recorded.step_move[1], "up", "movement binding should step-move window")
	assert_equal(recorded.move_to_screen[1], "left", "monitor binding should move window to target screen")
	assert_equal(recorded.minimize_calls, 1, "batch minimize should be delegated")
	assert_equal(recorded.unminimize_calls, 1, "batch unminimize should be delegated")
	assert_equal(recorded.close_calls, 1, "batch close should be delegated")

	window_manipulation.stop()
	assert_equal(recorded.deleted_bindings, 32, "stop should delete all registered bindings")

	reset_modules()
	hs = nil
end

return _M
