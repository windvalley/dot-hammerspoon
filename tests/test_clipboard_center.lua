local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

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

local function find_menu_item(menu, title)
	for _, item in ipairs(menu or {}) do
		if item.title == title then
			return item
		end
	end

	return nil
end

local function reset_modules()
	loaded_modules["clipboard_center"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		alerts = {},
		hotkey_bindings = {},
		prompt_values = { "control+shift", "x" },
		settings_store = {
			["clipboard_center.hotkey.modifiers"] = { "cmd" },
			["clipboard_center.hotkey.key"] = "v",
		},
		watcher_start_count = 0,
		deleted_binding_count = 0,
	}
	local current_clipboard_text = "seed clipboard text"

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
					d = function() end,
				}
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
		timer = {
			absoluteTime = function()
				return 42
			end,
			doEvery = function()
				return {
					stop = function() end,
				}
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
		geometry = {
			point = function(x, y)
				return { x = x, y = y }
			end,
		},
		chooser = {
			new = function()
				local state = {
					visible = false,
					query = nil,
					choices = {},
					selected_row = 0,
					show_callback = nil,
					hide_callback = nil,
					query_changed_callback = nil,
					right_click_callback = nil,
				}

				local chooser = {}

				function chooser.searchSubText(_) end
				function chooser.rows(_) end
				function chooser.width(_) end
				function chooser.placeholderText(_) end
				function chooser.showCallback(_, fn)
					state.show_callback = fn
				end
				function chooser.hideCallback(_, fn)
					state.hide_callback = fn
				end
				function chooser.queryChangedCallback(_, fn)
					state.query_changed_callback = fn
				end
				function chooser.rightClickCallback(_, fn)
					state.right_click_callback = fn
				end
				function chooser.choices(_, value)
					if value ~= nil then
						state.choices = value
					end

					return state.choices
				end
				function chooser.query(_, value)
					if value ~= nil then
						state.query = value
					end

					return state.query
				end
				function chooser.show(_)
					state.visible = true

					if state.show_callback ~= nil then
						state.show_callback()
					end
				end
				function chooser.hide(_)
					state.visible = false

					if state.hide_callback ~= nil then
						state.hide_callback()
					end
				end
				function chooser.delete(_) end
				function chooser.isVisible(_)
					return state.visible
				end
				function chooser.selectedRow(_, value)
					if value ~= nil then
						state.selected_row = value
					end

					return state.selected_row
				end
				function chooser.selectedRowContents(_, row)
					return state.choices[row or state.selected_row]
				end

				return chooser
			end,
		},
		menubar = {
			new = function()
				return {
					setIcon = function() end,
					setTitle = function(_, title)
						recorded.menubar_title = title
					end,
					setTooltip = function(_, tooltip)
						recorded.menubar_tooltip = tooltip
					end,
					setMenu = function(_, builder)
						recorded.menu_builder = builder
					end,
					delete = function()
						recorded.menubar_deleted = true
					end,
				}
			end,
		},
		canvas = {
			new = function()
				return {
					appendElements = function() end,
					imageFromCanvas = function()
						return {
							size = function() end,
							template = function() end,
						}
					end,
					delete = function() end,
				}
			end,
			windowLevels = {
				modalPanel = 1,
			},
		},
		pasteboard = {
			watcher = {
				new = function()
					return {
						start = function()
							recorded.watcher_start_count = recorded.watcher_start_count + 1
							return true
						end,
						stop = function() end,
					}
				end,
			},
			readImage = function()
				return nil
			end,
			getContents = function()
				return current_clipboard_text
			end,
			setContents = function()
				return true
			end,
			writeObjects = function()
				return true
			end,
		},
		host = {
			interfaceStyle = function()
				return "Light"
			end,
		},
		alert = {
			show = function(message)
				table.insert(recorded.alerts, message)
			end,
		},
		mouse = {
			absolutePosition = function()
				return { x = 0, y = 0 }
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		clipboard = {
			enabled = true,
			show_menubar = true,
			capture_images = false,
			prefix = { "Option", "Shift" },
			key = "C",
			message = "Clipboard Center",
			history_size = 10,
			menu_history_size = 5,
			chooser_rows = 8,
			chooser_width = 40,
		},
	}

	loaded_modules["hotkey_helper"] = {
		normalize_hotkey_modifiers = function(raw_modifiers)
			local modifier_order = {
				ctrl = 1,
				alt = 2,
				cmd = 3,
				shift = 4,
				fn = 5,
			}
			local aliases = {
				control = "ctrl",
				ctrl = "ctrl",
				option = "alt",
				opt = "alt",
				alt = "alt",
				command = "cmd",
				cmd = "cmd",
				shift = "shift",
				fn = "fn",
			}
			local modifiers = {}
			local seen = {}
			local values = {}

			if raw_modifiers == nil then
				return {}
			end

			if type(raw_modifiers) == "table" then
				values = raw_modifiers
			else
				for token in tostring(raw_modifiers):gmatch("[^,%+%s]+") do
					table.insert(values, token)
				end
			end

			for _, value in ipairs(values) do
				local normalized = aliases[string.lower(tostring(value))]

				if normalized == nil then
					return nil, value
				end

				if seen[normalized] ~= true then
					seen[normalized] = true
					table.insert(modifiers, normalized)
				end
			end

			table.sort(modifiers, function(left, right)
				return modifier_order[left] < modifier_order[right]
			end)

			return modifiers
		end,
		format_hotkey = function(modifiers, key)
			local parts = {}

			for _, modifier in ipairs(modifiers or {}) do
				table.insert(parts, modifier)
			end

			if key ~= nil and key ~= "" then
				table.insert(parts, key)
			end

			return table.concat(parts, "+")
		end,
		modifier_prompt_names = {
			ctrl = "ctrl",
			alt = "option",
			cmd = "command",
			shift = "shift",
			fn = "fn",
		},
		bind = function(modifiers, key, message, pressedfn)
			table.insert(recorded.hotkey_bindings, {
				modifiers = modifiers,
				key = key,
				message = message,
				pressedfn = pressedfn,
			})

			return {
				delete = function()
					recorded.deleted_binding_count = recorded.deleted_binding_count + 1
				end,
			}
		end,
	}

	loaded_modules["utils_lib"] = {
		trim = function(value)
			return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		end,
		utf8len = function(text)
			return #tostring(text or "")
		end,
		utf8sub = function(text, start_char, num_chars)
			return tostring(text or ""):sub(start_char, start_char + num_chars - 1)
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
		file_exists = function()
			return false
		end,
		ensure_directory = function()
			return true
		end,
		expand_home_path = function(path)
			return path
		end,
		prompt_text = function()
			return table.remove(recorded.prompt_values, 1)
		end,
	}

	local clipboard_center = require("clipboard_center")

	assert_true(clipboard_center.start(), "clipboard_center.start() should succeed")
	assert_equal(recorded.watcher_start_count, 1, "clipboard watcher should start on first module start")
	assert_equal(recorded.hotkey_bindings[1].key, "v", "persisted hotkey should be used during startup")
	assert_contains(recorded.menubar_tooltip, "快捷键: cmd+v", "tooltip should include persisted hotkey")
	assert_equal(recorded.settings_store["clipboard_center.history"][1].content, "seed clipboard text", "startup should sync current clipboard")

	local menu = recorded.menu_builder()
	local set_hotkey_item = find_menu_item(menu, "设置快捷键")

	assert_true(set_hotkey_item ~= nil, "menubar menu should expose hotkey settings")
	set_hotkey_item.fn()

	assert_equal(recorded.hotkey_bindings[#recorded.hotkey_bindings].key, "x", "updated hotkey should be rebound")
	assert_equal(recorded.settings_store["clipboard_center.hotkey.key"], "x", "updated hotkey key should persist")
	assert_equal(
		table.concat(recorded.settings_store["clipboard_center.hotkey.modifiers"], ","),
		"ctrl,shift",
		"updated modifiers should persist"
	)
	assert_true(recorded.deleted_binding_count >= 1, "previous hotkey binding should be deleted before rebinding")

	clipboard_center.stop()
	current_clipboard_text = "second clipboard text"
	recorded.settings_store["clipboard_center.history"] = nil
	assert_true(clipboard_center.start(), "clipboard_center.start() should support restart after stop")
	assert_equal(recorded.watcher_start_count, 2, "clipboard watcher should restart after stop/start")
	assert_equal(
		recorded.settings_store["clipboard_center.history"][1].content,
		"second clipboard text",
		"restart should resync current clipboard instead of reusing stale in-memory history"
	)

	clipboard_center.stop()
	reset_modules()
	hs = nil
end

return _M
