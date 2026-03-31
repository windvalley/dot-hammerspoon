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

local function first_choice_by_source(choices, source)
	for _, choice in ipairs(choices or {}) do
		if choice.source == source then
			return choice
		end
	end

	return nil
end

local function preview_contains_text(elements, expected)
	for _, element in ipairs(elements or {}) do
		if tostring(element.text or ""):find(expected, 1, true) ~= nil then
			return true
		end
	end

	return false
end

local function reset_modules()
	loaded_modules["snippet_center"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
	loaded_modules["clipboard_center"] = nil
end

function _M.run()
	reset_modules()

	local original_remove = os.remove
	local original_rename = os.rename
	local original_io_open = io.open

	local recorded = {
		alerts = {},
		hotkey_bindings = {},
		deleted_binding_count = 0,
		settings_store = {},
		pasteboard_sets = {},
		auto_paste_keystrokes = {},
		do_after_delays = {},
		suspend_capture_calls = {},
		frontmost_app_activations = 0,
		prompt_values = {
			"ctrl+option",
			"K",
			"command+shift",
			"J",
			"Renamed Title",
		},
		chooser = nil,
		last_popup_menu = nil,
		editor_message_handler = nil,
		editor_html = nil,
		menubar_created = 0,
		menubar_deleted = 0,
		menubar_menu_builder = nil,
		preview_deleted = false,
		ensured_directories = {},
		renamed_paths = {},
		removed_paths = {},
	}
	local current_clipboard_text = "First snippet\nLine two"
	local fake_files = {}
	local home_path = "/Users/tester"
	local configured_storage_path = home_path .. "/.hammerspoon/data/snippets-test.json"

	rawset(os, "remove", function(path)
		table.insert(recorded.removed_paths, path)
		fake_files[path] = nil
		return true
	end)

	rawset(os, "rename", function(from_path, to_path)
		table.insert(recorded.renamed_paths, {
			from = from_path,
			to = to_path,
		})

		if fake_files[from_path] == nil then
			return nil, "missing source"
		end

		fake_files[to_path] = fake_files[from_path]
		fake_files[from_path] = nil
		return true
	end)

	rawset(io, "open", function(path, mode)
		if mode == "r" then
			if fake_files[path] == nil then
				return nil, "missing file"
			end

			return {
				read = function(_, pattern)
					if pattern == "*a" then
						return fake_files[path]
					end

					return nil
				end,
				close = function()
					return true
				end,
			}
		end

		if mode == "w" then
			local buffer = {}

			return {
				write = function(_, content)
					table.insert(buffer, tostring(content or ""))
					return true
				end,
				close = function()
					fake_files[path] = table.concat(buffer)
					return true
				end,
			}
		end

		return nil, "unsupported mode"
	end)

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
		json = {
			encode = function(payload)
				local items = {}

				for _, item in ipairs((payload or {}).items or {}) do
					table.insert(items, string.format(
						'{"id":"%s","title":"%s","content":"%s","pinned":%s,"created_at":%d,"updated_at":%d,"last_used_at":%d,"use_count":%d}',
						tostring(item.id or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"),
						tostring(item.title or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"),
						tostring(item.content or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"),
						item.pinned == true and "true" or "false",
						tonumber(item.created_at) or 0,
						tonumber(item.updated_at) or 0,
						tonumber(item.last_used_at) or 0,
						tonumber(item.use_count) or 0
					))
				end

				return string.format('{"version":%d,"items":[%s]}', tonumber(payload.version) or 1, table.concat(items, ","))
			end,
			decode = function()
				error("decode should not be called in this test")
			end,
		},
		timer = {
			doAfter = function(delay, fn)
				table.insert(recorded.do_after_delays, delay)

				if fn ~= nil then
					fn()
				end

				return {
					stop = function() end,
				}
			end,
			doEvery = function(interval, fn)
				recorded.preview_timer_interval = interval
				recorded.preview_timer_callback = fn

				return {
					stop = function()
						recorded.preview_timer_stopped = true
					end,
				}
			end,
		},
		pasteboard = {
			getContents = function()
				return current_clipboard_text
			end,
			setContents = function(value)
				current_clipboard_text = value
				table.insert(recorded.pasteboard_sets, value)
				return true
			end,
			readAllData = function()
				return nil
			end,
			readImage = function()
				return nil
			end,
			clearContents = function()
				current_clipboard_text = nil
				return true
			end,
		},
		eventtap = {
			keyStroke = function(modifiers, key, delay)
				table.insert(recorded.auto_paste_keystrokes, {
					modifiers = modifiers,
					key = key,
					delay = delay,
				})
			end,
			leftClick = function(point, delay)
				recorded.editor_click_point = point
				recorded.editor_click_delay = delay
			end,
		},
		application = {
			frontmostApplication = function()
				return {
					activate = function()
						recorded.frontmost_app_activations = recorded.frontmost_app_activations + 1
						return true
					end,
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
			new = function(choice_callback)
				local state = {
					visible = false,
					query = nil,
					choices = {},
					selected_row = 0,
					show_callback = nil,
					hide_callback = nil,
					query_changed_callback = nil,
					right_click_callback = nil,
					choice_callback = choice_callback,
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
				function chooser.query(_, ...)
					if select("#", ...) > 0 then
						state.query = select(1, ...)

						if state.query_changed_callback ~= nil then
							state.query_changed_callback()
						end
					end

					return state.query
				end
				function chooser.show(_, point)
					state.visible = true
					recorded.chooser_point = point

					if state.show_callback ~= nil then
						state.show_callback()
					end
				end
				function chooser.hide(_)
					state.visible = false
					recorded.chooser_hide_count = (recorded.chooser_hide_count or 0) + 1

					if state.hide_callback ~= nil then
						state.hide_callback()
					end
				end
				function chooser.delete(_)
					recorded.chooser_deleted = true
				end
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
				function chooser.selectChoice(_, choice)
					if state.choice_callback ~= nil then
						state.choice_callback(choice)
					end
				end
				function chooser.rightClick(_, row)
					if state.right_click_callback ~= nil then
						state.right_click_callback(row)
					end
				end

				recorded.chooser = chooser

				return chooser
			end,
		},
		menubar = {
			new = function(in_menu_bar)
				if in_menu_bar == false then
					return {
						setMenu = function(_, menu)
							recorded.last_popup_menu = menu
						end,
						popupMenu = function() end,
						delete = function() end,
					}
				end

				recorded.menubar_created = recorded.menubar_created + 1

				return {
					setMenu = function(_, menu)
						recorded.menubar_menu_builder = menu
					end,
					setTitle = function(_, title)
						recorded.menubar_title = title
					end,
					setTooltip = function(_, tooltip)
						recorded.menubar_tooltip = tooltip
					end,
					delete = function()
						recorded.menubar_deleted = recorded.menubar_deleted + 1
					end,
				}
			end,
		},
		canvas = {
			windowLevels = {
				modalPanel = 1,
			},
			new = function(frame)
				local state = {
					frame = frame,
					showing = false,
				}

				return {
					level = function(_, value)
						recorded.preview_level = value
					end,
					clickActivating = function(_, value)
						recorded.preview_click_activating = value
					end,
					frame = function(_, value)
						if value ~= nil then
							state.frame = value
							recorded.preview_frame = value
						end

						return state.frame
					end,
					replaceElements = function(_, ...)
						recorded.preview_last_elements = { ... }
					end,
					show = function(_, duration)
						state.showing = true
						recorded.preview_show_duration = duration
						recorded.preview_show_count = (recorded.preview_show_count or 0) + 1
					end,
					hide = function(_, duration)
						state.showing = false
						recorded.preview_hide_duration = duration
						recorded.preview_hide_count = (recorded.preview_hide_count or 0) + 1
					end,
					isShowing = function()
						return state.showing
					end,
					delete = function()
						recorded.preview_deleted = true
					end,
				}
			end,
		},
		mouse = {
			absolutePosition = function(position)
				if position ~= nil then
					recorded.mouse_position = position
				end

				return recorded.mouse_position or { x = 0, y = 0 }
			end,
		},
		webview = {
			usercontent = {
				new = function(port_name)
					recorded.editor_port_name = port_name

					return {
						setCallback = function(_, callback)
							recorded.editor_message_handler = callback
						end,
					}
				end,
			},
			new = function(_, _, _)
				local state = {
					window_callback = nil,
					deleted = false,
				}
				local window = {
					focus = function()
						recorded.editor_focus_count = (recorded.editor_focus_count or 0) + 1
					end,
				}

				return {
					windowTitle = function(_, value)
						recorded.editor_title = value
					end,
					allowTextEntry = function() end,
					allowNewWindows = function() end,
					allowGestures = function() end,
					closeOnEscape = function() end,
					deleteOnClose = function() end,
					shadow = function() end,
					transparent = function() end,
					windowStyle = function(_, value)
						recorded.editor_window_style = value
					end,
					behaviorAsLabels = function(_, labels)
						recorded.editor_behaviors = labels
					end,
					windowCallback = function(_, callback)
						state.window_callback = callback
					end,
					navigationCallback = function(_, callback)
						recorded.editor_navigation_callback = callback
					end,
					html = function(_, html)
						recorded.editor_html = html
						if recorded.editor_navigation_callback ~= nil then
							recorded.editor_navigation_callback(nil, "didFinishNavigation")
						end
					end,
					show = function()
						recorded.editor_show_count = (recorded.editor_show_count or 0) + 1
					end,
					bringToFront = function() end,
					hswindow = function()
						return window
					end,
					evaluateJavaScript = function(_, script)
						recorded.editor_last_script = script
					end,
					frame = function()
						return { x = 100, y = 120, w = 600, h = 420 }
					end,
					delete = function()
						if state.deleted ~= true then
							state.deleted = true

							if state.window_callback ~= nil then
								state.window_callback("closing")
							end
						end
					end,
					hide = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(recorded.alerts, message)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		snippets = {
			enabled = true,
			storage_path = "~/.hammerspoon/data/snippets-test.json",
			max_items = 20,
			max_content_length = 20000,
			chooser_rows = 8,
			chooser_width = 40,
			auto_paste = true,
			restore_clipboard_after_paste = true,
			show_menubar = true,
			menu_items = 4,
			preview_enabled = true,
			preview_width = 420,
			preview_height = 320,
			preview_poll_interval = 0.08,
			preview_body_max_chars = 6000,
			auto_title_length = 36,
			editor = {
				width = 600,
				height = 420,
			},
			prefix = { "Option", "Shift" },
			key = "S",
			message = "Snippet Center",
			quick_save = {
				prefix = { "Option", "Shift", "Command" },
				key = "S",
				message = "Quick Save Snippet",
			},
		},
	}

	loaded_modules["hotkey_helper"] = {
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
		modifier_prompt_names = {
			ctrl = "ctrl",
			alt = "option",
			cmd = "command",
			shift = "shift",
			fn = "fn",
		},
		format_hotkey = function(modifiers, key)
			local symbols = {
				ctrl = "⌃",
				alt = "⌥",
				cmd = "⌘",
				shift = "⇧",
				fn = "fn",
			}
			local parts = {}

			for _, modifier in ipairs(modifiers or {}) do
				table.insert(parts, symbols[modifier] or tostring(modifier))
			end

			table.insert(parts, string.upper(tostring(key or "")))
			return table.concat(parts, " ")
		end,
		normalize_hotkey_modifiers = function(raw_modifiers)
			local values = {}
			local normalized = {}
			local seen = {}
			local aliases = {
				ctrl = "ctrl",
				control = "ctrl",
				option = "alt",
				alt = "alt",
				opt = "alt",
				command = "cmd",
				cmd = "cmd",
				shift = "shift",
				fn = "fn",
			}
			local order = {
				ctrl = 1,
				alt = 2,
				cmd = 3,
				shift = 4,
				fn = 5,
			}

			if raw_modifiers == nil then
				return {}
			end

			if type(raw_modifiers) == "table" then
				values = raw_modifiers
			else
				for token in string.gmatch(tostring(raw_modifiers), "[^,%+%s]+") do
					table.insert(values, token)
				end
			end

			for _, raw_value in ipairs(values) do
				local token = tostring(raw_value):lower()

				if token ~= "" then
					local modifier = aliases[token]

					if modifier == nil then
						return nil, raw_value
					end

					if seen[modifier] ~= true then
						seen[modifier] = true
						table.insert(normalized, modifier)
					end
				end
			end

			table.sort(normalized, function(left, right)
				return order[left] < order[right]
			end)

			return normalized
		end,
	}

	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
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
		file_exists = function(path)
			return fake_files[path] ~= nil
		end,
		ensure_directory = function(path)
			table.insert(recorded.ensured_directories, path)
			return true
		end,
		expand_home_path = function(path)
			if path == "~/.hammerspoon/data/snippets-test.json" then
				return configured_storage_path
			end

			if path == "~/.hammerspoon/data" then
				return home_path .. "/.hammerspoon/data"
			end

			if tostring(path):sub(1, 2) == "~/" then
				return home_path .. tostring(path):sub(2)
			end

			return path
		end,
		prompt_text = function()
			return table.remove(recorded.prompt_values, 1)
		end,
	}

	loaded_modules["clipboard_center"] = {
		suspend_capture = function(seconds)
			table.insert(recorded.suspend_capture_calls, seconds)
		end,
	}

	local snippet_center = require("snippet_center")

	assert_true(snippet_center.start(), "snippet_center.start() should succeed")
	assert_equal(#recorded.hotkey_bindings, 2, "module should bind chooser and quick save hotkeys")
	assert_equal(recorded.hotkey_bindings[1].key, "s", "chooser hotkey should come from config")
	assert_equal(recorded.hotkey_bindings[2].key, "s", "quick save hotkey should come from config")
	assert_equal(recorded.menubar_created, 1, "snippet center should create a menubar item when configured")
	assert_equal(recorded.menubar_title, "Snip", "snippet center menubar should expose a stable title")
	assert_true(snippet_center.get_state().menubar_exists == true, "menubar should exist after startup when enabled")
	assert_equal(snippet_center.get_state().storage_path, configured_storage_path, "snippet center should expand the configured storage path")

	local quick_save_ok = snippet_center.quick_save_clipboard()
	assert_true(quick_save_ok == true, "quick save should persist current clipboard text as a snippet")
	assert_equal(snippet_center.get_state().item_count, 1, "quick save should create one snippet")
	assert_contains(fake_files[configured_storage_path], "First snippet\\nLine two", "saved snippet should persist its content in the storage file")
	assert_equal(recorded.ensured_directories[1], home_path .. "/.hammerspoon/data", "saving snippets should ensure the parent directory exists")
	assert_equal(recorded.renamed_paths[1].from, configured_storage_path .. ".tmp", "snippet persistence should write through a temp file")
	assert_equal(recorded.renamed_paths[1].to, configured_storage_path, "snippet persistence should atomically rename the temp file")

	local menubar_menu = recorded.menubar_menu_builder()
	local open_chooser_item = find_menu_item(menubar_menu, "打开 Chooser")
	assert_true(open_chooser_item ~= nil, "menubar should expose the chooser action")
	assert_true(find_menu_item(menubar_menu, "打开快捷键: ⌥ ⇧ S") ~= nil, "menubar should display the chooser hotkey")
	assert_true(find_menu_item(menubar_menu, "快速保存快捷键: ⌥ ⌘ ⇧ S") ~= nil, "menubar should display the quick save hotkey")
	local auto_paste_item = find_menu_item(menubar_menu, "自动粘贴")
	assert_true(auto_paste_item ~= nil, "menubar should expose the auto paste toggle")
	assert_true(auto_paste_item.checked == true, "auto paste should default to enabled in the menubar")
	local hotkey_menu_item = find_menu_item(menubar_menu, "快捷键")
	assert_true(hotkey_menu_item ~= nil, "menubar should expose hotkey settings")
	assert_true(type(hotkey_menu_item.menu) == "table", "hotkey settings should use a submenu")
	assert_true(find_menu_item(hotkey_menu_item.menu, "设置打开快捷键") ~= nil, "hotkey submenu should expose open-hotkey configuration")
	assert_true(find_menu_item(hotkey_menu_item.menu, "设置快速保存快捷键") ~= nil, "hotkey submenu should expose quick-save-hotkey configuration")
	local snippet_menu_item = find_menu_item(menubar_menu, "First snippet")
	assert_true(snippet_menu_item ~= nil, "menubar should expose recently saved snippets")
	assert_true(type(snippet_menu_item.menu) == "table", "snippet menubar entry should open a management submenu")
	assert_true(find_menu_item(snippet_menu_item.menu, "编辑...") ~= nil, "snippet submenu should expose edit action")
	find_menu_item(hotkey_menu_item.menu, "设置打开快捷键").fn()
	assert_equal(snippet_center.get_state().open_hotkey_label, "⌃ ⌥ K", "menubar should allow changing the chooser hotkey")
	assert_equal(recorded.settings_store["snippet_center.hotkey.open.key"], "k", "open hotkey override should be persisted")
	assert_equal(recorded.settings_store["snippet_center.hotkey.open.modifiers"][1], "ctrl", "open hotkey modifiers should be persisted")
	assert_equal(recorded.settings_store["snippet_center.hotkey.open.modifiers"][2], "alt", "open hotkey modifier order should be normalized")
	find_menu_item(hotkey_menu_item.menu, "设置快速保存快捷键").fn()
	assert_equal(snippet_center.get_state().quick_save_hotkey_label, "⌘ ⇧ J", "menubar should allow changing the quick save hotkey")
	assert_equal(recorded.settings_store["snippet_center.hotkey.quick_save.key"], "j", "quick save hotkey override should be persisted")
	assert_equal(recorded.settings_store["snippet_center.hotkey.quick_save.modifiers"][1], "cmd", "quick save modifiers should be persisted")
	assert_equal(recorded.settings_store["snippet_center.hotkey.quick_save.modifiers"][2], "shift", "quick save modifier order should be normalized")
	assert_equal(#recorded.hotkey_bindings, 4, "changing both snippet hotkeys should rebind both actions")
	menubar_menu = recorded.menubar_menu_builder()
	assert_true(find_menu_item(menubar_menu, "打开快捷键: ⌃ ⌥ K") ~= nil, "menubar should refresh the chooser hotkey label after reconfiguration")
	assert_true(find_menu_item(menubar_menu, "快速保存快捷键: ⌘ ⇧ J") ~= nil, "menubar should refresh the quick save hotkey label after reconfiguration")
	auto_paste_item.fn()
	assert_true(snippet_center.get_state().auto_paste == false, "menubar toggle should update runtime auto paste state")
	assert_equal(recorded.settings_store["snippet_center.auto_paste"], false, "menubar toggle should persist auto paste override")
	menubar_menu = recorded.menubar_menu_builder()
	auto_paste_item = find_menu_item(menubar_menu, "自动粘贴")
	assert_true(auto_paste_item.checked ~= true, "menubar should reflect updated auto paste state")
	auto_paste_item.fn()
	assert_true(snippet_center.get_state().auto_paste == true, "second menubar toggle should restore auto paste")
	assert_equal(recorded.settings_store["snippet_center.auto_paste"], nil, "restoring default auto paste should clear the override")

	local duplicate_ok = snippet_center.quick_save_clipboard()
	assert_true(duplicate_ok == false, "duplicate quick save should be rejected")
	assert_contains(recorded.alerts[#recorded.alerts], "已存在相同内容", "duplicate quick save should explain why it failed")

	snippet_center.show_chooser()
	local choices = recorded.chooser:choices()
	assert_equal(choices[1].source, "action", "first chooser row should be the create action")
	assert_equal(choices[2].source, "action", "second chooser row should be the clipboard create action")
	assert_equal(choices[3].source, "snippet", "saved snippet should appear after action rows")
	assert_equal(choices[3].text, "First snippet", "snippet with empty title should use first content line as display title")
	assert_true(snippet_center.get_state().preview_exists == true, "showing chooser should create the preview canvas when enabled")
	assert_equal(recorded.preview_timer_interval, 0.08, "snippet preview should honor the configured poll interval")
	assert_true(preview_contains_text(recorded.preview_last_elements, "新建空白片段"), "preview should render the currently selected chooser action")
	recorded.chooser:selectedRow(3)
	recorded.preview_timer_callback()
	assert_true(preview_contains_text(recorded.preview_last_elements, "First snippet\nLine two"), "preview should render the selected snippet body")
	assert_true(preview_contains_text(recorded.preview_last_elements, "2 行"), "preview should render snippet metadata")

	recorded.chooser:rightClick(3)
	local rename_item = find_menu_item(recorded.last_popup_menu, "重命名...")
	assert_true(rename_item ~= nil, "snippet row context menu should expose rename action")
	rename_item.fn()
	assert_equal(snippet_center.get_state().items[1].title, "Renamed Title", "rename should update stored title")

	recorded.chooser:rightClick(3)
	local edit_item = find_menu_item(recorded.last_popup_menu, "编辑...")
	assert_true(edit_item ~= nil, "snippet row context menu should expose edit action")
	edit_item.fn()
	assert_true(snippet_center.get_state().editor_exists == true, "edit action should open the snippet editor")
	assert_contains(recorded.editor_html, "Renamed Title", "editor html should receive the current snippet title")
	assert_true((recorded.chooser_hide_count or 0) >= 1, "opening editor should hide chooser first")
	assert_true((recorded.preview_hide_count or 0) >= 1, "hiding chooser for editor should also hide the preview panel")
	assert_true((recorded.editor_focus_count or 0) >= 1, "opening editor should focus the snippet window")
	assert_equal(recorded.editor_window_style, 31, "editor should use the configured stable webview window style")
	assert_true(type(recorded.editor_click_point) == "table", "opening editor should click inside the editor to claim focus")
	assert_contains(recorded.editor_last_script, "document.getElementById(\"content\")", "opening editor should refocus the textarea via JavaScript")
	recorded.editor_message_handler({
		body = {
			action = "save",
			title = "Edited Title",
			content = "Edited body\nSecond line",
		},
	})
	assert_true(snippet_center.get_state().editor_exists == false, "saving from editor should close the editor")
	assert_equal(snippet_center.get_state().items[1].title, "Edited Title", "editor save should update snippet title")
	assert_equal(snippet_center.get_state().items[1].content, "Edited body\nSecond line", "editor save should update snippet content")

	snippet_center.show_chooser()
	choices = recorded.chooser:choices()
	recorded.chooser:selectChoice(choices[1])
	assert_true(snippet_center.get_state().editor_exists == true, "new empty action should open the editor")
	recorded.editor_message_handler({
		body = {
			action = "save",
			title = "",
			content = "Second snippet body",
		},
	})
	assert_equal(snippet_center.get_state().item_count, 2, "creating from editor should add a new snippet")

	snippet_center.show_chooser()
	recorded.chooser:query("second")
	choices = recorded.chooser:choices()
	local matched_snippet = first_choice_by_source(choices, "snippet")
	assert_true(matched_snippet ~= nil, "query should match snippet content")
	assert_equal(matched_snippet.text, "Second snippet body", "content search should keep matching snippet in chooser")

	current_clipboard_text = "ORIGINAL CLIPBOARD"
	snippet_center.show_chooser()
	choices = recorded.chooser:choices()
	local snippet_choice = first_choice_by_source(choices, "snippet")
	assert_true(snippet_choice ~= nil, "chooser should expose at least one snippet choice for insertion")
	recorded.chooser:selectChoice(snippet_choice)
	assert_equal(recorded.auto_paste_keystrokes[1].key, "v", "selecting a snippet should auto paste via Command+V")
	assert_equal(table.concat(recorded.auto_paste_keystrokes[1].modifiers, ","), "cmd", "auto paste should use Command modifier")
	assert_true(recorded.frontmost_app_activations >= 1, "auto paste should reactivate the previous app")
	assert_equal(current_clipboard_text, "ORIGINAL CLIPBOARD", "clipboard should be restored after automatic insertion")
	assert_true(#recorded.suspend_capture_calls >= 2, "automatic insertion should suspend clipboard history for write and restore")
	assert_true(snippet_center.get_state().items[1].use_count >= 1, "selected snippet should update usage count")

	snippet_center.hide_menubar()
	assert_true(snippet_center.get_state().menubar_exists ~= true, "hide_menubar should remove the menubar item")
	snippet_center.show_menubar()
	assert_true(snippet_center.get_state().menubar_exists == true, "show_menubar should recreate the menubar item")
	assert_true(recorded.menubar_created >= 2, "show_menubar should create a fresh menubar item after hiding")

	assert_true(snippet_center.stop(), "snippet_center.stop() should succeed")
	assert_equal(recorded.deleted_binding_count, 4, "reconfiguring and stopping should delete replaced and active hotkey bindings")
	assert_true(recorded.chooser_deleted == true, "stop should delete the chooser")
	assert_true(recorded.menubar_deleted >= 2, "stop should delete the menubar item")
	assert_true(recorded.preview_deleted == true, "stop should delete the preview canvas")

	reset_modules()
	rawset(os, "remove", original_remove)
	rawset(os, "rename", original_rename)
	rawset(io, "open", original_io_open)
	hs = nil
end

return _M
