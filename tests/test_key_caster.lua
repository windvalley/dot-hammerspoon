local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

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

local function reset_modules()
	loaded_modules["key_caster"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
end

local function create_utils_stub()
	return {
		shallow_copy = function(value)
			local copied = {}

			for key, item in pairs(value or {}) do
				copied[key] = item
			end

			return copied
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
	}
end

local function create_canvas_stub(recorded)
	return {
		new = function(frame)
			local state = {
				frame = frame,
				deleted = false,
			}

			table.insert(recorded.canvas_frames, frame)

			return {
				appendElements = function(_, ...)
					for _, element in ipairs({ ... }) do
						if element.type == "text" then
							table.insert(recorded.rendered_text, tostring(element.text))
							table.insert(recorded.text_frames, element.frame)
						end
					end
				end,
				minimumTextSize = function(_, text)
					return {
						w = #tostring(text or "") * 12,
						h = 36,
					}
				end,
				level = function(_, level)
					recorded.levels[#recorded.levels + 1] = level
				end,
				show = function()
					recorded.shown = recorded.shown + 1
				end,
				delete = function()
					if state.deleted ~= true then
						state.deleted = true
						recorded.deleted_canvases = recorded.deleted_canvases + 1
					end
				end,
			}
		end,
		windowLevels = {
			overlay = 9,
		},
	}
end

local function create_menu_stub(recorded)
	return {
		new = function(in_menu_bar)
			recorded.menubar_created = recorded.menubar_created + 1
			local visible = in_menu_bar ~= false

			return {
				setMenu = function(_, builder)
					recorded.menu_builder = builder
				end,
				setTitle = function(_, title)
					recorded.menubar_title = title
				end,
				setTooltip = function(_, tooltip)
					recorded.menubar_tooltip = tooltip
				end,
				removeFromMenuBar = function()
					recorded.menubar_hidden = recorded.menubar_hidden + 1
					visible = false
				end,
				returnToMenuBar = function()
					recorded.menubar_shown = recorded.menubar_shown + 1
					visible = true
				end,
				isInMenuBar = function()
					return visible
				end,
				delete = function()
					recorded.menubar_deleted = recorded.menubar_deleted + 1
				end,
			}
		end,
	}
end

local function create_hotkey_helper_stub(recorded, should_fail)
	return {
		normalize_hotkey_modifiers = function(modifiers)
			return modifiers or {}
		end,
		format_hotkey = function(modifiers, key)
			local parts = {}

			for _, modifier in ipairs(modifiers or {}) do
				table.insert(parts, tostring(modifier))
			end

			if key ~= nil then
				table.insert(parts, tostring(key))
			end

			return table.concat(parts, "+")
		end,
		bind = function(_, _, _, pressedfn)
			recorded.bound_handler = pressedfn

			if should_fail == true then
				return nil, "bind failed"
			end

			return {
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
				end,
			}
		end,
	}
end

local function find_menu_item(menu, title)
	for _, item in ipairs(menu or {}) do
		if item.title == title then
			return item
		end
	end

	return nil
end

function _M.run()
	reset_modules()

	local recovery_recorded = {
		alerts = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(recovery_recorded.alerts, message)
			end,
		},
		menubar = create_menu_stub(recovery_recorded),
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = false,
			show_menubar = false,
			toggle_hotkey = {
				prefix = { "Ctrl", "Option", "Shift" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(recovery_recorded, true)

	local key_caster = require("key_caster")

	assert_true(key_caster.start(), "module should still start when key caster hotkey binding fails")
	assert_equal(recovery_recorded.menubar_created, 1, "hotkey binding failure should force-create a menubar recovery entry")
	assert_contains(recovery_recorded.alerts[#recovery_recorded.alerts], "按键显示快捷键绑定失败", "startup should surface hotkey binding failure")
	assert_contains(recovery_recorded.alerts[#recovery_recorded.alerts], "已临时显示菜单栏图标", "startup should expose a temporary recovery entry")
	assert_true(key_caster.stop(), "stop should succeed after hotkey binding failure")
	assert_equal(recovery_recorded.menubar_deleted, 1, "stop should delete the temporary recovery menubar item")

	reset_modules()

	local recorded = {
		alerts = {},
		eventtap_created = 0,
		eventtap_started = 0,
		eventtap_stopped = 0,
		rendered_text = {},
		text_frames = {},
		canvas_frames = {},
		levels = {},
		shown = 0,
		deleted_canvases = 0,
		timers = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(recorded.alerts, message)
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = create_canvas_stub(recorded),
		timer = {
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				table.insert(recorded.timers, timer)

				return timer
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
		keycodes = {
			map = {
				[0] = "a",
				[55] = "cmd",
				[56] = "shift",
			},
		},
		menubar = create_menu_stub(recorded),
		eventtap = {
			event = {
				types = {
					keyDown = 10,
					flagsChanged = 12,
				},
			},
			new = function(_, callback)
				recorded.eventtap_created = recorded.eventtap_created + 1
				recorded.callback = callback

				return {
					start = function()
						recorded.eventtap_started = recorded.eventtap_started + 1
						return true
					end,
					stop = function()
						recorded.eventtap_stopped = recorded.eventtap_stopped + 1
					end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = false,
			show_menubar = "true",
			toggle_hotkey = {
				prefix = { "Ctrl", "Option", "Shift" },
				key = "K",
				message = "Toggle Key Caster",
			},
			position = {
				anchor = "top_right",
				offset_x = 20,
				offset_y = 30,
			},
			font = {
				name = "Monaco",
				size = 36,
			},
			text_color = {
				hex = "#FFFFFF",
				alpha = 1,
			},
			background_color = {
				hex = "#000000",
				alpha = 0.6,
			},
			duration_seconds = 1.5,
		},
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(recorded, false)

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "disabled key caster should still start successfully")
	assert_equal(recorded.eventtap_created, 0, "disabled key caster should not create event taps during startup")
	assert_equal(recorded.menubar_created, 1, "string true menubar config should be treated as always visible")
	assert_true(recorded.menubar_shown >= 1, "always visible menubar should be shown during startup")
	assert_true(type(recorded.bound_handler) == "function", "key caster toggle hotkey should be registered")

	recorded.bound_handler()

	assert_equal(recorded.eventtap_created, 1, "toggle hotkey should create one event tap when enabling key caster")
	assert_equal(recorded.eventtap_started, 1, "toggle hotkey should start the event tap when enabling key caster")
	assert_equal(recorded.menubar_created, 1, "always visible menubar should be reused after enabling key caster")
	assert_contains(recorded.alerts[#recorded.alerts], "按键显示已开启", "enabling key caster should show a status alert")
	assert_true(type(recorded.menu_builder) == "function", "menubar should expose a menu builder when visible")

	local menu = recorded.menu_builder()
	assert_true(find_menu_item(menu, "启用按键显示") ~= nil, "menubar should expose an enable toggle item")
	assert_true(find_menu_item(menu, "菜单栏图标") ~= nil, "menubar should expose a visibility management submenu")

	recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 0
		end,
		getFlags = function()
			return {
				cmd = true,
				shift = true,
			}
		end,
	})

	assert_equal(recorded.rendered_text[#recorded.rendered_text], "⌘ ⇧ A", "keyDown should render modifier combo and key")
	assert_equal(recorded.canvas_frames[#recorded.canvas_frames].y, 30, "top_right anchor should honor y offset")
	assert_equal(
		recorded.canvas_frames[#recorded.canvas_frames].x,
		1440 - recorded.canvas_frames[#recorded.canvas_frames].w - 20,
		"top_right anchor should honor x offset"
	)
	assert_equal(recorded.timers[#recorded.timers].interval, 1.5, "timer should use configured duration")

	recorded.callback({
		getType = function()
			return hs.eventtap.event.types.flagsChanged
		end,
		getKeyCode = function()
			return 55
		end,
		getFlags = function()
			return {
				cmd = true,
			}
		end,
	})

	assert_equal(recorded.rendered_text[#recorded.rendered_text], "⌘", "flagsChanged should render standalone modifier keys")
	assert_true(recorded.timers[1].stopped, "new keystroke should stop previous hide timer")

	key_caster.hide_menubar()
	assert_true(recorded.menubar_hidden >= 1, "hide_menubar should hide the menubar item from the system menu bar")
	assert_contains(recorded.alerts[#recorded.alerts], "已隐藏按键菜单栏图标", "hide_menubar should surface session-only visibility feedback")

	key_caster.show_menubar()
	assert_true(recorded.menubar_shown >= 2, "show_menubar should return the hidden menubar item back to the system menu bar")
	assert_contains(recorded.alerts[#recorded.alerts], "已切换为始终显示按键菜单栏图标", "show_menubar should surface visibility feedback")

	key_caster.auto_menubar()
	assert_contains(recorded.alerts[#recorded.alerts], "已切换为自动显示按键菜单栏图标", "auto_menubar should restore auto visibility mode")

	recorded.bound_handler()

	assert_equal(recorded.eventtap_stopped, 1, "toggle hotkey should stop the event tap when disabling key caster")
	assert_true(recorded.menubar_hidden >= 2, "auto menubar should hide the menubar item again after disabling key caster")
	assert_contains(recorded.alerts[#recorded.alerts], "按键显示已关闭", "disabling key caster should show a status alert")

	assert_true(key_caster.stop(), "stop should succeed")
	assert_true(recorded.deleted_canvases >= 2, "stop and redraw should clean up canvases")
	assert_true(recorded.timers[#recorded.timers].stopped, "stop should cancel pending hide timer")
	assert_true(recorded.deleted_bindings > 0, "stop should delete the toggle hotkey binding")

	reset_modules()

	local auto_recorded = {
		alerts = {},
		eventtap_created = 0,
		eventtap_started = 0,
		eventtap_stopped = 0,
		rendered_text = {},
		text_frames = {},
		canvas_frames = {},
		levels = {},
		shown = 0,
		deleted_canvases = 0,
		timers = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(auto_recorded.alerts, message)
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = create_canvas_stub(auto_recorded),
		timer = {
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				table.insert(auto_recorded.timers, timer)

				return timer
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
		keycodes = {
			map = {
				[0] = "a",
			},
		},
		menubar = create_menu_stub(auto_recorded),
		eventtap = {
			event = {
				types = {
					keyDown = 10,
					flagsChanged = 12,
				},
			},
			new = function(_, callback)
				auto_recorded.eventtap_created = auto_recorded.eventtap_created + 1
				auto_recorded.callback = callback

				return {
					start = function()
						auto_recorded.eventtap_started = auto_recorded.eventtap_started + 1
						return true
					end,
					stop = function()
						auto_recorded.eventtap_stopped = auto_recorded.eventtap_stopped + 1
					end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = false,
			show_menubar = "auto",
			toggle_hotkey = {
				prefix = { "Ctrl", "Option", "Shift" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(auto_recorded, false)

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "auto menubar mode should start successfully")
	assert_equal(auto_recorded.menubar_created, 1, "auto mode should create a reusable hidden menubar item while disabled")
	assert_equal(auto_recorded.menubar_hidden, 0, "auto mode should keep the menubar hidden while disabled")

	auto_recorded.bound_handler()
	assert_true(auto_recorded.menubar_shown >= 1, "auto mode should return the hidden menubar item to the system menu bar when enabling")

	auto_recorded.bound_handler()
	assert_true(auto_recorded.menubar_hidden >= 1, "auto mode should hide the menubar item again when disabled")

	auto_recorded.bound_handler()
	assert_true(auto_recorded.menubar_shown >= 2, "auto mode should show the same menubar item on the next enable")

	auto_recorded.bound_handler()
	assert_true(auto_recorded.menubar_hidden >= 2, "auto mode should only hide its own menubar item on repeated toggles")

	assert_true(key_caster.stop(), "stop should succeed in auto mode")

	reset_modules()
	hs = nil
end

return _M
