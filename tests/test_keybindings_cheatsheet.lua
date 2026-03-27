local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_contains(text, expected, message)
	if tostring(text or ""):find(expected, 1, true) == nil then
		error(string.format("%s: expected to find %s in %s", message or "assert_contains failed", tostring(expected), tostring(text)))
	end
end

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function create_hotkey_helper_stub(recorded)
	local modifier_aliases = {
		ctrl = "ctrl",
		control = "ctrl",
		option = "alt",
		alt = "alt",
		command = "cmd",
		cmd = "cmd",
		shift = "shift",
		fn = "fn",
	}
	local modifier_symbols = {
		ctrl = "⌃",
		alt = "⌥",
		cmd = "⌘",
		shift = "⇧",
		fn = "fn",
	}

	return {
		format_hotkey = function(modifiers, key)
			local parts = {}

			for _, modifier in ipairs(modifiers or {}) do
				local normalized = modifier_aliases[string.lower(tostring(modifier))]
				table.insert(parts, modifier_symbols[normalized or ""] or tostring(modifier))
			end

			table.insert(parts, string.upper(tostring(key or "")))

			return table.concat(parts, " ")
		end,
		normalize_hotkey_modifiers = function(modifiers)
			return modifiers or {}
		end,
		bind = function(_, _, _, pressedfn)
			recorded.bound_handler = pressedfn

			return {
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
				end,
			}
		end,
	}
end

