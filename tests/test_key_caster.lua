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
	loaded_modules["break_reminder"] = nil
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
		prompt_text = function()
			return nil
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
				imageFromCanvas = function()
					return {
						size = function(_, size)
							recorded.menubar_icon_size = size
						end,
						template = function(_, enabled)
							recorded.menubar_icon_template = enabled
						end,
					}
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
			recorded.menubar_visible = visible

			return {
				setMenu = function(_, builder)
					recorded.menu_builder = builder
				end,
				setTitle = function(_, title)
					recorded.menubar_title = title
				end,
				setIcon = function(_, icon)
					recorded.menubar_icon = icon
				end,
				setTooltip = function(_, tooltip)
					recorded.menubar_tooltip = tooltip
				end,
				autosaveName = function(_, name)
					recorded.menubar_autosave_name = name
				end,
				removeFromMenuBar = function()
					recorded.menubar_hidden = recorded.menubar_hidden + 1
					visible = false
					recorded.menubar_visible = false
				end,
				returnToMenuBar = function()
					recorded.menubar_shown = recorded.menubar_shown + 1
					visible = true
					recorded.menubar_visible = true
				end,
				isInMenuBar = function()
					return visible
				end,
				delete = function()
					recorded.menubar_deleted = recorded.menubar_deleted + 1
					visible = false
					recorded.menubar_visible = false
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
		bind = function(_, _, _, pressedfn, releasedfn)
			recorded.bound_handler = pressedfn or releasedfn

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
				prefix = { "Command", "Ctrl" },
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
		current_time_ns = 0,
		dialog_responses = { "恢复默认" },
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
		menubar_refresh_timers = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
		break_reminder_refresh_calls = 0,
		break_reminder_force_refreshes = {},
		settings_store = {},
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
		dialog = {
			blockAlert = function()
				return table.remove(recorded.dialog_responses, 1)
			end,
		},
		settings = {
			get = function(key)
				return recorded.settings_store[key]
			end,
			set = function(key, value)
				recorded.settings_store[key] = value
			end,
			clear = function(key)
				recorded.settings_store[key] = nil
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = create_canvas_stub(recorded),
		timer = {
			absoluteTime = function()
				return recorded.current_time_ns
			end,
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				if interval == 0 then
					table.insert(recorded.menubar_refresh_timers, timer)
				else
					table.insert(recorded.timers, timer)
				end

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
			display_mode = "single",
			toggle_hotkey = {
				prefix = { "Command", "Ctrl" },
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
	loaded_modules["break_reminder"] = {
		refresh_menubar = function(force_refresh)
			recorded.break_reminder_refresh_calls = recorded.break_reminder_refresh_calls + 1
			table.insert(recorded.break_reminder_force_refreshes, force_refresh)
		end,
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(recorded, false)

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "disabled key caster should still start successfully")
	assert_equal(recorded.eventtap_created, 0, "disabled key caster should not create event taps during startup")
	assert_equal(recorded.menubar_created, 1, "string true menubar config should be treated as always visible")
	assert_true(recorded.menubar_visible == true, "always visible menubar should be visible during startup")
	assert_true(type(recorded.bound_handler) == "function", "key caster toggle hotkey should be registered")
	assert_equal(recorded.break_reminder_refresh_calls, 1, "creating the key caster menubar should refresh the break reminder menubar")
	assert_true(recorded.break_reminder_force_refreshes[1] == true, "break reminder redraw should be forced after key caster menubar creation")
	assert_equal(key_caster.get_state().display_mode, "single", "default display mode should remain single-key overlay")

	recorded.bound_handler()

	assert_equal(recorded.eventtap_created, 1, "toggle hotkey should create one event tap when enabling key caster")
	assert_equal(recorded.eventtap_started, 1, "toggle hotkey should start the event tap when enabling key caster")
	assert_equal(recorded.menubar_created, 1, "always visible menubar should be reused after enabling key caster")
	assert_equal(recorded.menubar_autosave_name, "dot-hammerspoon.key_caster", "menubar should apply a stable autosave name")
	assert_true(recorded.menubar_icon ~= nil, "menubar should render a keyboard icon")
	assert_equal(recorded.menubar_title, nil, "menubar should clear the legacy text marker when an icon is available")
	assert_true(recorded.menubar_icon_template == true, "menubar icon should be rendered as a template image")
	assert_contains(recorded.alerts[#recorded.alerts], "按键显示已开启", "enabling key caster should show a status alert")
	assert_true(type(recorded.menu_builder) == "function", "menubar should expose a menu builder when visible")

	local menu = recorded.menu_builder()
	assert_true(find_menu_item(menu, "启用按键显示") ~= nil, "menubar should expose an enable toggle item")
	assert_true(find_menu_item(menu, "菜单栏图标") ~= nil, "menubar should expose a visibility management submenu")
	assert_true(find_menu_item(menu, "显示模式") ~= nil, "menubar should expose a display mode submenu")
	assert_true(find_menu_item(menu, "显示位置") ~= nil, "menubar should expose a position submenu")
	assert_true(find_menu_item(menu, "字体大小") ~= nil, "menubar should expose a font size submenu")
	assert_true(find_menu_item(menu, "停留时间") ~= nil, "menubar should expose a duration submenu")

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
	assert_equal(key_caster.get_state().position.anchor, "top_right", "runtime state should expose the current anchor")
	assert_equal(key_caster.get_state().font_size, 36, "runtime state should expose the current font size")
	assert_equal(key_caster.get_state().duration_seconds, 1.5, "runtime state should expose the current overlay duration")

	local position_menu = find_menu_item(menu, "显示位置").menu
	find_menu_item(position_menu, "顶部居中").fn()
	assert_equal(key_caster.get_state().position.anchor, "top_center", "position menu should update the runtime anchor")
	assert_equal(
		recorded.canvas_frames[#recorded.canvas_frames].x,
		math.floor(((1440 - recorded.canvas_frames[#recorded.canvas_frames].w) / 2) + 20),
		"changing the anchor from the menu should immediately rerender the current overlay"
	)
	assert_equal(
		recorded.settings_store["key_caster.runtime_overrides"].position.anchor,
		"top_center",
		"position changes made from the menu should be persisted"
	)

	local font_size_menu = find_menu_item(menu, "字体大小").menu
	find_menu_item(font_size_menu, "52 pt").fn()
	assert_equal(key_caster.get_state().font_size, 52, "font size menu should update the runtime font size")
	assert_equal(
		recorded.settings_store["key_caster.runtime_overrides"].font.size,
		52,
		"font size changes made from the menu should be persisted"
	)

	local duration_menu = find_menu_item(menu, "停留时间").menu
	find_menu_item(duration_menu, "3 秒").fn()
	assert_equal(key_caster.get_state().duration_seconds, 3, "duration menu should update the runtime overlay duration")
	assert_equal(recorded.timers[#recorded.timers].interval, 3, "changing duration from the menu should rerender with the new hide timer")
	assert_equal(
		recorded.settings_store["key_caster.runtime_overrides"].duration_seconds,
		3,
		"duration changes made from the menu should be persisted"
	)

	local display_mode_menu = find_menu_item(menu, "显示模式").menu
	find_menu_item(display_mode_menu, "连续拼接").fn()
	assert_equal(key_caster.get_state().display_mode, "sequence", "display mode changes made from the menu should update runtime state")
	assert_equal(
		recorded.settings_store["key_caster.runtime_overrides"].display_mode,
		"sequence",
		"display mode changes made from the menu should be persisted"
	)

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

	local restored_menu = recorded.menu_builder()
	find_menu_item(restored_menu, "恢复默认").fn()
	assert_equal(key_caster.get_state().position.anchor, "top_right", "restore defaults should recover the configured anchor")
	assert_equal(key_caster.get_state().font_size, 36, "restore defaults should recover the configured font size")
	assert_equal(key_caster.get_state().duration_seconds, 1.5, "restore defaults should recover the configured duration")
	assert_equal(key_caster.get_state().display_mode, "single", "restore defaults should recover the configured display mode")
	assert_equal(recorded.settings_store["key_caster.runtime_overrides"], nil, "restore defaults should clear persisted key caster menu overrides")

	key_caster.hide_menubar()
	assert_true(recorded.menubar_deleted >= 1, "hide_menubar should remove the menubar item when switching to never mode")
	assert_equal(recorded.break_reminder_refresh_calls, 2, "hiding the key caster menubar should refresh the break reminder menubar")
	assert_contains(recorded.alerts[#recorded.alerts], "已隐藏按键菜单栏图标", "hide_menubar should surface session-only visibility feedback")

	key_caster.show_menubar()
	assert_true(recorded.menubar_created >= 2, "show_menubar should recreate a visible menubar item after hiding it")
	assert_equal(recorded.break_reminder_refresh_calls, 3, "recreating the key caster menubar should refresh the break reminder menubar again")
	assert_contains(recorded.alerts[#recorded.alerts], "已切换为始终显示按键菜单栏图标", "show_menubar should surface visibility feedback")

	key_caster.auto_menubar()
	assert_contains(recorded.alerts[#recorded.alerts], "已切换为自动显示按键菜单栏图标", "auto_menubar should restore auto visibility mode")

	recorded.bound_handler()

	assert_equal(recorded.eventtap_stopped, 1, "toggle hotkey should stop the event tap when disabling key caster")
	assert_true(recorded.menubar_deleted >= 2, "auto menubar should remove the menubar item again after disabling key caster")
	assert_contains(recorded.alerts[#recorded.alerts], "按键显示已关闭", "disabling key caster should show a status alert")

	assert_true(key_caster.stop(), "stop should succeed")
	assert_true(recorded.deleted_canvases >= 2, "stop and redraw should clean up canvases")
	assert_true(recorded.timers[#recorded.timers].stopped, "stop should cancel pending hide timer")
	assert_true(recorded.deleted_bindings > 0, "stop should delete the toggle hotkey binding")

	reset_modules()

	local sequence_recorded = {
		alerts = {},
		current_time_ns = 0,
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
		menubar_refresh_timers = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
		break_reminder_refresh_calls = 0,
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
				table.insert(sequence_recorded.alerts, message)
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = create_canvas_stub(sequence_recorded),
		timer = {
			absoluteTime = function()
				return sequence_recorded.current_time_ns
			end,
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				if interval == 0 then
					table.insert(sequence_recorded.menubar_refresh_timers, timer)
				else
					table.insert(sequence_recorded.timers, timer)
				end

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
				[1] = "b",
				[2] = "c",
			},
		},
		menubar = create_menu_stub(sequence_recorded),
		eventtap = {
			event = {
				types = {
					keyDown = 10,
					flagsChanged = 12,
				},
			},
			new = function(_, callback)
				sequence_recorded.eventtap_created = sequence_recorded.eventtap_created + 1
				sequence_recorded.callback = callback

				return {
					start = function()
						sequence_recorded.eventtap_started = sequence_recorded.eventtap_started + 1
						return true
					end,
					stop = function()
						sequence_recorded.eventtap_stopped = sequence_recorded.eventtap_stopped + 1
					end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = false,
			show_menubar = false,
			display_mode = "sequence",
			sequence_window_seconds = 0.45,
			toggle_hotkey = {
				prefix = { "Command", "Ctrl" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
	}
	loaded_modules["break_reminder"] = {
		refresh_menubar = function()
			sequence_recorded.break_reminder_refresh_calls = sequence_recorded.break_reminder_refresh_calls + 1
		end,
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(sequence_recorded, false)

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "sequence mode should still start successfully")
	assert_equal(key_caster.get_state().display_mode, "sequence", "sequence mode should be reflected in runtime state")

	sequence_recorded.bound_handler()
	assert_equal(sequence_recorded.eventtap_started, 1, "sequence mode should start capture when enabled")

	sequence_recorded.current_time_ns = 0
	sequence_recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 0
		end,
		getFlags = function()
			return {}
		end,
	})
	assert_equal(sequence_recorded.rendered_text[#sequence_recorded.rendered_text], "A", "sequence mode should start with the first letter")

	sequence_recorded.current_time_ns = 200000000
	sequence_recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 1
		end,
		getFlags = function()
			return {}
		end,
	})
	assert_equal(sequence_recorded.rendered_text[#sequence_recorded.rendered_text], "AB", "sequence mode should append consecutive letters within the merge window")

	sequence_recorded.current_time_ns = 800000000
	sequence_recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 2
		end,
		getFlags = function()
			return {}
		end,
	})
	assert_equal(sequence_recorded.rendered_text[#sequence_recorded.rendered_text], "C", "sequence mode should reset after the merge window expires")

	sequence_recorded.current_time_ns = 900000000
	sequence_recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 0
		end,
		getFlags = function()
			return {
				cmd = true,
			}
		end,
	})
	assert_equal(sequence_recorded.rendered_text[#sequence_recorded.rendered_text], "⌘ A", "command shortcuts should still use the original single-key overlay rendering")

	sequence_recorded.current_time_ns = 950000000
	sequence_recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 1
		end,
		getFlags = function()
			return {}
		end,
	})
	assert_equal(sequence_recorded.rendered_text[#sequence_recorded.rendered_text], "B", "non-letter shortcuts should reset the sequence buffer before the next plain letter")

	assert_true(key_caster.stop(), "sequence mode stop should succeed")

	reset_modules()

	local auto_recorded = {
		alerts = {},
		current_time_ns = 0,
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
		menubar_refresh_timers = {},
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_hidden = 0,
		menubar_shown = 0,
		deleted_bindings = 0,
		break_reminder_refresh_calls = 0,
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
			absoluteTime = function()
				return auto_recorded.current_time_ns
			end,
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				if interval == 0 then
					table.insert(auto_recorded.menubar_refresh_timers, timer)
				else
					table.insert(auto_recorded.timers, timer)
				end

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
				prefix = { "Command", "Ctrl" },
				key = "K",
				message = "Toggle Key Caster",
			},
		},
	}
	loaded_modules["break_reminder"] = {
		refresh_menubar = function()
			auto_recorded.break_reminder_refresh_calls = auto_recorded.break_reminder_refresh_calls + 1
		end,
	}
	loaded_modules["utils_lib"] = create_utils_stub()
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(auto_recorded, false)

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "auto menubar mode should start successfully")
	assert_equal(auto_recorded.menubar_created, 0, "auto mode should not create a menubar item while disabled")
	assert_equal(auto_recorded.break_reminder_refresh_calls, 0, "auto mode should not refresh break reminder before the key caster menubar is created")

	auto_recorded.bound_handler()
	assert_equal(auto_recorded.menubar_created, 1, "auto mode should create the menubar item on first enable")
	assert_true(auto_recorded.menubar_visible == true, "auto mode should show the menubar item when enabling")
	assert_equal(auto_recorded.break_reminder_refresh_calls, 1, "first auto-mode menubar creation should refresh break reminder")

	auto_recorded.bound_handler()
	assert_equal(auto_recorded.menubar_deleted, 1, "auto mode should remove the menubar item again when disabled")
	assert_equal(auto_recorded.break_reminder_refresh_calls, 2, "auto-mode menubar deletion should refresh break reminder")

	auto_recorded.bound_handler()
	assert_equal(auto_recorded.menubar_created, 2, "auto mode should recreate the menubar item on the next enable")
	assert_true(auto_recorded.menubar_visible == true, "auto mode should make the recreated menubar item visible")
	assert_equal(auto_recorded.break_reminder_refresh_calls, 3, "recreating the auto-mode menubar should refresh break reminder again")

	auto_recorded.bound_handler()
	assert_equal(auto_recorded.menubar_deleted, 2, "auto mode should remove the recreated menubar item on repeated toggles")
	assert_equal(auto_recorded.break_reminder_refresh_calls, 4, "repeated auto-mode menubar deletion should keep refreshing break reminder")

	assert_true(key_caster.stop(), "stop should succeed in auto mode")

	reset_modules()
	hs = nil
end

return _M