local function reset_modules()
	loaded_modules["keybindings_cheatsheet"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		rendered_text = {},
		text_frames = {},
		segment_coordinates = {},
		canvas_frames = {},
		deleted_bindings = 0,
		bound_handler = nil,
		settings_store = {
			["clipboard_center.hotkey.modifiers"] = { "ctrl", "shift" },
			["clipboard_center.hotkey.key"] = "x",
			["keep_awake.hotkey.modifiers"] = { "ctrl", "option" },
			["keep_awake.hotkey.key"] = "a",
		},
	}

	hs = {
		logger = {
			new = function()
				return {
					w = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return recorded.settings_store[key]
			end,
		},
		window = {
			focusedWindow = function()
				return nil
			end,
		},
		screen = {
			mainScreen = function()
				return {
					frame = function()
						return { x = 0, y = 0, w = 1440, h = 900 }
					end,
				}
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = {
			new = function()
				local state = {
					frame = { x = 0, y = 0, w = 0, h = 0 },
				}

				return {
					appendElements = function(_, ...)
						for _, element in ipairs({ ... }) do
							if element.type == "text" then
								table.insert(recorded.rendered_text, element.text)
								table.insert(recorded.text_frames, element.frame)
							elseif element.type == "segments" then
								table.insert(recorded.segment_coordinates, element.coordinates)
							end
						end
					end,
					minimumTextSize = function(_, text)
						local longest_line = 0

						for line in tostring(text or ""):gmatch("[^\n]+") do
							longest_line = math.max(longest_line, #line)
						end

						return {
							w = longest_line,
							h = 10,
						}
					end,
					frame = function(_, value)
						if value ~= nil then
							state.frame = value
							table.insert(recorded.canvas_frames, value)
						end

						return state.frame
					end,
					hide = function() end,
					delete = function() end,
					show = function() end,
				}
			end,
		},
	}

		loaded_modules["keybindings_config"] = {
		keybindings_cheatsheet = {
			prefix = { "Option" },
			key = "/",
			message = "Cheatsheet",
		},
		manual_input_methods = {
			{ prefix = { "Option" }, key = "1", message = "ABC" },
		},
		system = {
			lock_screen = { prefix = { "Option" }, key = "Q", message = "Lock Screen" },
			screen_saver = { prefix = { "Option" }, key = "S", message = "Start Screensaver" },
			keep_awake = { prefix = { "Option" }, key = "A", message = "Toggle Prevent Sleep" },
			restart = { prefix = { "Ctrl", "Option" }, key = "R", message = "Restart Computer" },
			shutdown = { prefix = { "Ctrl", "Option" }, key = "X", message = "Shutdown Computer" },
		},
		clipboard = {
			enabled = true,
			prefix = { "Option", "Shift" },
			key = "C",
			message = "Clipboard Center",
		},
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
		},
		key_caster = {
			toggle_hotkey = {
				prefix = { "Command", "Ctrl" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
		websites = {
			{ prefix = { "Option" }, key = "8", message = "github.com" },
		},
			apps = {
				{ prefix = { "Option" }, key = "C", message = "Chrome" },
				{ prefix = { "Option" }, key = "1", message = "Long App Launch Label For Second Column Width Check" },
			},
		window_position = {
			center = { prefix = { "Ctrl", "Option" }, key = "C", message = "Center Window" },
			left = { prefix = { "Ctrl", "Option" }, key = "H", message = "Left Half of Screen" },
			right = { prefix = { "Ctrl", "Option" }, key = "L", message = "Right Half of Screen" },
			up = { prefix = { "Ctrl", "Option" }, key = "K", message = "Up Half of Screen" },
			down = { prefix = { "Ctrl", "Option" }, key = "J", message = "Down Half of Screen" },
			top_left = { prefix = { "Ctrl", "Option" }, key = "Y", message = "Top Left Corner" },
			top_right = { prefix = { "Ctrl", "Option" }, key = "O", message = "Top Right Corner" },
			bottom_left = { prefix = { "Ctrl", "Option" }, key = "U", message = "Bottom Left Corner" },
			bottom_right = { prefix = { "Ctrl", "Option" }, key = "I", message = "Bottom Right Corner" },
			left_1_3 = { prefix = { "Ctrl", "Option" }, key = "Q", message = "Left or Top 1/3" },
			right_1_3 = { prefix = { "Ctrl", "Option" }, key = "W", message = "Right or Bottom 1/3" },
			left_2_3 = { prefix = { "Ctrl", "Option" }, key = "E", message = "Left or Top 2/3" },
			right_2_3 = { prefix = { "Ctrl", "Option" }, key = "R", message = "Right or Bottom 2/3" },
		},
		window_movement = {
			to_up = { prefix = { "Ctrl", "Option", "Command" }, key = "K", message = "Move Upward" },
			to_down = { prefix = { "Ctrl", "Option", "Command" }, key = "J", message = "Move Downward" },
			to_left = { prefix = { "Ctrl", "Option", "Command" }, key = "H", message = "Move Leftward" },
			to_right = { prefix = { "Ctrl", "Option", "Command" }, key = "L", message = "Move Rightward" },
		},
		window_resize = {
			max = { prefix = { "Ctrl", "Option" }, key = "M", message = "Max Window" },
			stretch = { prefix = { "Ctrl", "Option" }, key = "=", message = "Stretch Outward" },
			shrink = { prefix = { "Ctrl", "Option" }, key = "-", message = "Shrink Inward" },
			stretch_up = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "K", message = "Bottom Side Stretch Upward" },
			stretch_down = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "J", message = "Bottom Side Stretch Downward" },
			stretch_left = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "H", message = "Right Side Stretch Leftward" },
			stretch_right = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "L", message = "Right Side Stretch Rightward" },
		},
		window_monitor = {
			to_above_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Up", message = "Move to Above Screen" },
			to_below_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Down", message = "Move to Below Screen" },
			to_left_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Left", message = "Move to Left Screen" },
			to_right_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Right", message = "Move to Right Screen" },
			to_next_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "N", message = "Move to Next Screen" },
		},
		window_batch = {
			minimize_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "M", message = "Minimize All Windows" },
			un_minimize_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "U", message = "Unminimize All Windows" },
			close_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "Q", message = "Close All Windows" },
		},
	}
	loaded_modules["keybindings_config"].window_position.center = nil

	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(recorded)

	loaded_modules["utils_lib"] = {
		utf8len = function(text)
			return #tostring(text or "")
		end,
		utf8sub = function(text, start_char, num_chars)
			return tostring(text or ""):sub(start_char, start_char + num_chars - 1)
		end,
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
	}

	local cheatsheet = require("keybindings_cheatsheet")

	assert_true(cheatsheet.start(), "keybindings_cheatsheet.start() should succeed")
	assert_true(#recorded.rendered_text == 0, "cheatsheet should not render canvas during startup")
	assert_true(type(recorded.bound_handler) == "function", "cheatsheet hotkey handler should be registered")

	recorded.bound_handler()

	local rendered = table.concat(recorded.rendered_text, "\n")
	assert_contains(rendered, "⌃ ⇧ X: Clipboard Center", "clipboard hotkey should use runtime override")
	assert_contains(rendered, "⌃ ⌥ A: Toggle Prevent Sleep", "keep awake hotkey should use runtime override")
	assert_contains(rendered, "[Selected Text Translate]", "selected text translate section should be rendered in cheatsheet")
	assert_contains(rendered, "⌥ R: Translate Selection", "selected text translate hotkey should be rendered in cheatsheet")
	assert_contains(rendered, "[Key Caster]", "key caster section should be rendered in cheatsheet")
	assert_contains(rendered, "⌘ ⌃ K: Toggle Key Cas", "key caster toggle hotkey should be rendered in cheatsheet")
	assert_contains(rendered, "⌥ /: Cheatsheet", "cheatsheet should render its own configured shortcut")
	assert_contains(rendered, "⌃ ⌥ H: Left Half of Screen", "named config sections should keep rendering after a missing leading item")
	assert_true(#recorded.text_frames >= 2, "rendered cheatsheet should span multiple columns in the test fixture")
	assert_true(
		recorded.text_frames[2].x > (recorded.text_frames[1].x + recorded.text_frames[1].w),
		"second column should be positioned after the first column without overlap"
	)
	assert_true(#recorded.segment_coordinates >= 1, "multi-column cheatsheet should draw separator lines")
	assert_true(#recorded.canvas_frames >= 1, "cheatsheet should position its canvas after rendering")
	assert_true(recorded.canvas_frames[#recorded.canvas_frames].w > 0, "canvas width should be positive after rendering")
	assert_true(recorded.canvas_frames[#recorded.canvas_frames].h > 0, "canvas height should be positive after rendering")

	cheatsheet.stop()
	assert_true(recorded.deleted_bindings > 0, "stop should delete bound hotkey")

	reset_modules()

	recorded = {
		rendered_text = {},
		text_frames = {},
		segment_coordinates = {},
		canvas_frames = {},
		deleted_bindings = 0,
		bound_handler = nil,
		settings_store = {},
	}

	hs = {
		logger = {
			new = function()
				return {
					w = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return recorded.settings_store[key]
			end,
		},
		window = {
			focusedWindow = function()
				return nil
			end,
		},
		screen = {
			mainScreen = function()
				return {
					frame = function()
						return { x = 0, y = 0, w = 120, h = 900 }
					end,
				}
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = {
			new = function()
				local state = {
					frame = { x = 0, y = 0, w = 0, h = 0 },
				}

				return {
					appendElements = function(_, ...)
						for _, element in ipairs({ ... }) do
							if element.type == "text" then
								table.insert(recorded.rendered_text, element.text)
								table.insert(recorded.text_frames, element.frame)
							elseif element.type == "segments" then
								table.insert(recorded.segment_coordinates, element.coordinates)
							end
						end
					end,
					minimumTextSize = function(_, text)
						local longest_line = 0

						for line in tostring(text or ""):gmatch("[^\n]+") do
							longest_line = math.max(longest_line, #line)
						end

						return {
							w = longest_line,
							h = 10,
						}
					end,
					frame = function(_, value)
						if value ~= nil then
							state.frame = value
							table.insert(recorded.canvas_frames, value)
						end

						return state.frame
					end,
					hide = function() end,
					delete = function() end,
					show = function() end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		keybindings_cheatsheet = {
			prefix = { "Option" },
			key = "/",
			message = "Cheatsheet",
		},
		manual_input_methods = {
			{ prefix = { "Option" }, key = "1", message = "ABC" },
		},
		system = {
			lock_screen = { prefix = { "Option" }, key = "Q", message = "Lock Screen" },
			screen_saver = { prefix = { "Option" }, key = "S", message = "Start Screensaver" },
			keep_awake = { prefix = { "Option" }, key = "A", message = "Toggle Prevent Sleep" },
			restart = { prefix = { "Ctrl", "Option" }, key = "R", message = "Restart Computer" },
			shutdown = { prefix = { "Ctrl", "Option" }, key = "X", message = "Shutdown Computer" },
		},
		clipboard = {
			enabled = true,
			prefix = { "Option", "Shift" },
			key = "C",
			message = "Clipboard Center",
		},
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
		},
		key_caster = {
			toggle_hotkey = {
				prefix = { "Command", "Ctrl" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
		websites = {
			{ prefix = { "Option" }, key = "8", message = "github.com" },
		},
		apps = {
			{ prefix = { "Option" }, key = "C", message = "Chrome" },
			{ prefix = { "Option" }, key = "1", message = "Long App Launch Label For Second Column Width Check" },
		},
		window_position = {
			left = { prefix = { "Ctrl", "Option" }, key = "H", message = "Left Half of Screen" },
			right = { prefix = { "Ctrl", "Option" }, key = "L", message = "Right Half of Screen" },
			up = { prefix = { "Ctrl", "Option" }, key = "K", message = "Up Half of Screen" },
			down = { prefix = { "Ctrl", "Option" }, key = "J", message = "Down Half of Screen" },
			top_left = { prefix = { "Ctrl", "Option" }, key = "Y", message = "Top Left Corner" },
			top_right = { prefix = { "Ctrl", "Option" }, key = "O", message = "Top Right Corner" },
			bottom_left = { prefix = { "Ctrl", "Option" }, key = "U", message = "Bottom Left Corner" },
			bottom_right = { prefix = { "Ctrl", "Option" }, key = "I", message = "Bottom Right Corner" },
			left_1_3 = { prefix = { "Ctrl", "Option" }, key = "Q", message = "Left or Top 1/3" },
			right_1_3 = { prefix = { "Ctrl", "Option" }, key = "W", message = "Right or Bottom 1/3" },
			left_2_3 = { prefix = { "Ctrl", "Option" }, key = "E", message = "Left or Top 2/3" },
			right_2_3 = { prefix = { "Ctrl", "Option" }, key = "R", message = "Right or Bottom 2/3" },
		},
		window_movement = {
			to_up = { prefix = { "Ctrl", "Option", "Command" }, key = "K", message = "Move Upward" },
			to_down = { prefix = { "Ctrl", "Option", "Command" }, key = "J", message = "Move Downward" },
			to_left = { prefix = { "Ctrl", "Option", "Command" }, key = "H", message = "Move Leftward" },
			to_right = { prefix = { "Ctrl", "Option", "Command" }, key = "L", message = "Move Rightward" },
		},
		window_resize = {
			max = { prefix = { "Ctrl", "Option" }, key = "M", message = "Max Window" },
			stretch = { prefix = { "Ctrl", "Option" }, key = "=", message = "Stretch Outward" },
			shrink = { prefix = { "Ctrl", "Option" }, key = "-", message = "Shrink Inward" },
			stretch_up = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "K", message = "Bottom Side Stretch Upward" },
			stretch_down = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "J", message = "Bottom Side Stretch Downward" },
			stretch_left = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "H", message = "Right Side Stretch Leftward" },
			stretch_right = { prefix = { "Ctrl", "Option", "Command", "Shift" }, key = "L", message = "Right Side Stretch Rightward" },
		},
		window_monitor = {
			to_above_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Up", message = "Move to Above Screen" },
			to_below_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Down", message = "Move to Below Screen" },
			to_left_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Left", message = "Move to Left Screen" },
			to_right_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "Right", message = "Move to Right Screen" },
			to_next_screen = { prefix = { "Ctrl", "Option", "Command" }, key = "N", message = "Move to Next Screen" },
		},
		window_batch = {
			minimize_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "M", message = "Minimize All Windows" },
			un_minimize_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "U", message = "Unminimize All Windows" },
			close_all_windows = { prefix = { "Ctrl", "Option", "Command" }, key = "Q", message = "Close All Windows" },
		},
	}

	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(recorded)

	loaded_modules["utils_lib"] = {
		utf8len = function(text)
			return #tostring(text or "")
		end,
		utf8sub = function(text, start_char, num_chars)
			return tostring(text or ""):sub(start_char, start_char + num_chars - 1)
		end,
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
	}

	cheatsheet = require("keybindings_cheatsheet")
	assert_true(cheatsheet.start(), "cheatsheet should start successfully on a narrow screen")
	recorded.bound_handler()
	assert_true(recorded.canvas_frames[#recorded.canvas_frames].w <= 72, "cheatsheet canvas width should stay within the visible screen width with margins")

	cheatsheet.stop()

	reset_modules()

	recorded = {
		rendered_text = {},
		text_frames = {},
		segment_coordinates = {},
		canvas_frames = {},
		deleted_bindings = 0,
		bound_handler = nil,
		settings_store = {},
	}

	loaded_modules["keybindings_config"] = {
		keybindings_cheatsheet = {
			prefix = { "Option" },
			key = "/",
			message = "Cheatsheet",
		},
		manual_input_methods = {},
		system = {
			lock_screen = { prefix = { "Option" }, key = "Q", message = "Lock Screen" },
			screen_saver = { prefix = { "Option" }, key = "S", message = "Start Screensaver" },
			keep_awake = { prefix = { "Option" }, key = "A", message = "Toggle Prevent Sleep" },
			restart = { prefix = { "Ctrl", "Option" }, key = "R", message = "Restart Computer" },
			shutdown = { prefix = { "Ctrl", "Option" }, key = "X", message = "Shutdown Computer" },
		},
		clipboard = {
			enabled = false,
		},
		websites = {},
		apps = {},
		window_position = {},
		window_movement = {},
		window_resize = {},
		window_monitor = {},
		window_batch = {},
	}

	loaded_modules["hotkey_helper"] = {
		format_hotkey = create_hotkey_helper_stub(recorded).format_hotkey,
		normalize_hotkey_modifiers = function(modifiers)
			return modifiers or {}
		end,
		bind = function()
			return nil, "bind failed"
		end,
	}

	loaded_modules["utils_lib"] = {
		utf8len = function(text)
			return #tostring(text or "")
		end,
		utf8sub = function(text, start_char, num_chars)
			return tostring(text or ""):sub(start_char, start_char + num_chars - 1)
		end,
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
	}

	cheatsheet = require("keybindings_cheatsheet")
	assert_true(cheatsheet.start() == false, "cheatsheet should report startup failure when its toggle hotkey cannot be bound")

	reset_modules()
	hs = nil
end

return _M
