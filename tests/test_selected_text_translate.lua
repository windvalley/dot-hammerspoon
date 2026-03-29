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

local function assert_contains(text, expected, message)
	if tostring(text or ""):find(expected, 1, true) == nil then
		error(string.format("%s: expected to find %s in %s", message or "assert_contains failed", tostring(expected), tostring(text)))
	end
end

local function assert_close(actual, expected, epsilon, message)
	if math.abs(actual - expected) > (epsilon or 0.0001) then
		error(string.format("%s: expected %.6f, got %.6f", message or "assert_close failed", expected, actual))
	end
end

local function find_element(elements, id)
	for _, element in ipairs(elements or {}) do
		if element.id == id then
			return element
		end
	end

	return nil
end

local function find_watcher(recorded, expected_event_type)
	for index = #(recorded.popup_watchers or {}), 1, -1 do
		local watcher = recorded.popup_watchers[index]

		if watcher.stopped == true then
			goto continue
		end

		for _, event_type in ipairs(watcher.event_types or {}) do
			if event_type == expected_event_type then
				return watcher
			end
		end

		::continue::
	end

	return nil
end

local function find_menu_item(menu, title)
	for _, item in ipairs(menu or {}) do
		if item.title == title then
			return item
		end
	end

	return nil
end

local function copy_value(value)
	if type(value) ~= "table" then
		return value
	end

	local copied = {}

	for key, item in pairs(value) do
		copied[key] = copy_value(item)
	end

	return copied
end

local function merge_tables(base, overrides)
	local merged = copy_value(base or {})

	for key, value in pairs(overrides or {}) do
		if type(value) == "table" and type(merged[key]) == "table" then
			merged[key] = merge_tables(merged[key], value)
		else
			merged[key] = copy_value(value)
		end
	end

	return merged
end

local function get_path_value(root, path)
	local value = root

	for _, segment in ipairs(path or {}) do
		if type(value) ~= "table" then
			return nil
		end

		value = value[segment]
	end

	return value
end

local function build_model_service(overrides)
	return merge_tables({
		provider = "openai_compatible",
		request_timeout_seconds = 20,
		ollama = {
			api_url = "http://localhost:11434/api/chat",
			model = "qwen3.5:35b",
			enable_warmup = false,
			keep_alive = "",
			disable_thinking = true,
		},
		openai_compatible = {
			api_url = "https://example.com/v1/chat/completions",
			model = "gpt-test",
			api_key_env = "OPENAI_API_KEY",
			api_key = "",
		},
		gemini = {
			api_url = "https://generativelanguage.googleapis.com/v1beta/models",
			model = "gemini-2.0-flash",
			api_key_env = "GEMINI_API_KEY",
			api_key = "",
		},
		anthropic = {
			api_url = "https://api.anthropic.com/v1/messages",
			model = "claude-3-5-haiku-latest",
			api_key_env = "ANTHROPIC_API_KEY",
			api_key = "",
		},
	}, overrides)
end

local function reset_modules()
	loaded_modules["selected_text_translate"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
	loaded_modules["clipboard_center"] = nil
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
	local modifier_order = {
		ctrl = 1,
		alt = 2,
		cmd = 3,
		shift = 4,
		fn = 5,
	}

	return {
		normalize_hotkey_modifiers = function(modifiers)
			local values = {}

			if modifiers == nil then
				return {}
			end

			if type(modifiers) == "table" then
				values = modifiers
			else
				for token in tostring(modifiers):gmatch("[^,%+%s]+") do
					table.insert(values, token)
				end
			end

			local normalized = {}
			local seen = {}

			for _, raw in ipairs(values) do
				local modifier = modifier_aliases[tostring(raw):lower()]

				if modifier == nil then
					return nil, raw
				end

				if seen[modifier] ~= true then
					seen[modifier] = true
					table.insert(normalized, modifier)
				end
			end

			table.sort(normalized, function(left, right)
				return modifier_order[left] < modifier_order[right]
			end)

			return normalized
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
		modifier_prompt_names = {
			ctrl = "ctrl",
			alt = "option",
			cmd = "command",
			shift = "shift",
			fn = "fn",
		},
		bind = function(modifiers, key, message, pressedfn)
			recorded.binding = {
				modifiers = modifiers,
				key = key,
				message = message,
			}
			recorded.bindings = recorded.bindings or {}
			table.insert(recorded.bindings, recorded.binding)
			recorded.bound_handler = pressedfn

			return {
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
				end,
			}
		end,
	}
end

local function create_menu_stub(recorded)
	return {
		new = function()
			recorded.menubar_created = recorded.menubar_created + 1

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
				delete = function()
					recorded.menubar_deleted = recorded.menubar_deleted + 1
				end,
			}
		end,
	}
end

local function create_timer_stub(recorded)
	return {
		doAfter = function(seconds, callback)
			local timer_state = {
				seconds = seconds,
				callback = callback,
				stopped = false,
			}

			table.insert(recorded.timers, timer_state)

			return {
				stop = function()
					timer_state.stopped = true
					recorded.stopped_timers = recorded.stopped_timers + 1
				end,
			}
		end,
	}
end

local function create_canvas_stub(recorded)
	return {
		windowLevels = {
			modalPanel = 17,
		},
		new = function(frame)
			local canvas_state = {
				frame = frame,
				elements = {},
				mouse_callback = nil,
				deleted = false,
			}

			table.insert(recorded.canvas_states, canvas_state)

			return {
				behaviorAsLabels = function(_, labels)
					canvas_state.behavior_labels = labels
				end,
				clickActivating = function(_, value)
					canvas_state.click_activating = value
				end,
				level = function(_, level)
					canvas_state.level = level
					table.insert(recorded.canvas_levels, level)
				end,
				appendElements = function(_, ...)
					canvas_state.elements = { ... }
				end,
				mouseCallback = function(_, callback)
					canvas_state.mouse_callback = callback
				end,
				show = function(_, duration)
					canvas_state.show_duration = duration
					recorded.shown_canvases = recorded.shown_canvases + 1
				end,
				hide = function(_, duration)
					canvas_state.hide_duration = duration
					recorded.hidden_canvases = recorded.hidden_canvases + 1
				end,
				delete = function()
					if canvas_state.deleted ~= true then
						canvas_state.deleted = true
						recorded.deleted_canvases = recorded.deleted_canvases + 1
					end
				end,
			}
		end,
	}
end

local function create_eventtap_stub(recorded)
	return {
		event = {
			types = {
				leftMouseDown = 1,
				rightMouseDown = 2,
				otherMouseDown = 3,
				mouseMoved = 4,
				leftMouseDragged = 5,
				rightMouseDragged = 6,
				otherMouseDragged = 7,
				keyDown = 8,
			},
		},
		new = function(event_types, callback)
			local watcher_state = {
				event_types = event_types,
				callback = callback,
				started = false,
				stopped = false,
			}

			table.insert(recorded.popup_watchers, watcher_state)

			return {
				start = function()
					watcher_state.started = true
					recorded.started_watchers = recorded.started_watchers + 1
					return watcher_state
				end,
				stop = function()
					watcher_state.stopped = true
					recorded.stopped_watchers = recorded.stopped_watchers + 1
					return watcher_state
				end,
			}
		end,
	}
end

local function create_axuielement_stub(bounds)
	return {
		systemWideElement = function()
			return {
				AXFocusedUIElement = {
					AXSelectedTextRange = {
						location = 2,
						length = 11,
					},
					parameterizedAttributeValue = function(_, attribute, range)
						if attribute ~= "AXBoundsForRange" then
							return nil
						end

						if range.location ~= 2 or range.length ~= 11 then
							return nil
						end

						return bounds
					end,
				},
			}
		end,
	}
end

function _M.run()
	reset_modules()

	local original_getenv = os.getenv

	local direct_recorded = {
		alerts = {},
		block_alerts = {},
		dialog_responses = { "恢复默认" },
		pasteboard_sets = {},
		async_posts = {},
		deleted_bindings = 0,
		menubar_created = 0,
		menubar_deleted = 0,
		settings_store = {},
		prompt_values = {
			"command+shift",
			"t",
			"sk-menu",
		},
		timers = {},
		stopped_timers = 0,
		canvas_states = {},
		canvas_levels = {},
		shown_canvases = 0,
		hidden_canvases = 0,
		deleted_canvases = 0,
		popup_watchers = {},
		started_watchers = 0,
		stopped_watchers = 0,
		mouse_position = {
			x = 0,
			y = 0,
		},
	}

	rawset(os, "getenv", function(name)
		if name == "OPENAI_API_KEY" then
			return "sk-direct"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return direct_recorded.settings_store[key]
			end,
			set = function(key, value)
				direct_recorded.settings_store[key] = value
			end,
			clear = function(key)
				direct_recorded.settings_store[key] = nil
			end,
		},
		menubar = create_menu_stub(direct_recorded),
		alert = {
			show = function(message)
				table.insert(direct_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(direct_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				if #direct_recorded.dialog_responses > 0 then
					return table.remove(direct_recorded.dialog_responses, 1)
				end

				return "关闭"
			end,
		},
		timer = create_timer_stub(direct_recorded),
		canvas = create_canvas_stub(direct_recorded),
		eventtap = create_eventtap_stub(direct_recorded),
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "hello world"
					end,
				}
			end,
		},
		mouse = {
			absolutePosition = function()
				return direct_recorded.mouse_position
			end,
		},
		axuielement = create_axuielement_stub({
			x = 400,
			y = 300,
			w = 100,
			h = 24,
		}),
		screen = {
			mainScreen = function()
				return {
					frame = function()
						return { x = 100, y = 60, w = 1440, h = 900 }
					end,
				}
			end,
		},
		json = {
			encode = function(value)
				direct_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(body)
				direct_recorded.decoded_body = body
				return {
					choices = {
						{
							message = {
								content = "你好，世界",
							},
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(direct_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
		pasteboard = {
			setContents = function(value)
				table.insert(direct_recorded.pasteboard_sets, value)
				return true
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			translation_direction = "auto",
			target_language = "简体中文",
			chinese_target_language = "英文",
			popup_duration_seconds = 8,
			popup_theme = "ocean",
			popup_background_alpha = 0.84,
			model_service = build_model_service({
				provider = "openai_compatible",
				request_timeout_seconds = 15,
				openai_compatible = {
					api_url = "https://example.com/v1/chat/completions",
					model = "gpt-test",
					api_key_env = "OPENAI_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(direct_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
		prompt_text = function(_, _, default_value)
			if #direct_recorded.prompt_values == 0 then
				return default_value
			end

			return table.remove(direct_recorded.prompt_values, 1)
		end,
	}

	local translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully")
	assert_equal(direct_recorded.menubar_created, 1, "translator should create a menubar entry during startup")
	assert_equal(direct_recorded.menubar_title, "译", "translator should expose a stable menubar marker")
	assert_equal(
		direct_recorded.menubar_autosave_name,
		"dot-hammerspoon.selected_text_translate",
		"translator should apply a stable menubar autosave name"
	)
	assert_equal(direct_recorded.binding.key, "r", "translator should normalize its hotkey key")
	assert_true(type(direct_recorded.bound_handler) == "function", "translator should register a hotkey handler")
	assert_true(type(direct_recorded.menu_builder) == "function", "translator should expose a menubar menu builder")

	local menu = direct_recorded.menu_builder()
	assert_true(find_menu_item(menu, "快捷键") ~= nil, "menubar should expose a hotkey submenu")
	assert_true(find_menu_item(menu, "翻译方向") ~= nil, "menubar should expose a direction submenu")
	assert_true(find_menu_item(menu, "非中文目标语言") ~= nil, "menubar should expose a target language submenu")
	assert_true(find_menu_item(menu, "中文目标语言") ~= nil, "menubar should expose a reverse target language submenu")
	assert_true(find_menu_item(menu, "悬浮窗主题") ~= nil, "menubar should expose a popup theme submenu")
	assert_true(find_menu_item(menu, "悬浮窗透明度") ~= nil, "menubar should expose a popup alpha submenu")
	assert_true(find_menu_item(menu, "悬浮窗停留时间") ~= nil, "menubar should expose a popup duration submenu")
	assert_true(find_menu_item(menu, "模型服务") ~= nil, "menubar should expose model service settings")
	local model_service_menu = find_menu_item(menu, "模型服务").menu
	assert_true(find_menu_item(model_service_menu, "Ollama") ~= nil, "model service menu should group settings under Ollama")
	assert_true(
		find_menu_item(model_service_menu, "OpenAI 兼容") ~= nil,
		"model service menu should group settings under OpenAI-compatible"
	)
	assert_true(
		find_menu_item(find_menu_item(menu, "中文目标语言").menu, "简体中文") == nil,
		"Chinese target language presets should not offer Simplified Chinese"
	)

	find_menu_item(find_menu_item(menu, "快捷键").menu, "设置快捷键...").fn()
	assert_equal(translator.get_state().hotkey_key, "t", "menu hotkey prompt should update the runtime hotkey")
	assert_equal(direct_recorded.binding.key, "t", "menu hotkey prompt should rebind the configured hotkey")
	assert_equal(
		direct_recorded.settings_store["selected_text_translate.runtime_overrides"].key,
		"t",
		"menu hotkey updates should be persisted"
	)

	find_menu_item(find_menu_item(menu, "悬浮窗主题").menu, "Forest 松林").fn()
	assert_equal(translator.get_state().popup_theme, "forest", "theme menu should update the runtime popup theme")
	assert_equal(
		direct_recorded.settings_store["selected_text_translate.runtime_overrides"].popup_theme,
		"forest",
		"theme updates should be persisted"
	)

	find_menu_item(find_menu_item(model_service_menu, "Ollama").menu, "设为当前提供方").fn()
	assert_equal(translator.get_state().provider, "ollama", "provider menu should switch to Ollama")
	assert_equal(
		get_path_value(direct_recorded.settings_store["selected_text_translate.runtime_overrides"], {
			"model_service",
			"provider",
		}),
		"ollama",
		"provider menu should persist the selected provider"
	)

	menu = direct_recorded.menu_builder()
	model_service_menu = find_menu_item(menu, "模型服务").menu
	find_menu_item(find_menu_item(model_service_menu, "OpenAI 兼容").menu, "设置 API Key...").fn()
	assert_equal(
		get_path_value(direct_recorded.settings_store["selected_text_translate.runtime_overrides"], {
			"model_service",
			"openai_compatible",
			"api_key",
		}),
		"sk-menu",
		"provider-group API key prompt should persist the entered key"
	)
	assert_equal(
		translator.get_state().provider,
		"ollama",
		"editing another provider from its group should not switch the active provider"
	)
	find_menu_item(find_menu_item(model_service_menu, "OpenAI 兼容").menu, "设为当前提供方").fn()
	assert_equal(
		translator.get_state().provider,
		"openai_compatible",
		"provider group should switch back to OpenAI-compatible mode"
	)
	assert_equal(translator.get_state().api_key_source, "菜单已保存", "provider-group API key menu should update runtime key source")

	direct_recorded.bound_handler()

	assert_equal(#direct_recorded.async_posts, 1, "direct accessibility path should issue one HTTP request")
	assert_equal(
		direct_recorded.async_posts[1].url,
		"https://example.com/v1/chat/completions",
		"translator should use the configured API URL"
	)
	assert_equal(
		direct_recorded.async_posts[1].headers["Authorization"],
		"Bearer sk-menu",
		"translator should prefer the persisted menu API key"
	)
	assert_equal(direct_recorded.encoded_payload.model, "gpt-test", "translator should encode the configured model")
	assert_equal(direct_recorded.encoded_payload.temperature, 0.2, "openai-compatible mode should keep temperature in the payload")
	assert_equal(
		direct_recorded.encoded_payload.messages[2].content,
		"hello world",
		"translator should pass the selected text as the user message"
	)
	assert_contains(
		direct_recorded.encoded_payload.messages[1].content,
		"简体中文",
		"non-Chinese selections should still translate to the configured target language"
	)
	assert_equal(direct_recorded.shown_canvases, 1, "translator should show one floating popup")
	assert_equal(direct_recorded.canvas_levels[1], 17, "translator should use the modal panel window level for the popup")
	assert_equal(direct_recorded.started_watchers, 3, "translator should start outside-click, hover, and escape watchers while the popup is visible")
	assert_equal(direct_recorded.canvas_states[1].frame.x, 290, "translator should anchor the popup horizontally above the selection when bounds are available")
	assert_equal(direct_recorded.canvas_states[1].frame.y, 148, "translator should leave room between the arrow tip and the selected text when bounds are available")
	assert_equal(direct_recorded.canvas_states[1].frame.h, 140, "translator should extend the canvas to make room for the popup arrow")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.red, 0.12, 0.0001, "translator should use the selected theme background red channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.green, 0.23, 0.0001, "translator should use the selected theme background green channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.blue, 0.18, 0.0001, "translator should use the selected theme background blue channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.alpha, 0.84, 0.0001, "translator should apply popup alpha separately from the theme")
	assert_equal(find_element(direct_recorded.canvas_states[1].elements, "background").frame.h, 132, "translator should keep the rounded bubble body separate from the arrow area")
	assert_equal(find_element(direct_recorded.canvas_states[1].elements, "title").text, "翻译结果", "translator should render the popup title")
	assert_equal(find_element(direct_recorded.canvas_states[1].elements, "body").text, "你好，世界", "translator should render the translated text")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "copy_button").fillColor.alpha, 0, 0.0001, "translator should keep the copy hit area invisible")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "copy_icon_front").strokeColor.red, 0.24, 0.0001, "translator should use the selected theme accent color for the copy icon")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "copy_icon_front") ~= nil, "translator should render the copy icon")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_shadow") ~= nil, "translator should render a dedicated shadow layer for the popup arrow")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_fill") ~= nil, "translator should render a pointer arrow for anchored popups")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_border") ~= nil, "translator should stroke the pointer arrow edges")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "border") == nil, "translator should use one continuous border path instead of a separate body border")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_shadow").withShadow == true, "translator should give the popup arrow the same floating shadow as the bubble")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_fill").coordinates[1].y < find_element(direct_recorded.canvas_states[1].elements, "background").frame.h, "translator should overlap the arrow shoulders into the bubble body to avoid a visible seam")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "arrow_border").closed == true, "translator should render the arrow and bubble border as one closed outline")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "arrow_fill").coordinates[3].x, 160, 0.0001, "translator should aim the popup arrow at the selection center")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "arrow_fill").coordinates[3].y, 139.5, 0.0001, "translator should place the arrow tip on the lower edge when the popup is above the selection")
	assert_close(direct_recorded.canvas_states[1].frame.y + find_element(direct_recorded.canvas_states[1].elements, "arrow_fill").coordinates[3].y, 287.5, 0.0001, "translator should keep the arrow tip a visible distance away from the selected text")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "close_button") == nil, "translator should not render a close button")
	assert_true(type(direct_recorded.canvas_states[1].mouse_callback) == "function", "translator should register popup mouse handlers")
	assert_equal(direct_recorded.timers[2].seconds, 8, "translator should use the configured popup auto-hide duration")

	direct_recorded.canvas_states[1].mouse_callback(nil, "mouseDown", "copy_button")

	assert_equal(direct_recorded.pasteboard_sets[1], "你好，世界", "copy button should write the translation to the clipboard")
	assert_contains(direct_recorded.alerts[#direct_recorded.alerts], "译文已复制", "copy success should be surfaced to the user")

	direct_recorded.mouse_position = {
		x = 320,
		y = 170,
	}
	find_watcher(direct_recorded, 4).callback()

	assert_true(direct_recorded.timers[2].stopped == true, "hovering the popup should pause auto-hide")

	direct_recorded.mouse_position = {
		x = 640,
		y = 170,
	}
	find_watcher(direct_recorded, 4).callback()

	assert_equal(direct_recorded.timers[3].seconds, 8, "moving the mouse away should restart popup auto-hide")

	direct_recorded.mouse_position = {
		x = 40,
		y = 40,
	}
	find_watcher(direct_recorded, 1).callback()

	assert_equal(direct_recorded.hidden_canvases, 1, "outside clicks should hide the popup")
	assert_equal(direct_recorded.deleted_canvases, 1, "outside clicks should delete the popup canvas")
	assert_equal(direct_recorded.stopped_watchers, 3, "outside clicks should stop all popup watchers")

	direct_recorded.bound_handler()

	assert_equal(direct_recorded.shown_canvases, 2, "translator should allow reopening the popup after it is closed")
	assert_equal(direct_recorded.started_watchers, 6, "reopened popups should start a fresh set of popup watchers")
	assert_true(
		find_watcher(direct_recorded, 8).callback({
			getKeyCode = function()
				return 53
			end,
		}),
		"pressing escape should be consumed when closing the popup"
	)
	assert_equal(direct_recorded.hidden_canvases, 2, "pressing escape should hide the popup")
	assert_equal(direct_recorded.deleted_canvases, 2, "pressing escape should delete the popup canvas")
	assert_equal(direct_recorded.stopped_watchers, 6, "pressing escape should stop all popup watchers")

	local restored_menu = direct_recorded.menu_builder()
	find_menu_item(restored_menu, "恢复默认").fn()
	assert_equal(translator.get_state().hotkey_key, "r", "restore defaults should recover the configured hotkey")
	assert_equal(translator.get_state().popup_theme, "ocean", "restore defaults should recover the configured popup theme")
	assert_equal(
		direct_recorded.settings_store["selected_text_translate.runtime_overrides"],
		nil,
		"restore defaults should clear persisted menu overrides"
	)
	assert_true(translator.stop(), "translator stop should succeed")
	assert_equal(direct_recorded.deleted_bindings, 3, "translator stop should delete the active hotkey after menu rebinds")
	assert_equal(direct_recorded.deleted_canvases, 2, "translator stop should not delete an already closed popup twice")

	reset_modules()

	local chinese_to_english_recorded = {
		alerts = {},
		block_alerts = {},
		async_posts = {},
		deleted_bindings = 0,
		timers = {},
		stopped_timers = 0,
	}

	rawset(os, "getenv", function(name)
		if name == "OPENAI_API_KEY" then
			return "sk-bilingual"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(chinese_to_english_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(chinese_to_english_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = create_timer_stub(chinese_to_english_recorded),
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "你好，世界"
					end,
				}
			end,
		},
		json = {
			encode = function(value)
				chinese_to_english_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					choices = {
						{
							message = {
								content = "Hello, world",
							},
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(chinese_to_english_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			translation_direction = "auto",
			target_language = "简体中文",
			chinese_target_language = "英文",
			model_service = build_model_service({
				provider = "openai_compatible",
				openai_compatible = {
					api_url = "https://example.com/v1/chat/completions",
					model = "gpt-bilingual",
					api_key_env = "OPENAI_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(chinese_to_english_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for Chinese-to-English auto mode")
	chinese_to_english_recorded.bound_handler()

	assert_contains(
		chinese_to_english_recorded.encoded_payload.messages[1].content,
		"英文",
		"Chinese selections should translate to the configured Chinese target language in auto mode"
	)
	assert_equal(
		chinese_to_english_recorded.encoded_payload.messages[2].content,
		"你好，世界",
		"Chinese selections should be sent as the user content"
	)
	assert_equal(
		chinese_to_english_recorded.block_alerts[1].informative_text,
		"Hello, world",
		"Chinese-to-English auto mode should still show the translated result"
	)
	assert_true(translator.stop(), "translator stop should succeed after Chinese-to-English auto mode")
	assert_equal(
		chinese_to_english_recorded.deleted_bindings,
		1,
		"translator stop should delete its hotkey binding after Chinese-to-English auto mode"
	)

	reset_modules()

	local fallback_recorded = {
		alerts = {},
		block_alerts = {},
		pasteboard_sets = {},
		async_posts = {},
		deleted_bindings = 0,
		change_count = 4,
		clipboard_text = "old clipboard",
		suspended_capture = nil,
		key_stroke = nil,
		timers = {},
		stopped_timers = 0,
	}

	rawset(os, "getenv", function(name)
		if name == "OPENAI_API_KEY" then
			return "sk-fallback"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(fallback_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(fallback_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = create_timer_stub(fallback_recorded),
		application = {
			frontmostApplication = function()
				return nil
			end,
		},
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return nil
					end,
				}
			end,
		},
		eventtap = {
			keyStroke = function(modifiers, key)
				fallback_recorded.key_stroke = {
					modifiers = modifiers,
					key = key,
				}
				fallback_recorded.clipboard_text = "selected from copy"
				fallback_recorded.change_count = fallback_recorded.change_count + 1
			end,
		},
		json = {
			encode = function(value)
				fallback_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					choices = {
						{
							message = {
								content = "复制路径译文",
							},
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(fallback_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
		pasteboard = {
			getContents = function()
				return fallback_recorded.clipboard_text
			end,
			setContents = function(value)
				table.insert(fallback_recorded.pasteboard_sets, value)
				fallback_recorded.clipboard_text = value
				fallback_recorded.change_count = fallback_recorded.change_count + 1
				return true
			end,
			changeCount = function()
				return fallback_recorded.change_count
			end,
			readImage = function()
				return nil
			end,
			clearContents = function()
				fallback_recorded.clipboard_text = nil
				fallback_recorded.change_count = fallback_recorded.change_count + 1
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			clipboard_poll_interval_seconds = 0.05,
			clipboard_max_wait_seconds = 0.3,
			model_service = build_model_service({
				provider = "openai_compatible",
				openai_compatible = {
					api_url = "https://example.com/v1/chat/completions",
					model = "gpt-fallback",
					api_key_env = "OPENAI_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(fallback_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}
	loaded_modules["clipboard_center"] = {
		suspend_capture = function(seconds)
			fallback_recorded.suspended_capture = seconds
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for clipboard fallback")
	fallback_recorded.bound_handler()

	assert_equal(fallback_recorded.key_stroke.key, "c", "clipboard fallback should simulate Command-C")
	assert_equal(fallback_recorded.key_stroke.modifiers[1], "cmd", "clipboard fallback should use the Command modifier")
	assert_true(
		type(fallback_recorded.suspended_capture) == "number" and fallback_recorded.suspended_capture > 0,
		"clipboard fallback should temporarily suspend clipboard history capture"
	)
	assert_equal(
		fallback_recorded.encoded_payload.messages[2].content,
		"selected from copy",
		"clipboard fallback should translate the copied selection instead of stale clipboard contents"
	)
	assert_equal(
		fallback_recorded.pasteboard_sets[1],
		"old clipboard",
		"clipboard fallback should restore the previous clipboard text after reading the selection"
	)
	assert_equal(
		fallback_recorded.block_alerts[1].informative_text,
		"复制路径译文",
		"clipboard fallback should still show the translated result"
	)
	assert_equal(#fallback_recorded.alerts, 0, "closing the popup should not emit extra alerts")
	assert_true(translator.stop(), "translator stop should succeed after clipboard fallback")
	assert_equal(fallback_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding in fallback path")

	reset_modules()

	local ghostty_recorded = {
		alerts = {},
		block_alerts = {},
		pasteboard_sets = {},
		async_posts = {},
		deleted_bindings = 0,
		change_count = 9,
		clipboard_text = "selected from ghostty auto copy",
		suspended_capture = nil,
		key_stroke = nil,
		timers = {},
		stopped_timers = 0,
	}

	rawset(os, "getenv", function(name)
		if name == "OPENAI_API_KEY" then
			return "sk-ghostty"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(ghostty_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(ghostty_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = create_timer_stub(ghostty_recorded),
		application = {
			frontmostApplication = function()
				return {
					bundleID = function()
						return "com.mitchellh.ghostty"
					end,
				}
			end,
		},
			uielement = {
				focusedElement = function()
					return {
						selectedText = function()
							return nil
					end,
				}
			end,
			},
			eventtap = {
				keyStroke = function(modifiers, key)
					ghostty_recorded.key_stroke = {
						modifiers = modifiers,
						key = key,
					}
					ghostty_recorded.clipboard_text = "selected from ghostty copy"
					ghostty_recorded.change_count = ghostty_recorded.change_count + 1
				end,
			},
		json = {
			encode = function(value)
				ghostty_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					choices = {
						{
							message = {
								content = "Ghostty 译文",
							},
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(ghostty_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
		pasteboard = {
			getContents = function()
				return ghostty_recorded.clipboard_text
			end,
			setContents = function(value)
				table.insert(ghostty_recorded.pasteboard_sets, value)
				ghostty_recorded.clipboard_text = value
				ghostty_recorded.change_count = ghostty_recorded.change_count + 1
				return true
			end,
			changeCount = function()
				return ghostty_recorded.change_count
			end,
			readImage = function()
				return nil
			end,
			clearContents = function()
				ghostty_recorded.clipboard_text = nil
				ghostty_recorded.change_count = ghostty_recorded.change_count + 1
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			clipboard_poll_interval_seconds = 0.05,
			clipboard_max_wait_seconds = 0.3,
			selection_auto_copy_by_bundle_id = {
				["com.mitchellh.ghostty"] = true,
			},
			model_service = build_model_service({
				provider = "openai_compatible",
				openai_compatible = {
					api_url = "https://example.com/v1/chat/completions",
					model = "gpt-ghostty",
					api_key_env = "OPENAI_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(ghostty_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}
	loaded_modules["clipboard_center"] = {
		suspend_capture = function(seconds)
			ghostty_recorded.suspended_capture = seconds
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for Ghostty clipboard fallback")
	ghostty_recorded.bound_handler()

	assert_true(ghostty_recorded.key_stroke == nil, "Ghostty auto-copy fallback should not simulate an extra copy keystroke")
	assert_equal(
		ghostty_recorded.encoded_payload.messages[2].content,
		"selected from ghostty auto copy",
		"Ghostty auto-copy fallback should translate the current clipboard selection"
	)
	assert_equal(#ghostty_recorded.pasteboard_sets, 0, "Ghostty auto-copy fallback should not rewrite the clipboard")
	assert_equal(
		ghostty_recorded.block_alerts[1].informative_text,
		"Ghostty 译文",
		"Ghostty auto-copy fallback should still show the translated result"
	)
	assert_true(translator.stop(), "translator stop should succeed after Ghostty auto-copy fallback")
	assert_equal(ghostty_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding after Ghostty auto-copy fallback")

	reset_modules()

	local gemini_recorded = {
		alerts = {},
		block_alerts = {},
		async_posts = {},
		deleted_bindings = 0,
		timers = {},
		stopped_timers = 0,
	}

	rawset(os, "getenv", function(name)
		if name == "GEMINI_API_KEY" then
			return "gemini-key"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(gemini_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(gemini_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = create_timer_stub(gemini_recorded),
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "gemini source"
					end,
				}
			end,
		},
		json = {
			encode = function(value)
				gemini_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					candidates = {
						{
							content = {
								parts = {
									{ text = "Gemini 译文" },
								},
							},
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(gemini_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			model_service = build_model_service({
				provider = "gemini",
				gemini = {
					api_url = "https://generativelanguage.googleapis.com/v1beta/models",
					model = "gemini-2.0-flash",
					api_key_env = "GEMINI_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(gemini_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for Gemini mode")
	assert_equal(translator.get_state().resolved_api_mode, "gemini", "Gemini mode should expose the resolved provider")
	gemini_recorded.bound_handler()

	assert_equal(
		gemini_recorded.async_posts[1].url,
		"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
		"Gemini mode should expand the models endpoint to the generateContent URL"
	)
	assert_equal(
		gemini_recorded.async_posts[1].headers["x-goog-api-key"],
		"gemini-key",
		"Gemini mode should send the configured API key with x-goog-api-key"
	)
	assert_true(
		gemini_recorded.async_posts[1].headers["Authorization"] == nil,
		"Gemini mode should not send an OpenAI-style Authorization header"
	)
	assert_contains(
		gemini_recorded.encoded_payload.systemInstruction.parts[1].text,
		"简体中文",
		"Gemini mode should keep the translation target in the system instruction"
	)
	assert_equal(
		gemini_recorded.encoded_payload.contents[1].parts[1].text,
		"gemini source",
		"Gemini mode should send the selected text in contents.parts"
	)
	assert_equal(
		gemini_recorded.block_alerts[1].informative_text,
		"Gemini 译文",
		"Gemini mode should parse and display the returned translation"
	)
	assert_true(translator.stop(), "translator stop should succeed after Gemini mode")
	assert_equal(gemini_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding after Gemini mode")

	reset_modules()

	local anthropic_recorded = {
		alerts = {},
		block_alerts = {},
		async_posts = {},
		deleted_bindings = 0,
		timers = {},
		stopped_timers = 0,
	}

	rawset(os, "getenv", function(name)
		if name == "ANTHROPIC_API_KEY" then
			return "anthropic-key"
		end

		return original_getenv(name)
	end)

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(anthropic_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(anthropic_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = create_timer_stub(anthropic_recorded),
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "anthropic source"
					end,
				}
			end,
		},
		json = {
			encode = function(value)
				anthropic_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					content = {
						{
							type = "text",
							text = "Anthropic 译文",
						},
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(anthropic_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			model_service = build_model_service({
				provider = "anthropic",
				anthropic = {
					api_url = "https://api.anthropic.com/v1/messages",
					model = "claude-3-5-haiku-latest",
					api_key_env = "ANTHROPIC_API_KEY",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(anthropic_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for Anthropic mode")
	assert_equal(translator.get_state().resolved_api_mode, "anthropic", "Anthropic mode should expose the resolved provider")
	anthropic_recorded.bound_handler()

	assert_equal(
		anthropic_recorded.async_posts[1].url,
		"https://api.anthropic.com/v1/messages",
		"Anthropic mode should use the configured messages endpoint"
	)
	assert_equal(
		anthropic_recorded.async_posts[1].headers["x-api-key"],
		"anthropic-key",
		"Anthropic mode should send the configured x-api-key header"
	)
	assert_equal(
		anthropic_recorded.async_posts[1].headers["anthropic-version"],
		"2023-06-01",
		"Anthropic mode should send the required API version header"
	)
	assert_true(
		anthropic_recorded.async_posts[1].headers["Authorization"] == nil,
		"Anthropic mode should not send an OpenAI-style Authorization header"
	)
	assert_contains(
		anthropic_recorded.encoded_payload.system,
		"简体中文",
		"Anthropic mode should keep the translation target in the system prompt"
	)
	assert_equal(
		anthropic_recorded.encoded_payload.messages[1].content,
		"anthropic source",
		"Anthropic mode should send the selected text in the user message"
	)
	assert_equal(
		anthropic_recorded.encoded_payload.max_tokens,
		1024,
		"Anthropic mode should provide a default max_tokens value"
	)
	assert_equal(
		anthropic_recorded.block_alerts[1].informative_text,
		"Anthropic 译文",
		"Anthropic mode should parse and display the returned translation"
	)
	assert_true(translator.stop(), "translator stop should succeed after Anthropic mode")
	assert_equal(
		anthropic_recorded.deleted_bindings,
		1,
		"translator stop should delete its hotkey binding after Anthropic mode"
	)

	reset_modules()

	local ollama_recorded = {
		alerts = {},
		block_alerts = {},
		pasteboard_sets = {},
		async_posts = {},
		encoded_payloads = {},
		deleted_bindings = 0,
		timers = {},
		stopped_timers = 0,
		canvas_states = {},
		canvas_levels = {},
		shown_canvases = 0,
		hidden_canvases = 0,
		deleted_canvases = 0,
		popup_watchers = {},
		started_watchers = 0,
		stopped_watchers = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		alert = {
			show = function(message)
				table.insert(ollama_recorded.alerts, message)
			end,
		},
		timer = create_timer_stub(ollama_recorded),
		canvas = create_canvas_stub(ollama_recorded),
		eventtap = create_eventtap_stub(ollama_recorded),
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "fast local text"
					end,
				}
			end,
		},
		mouse = {
			absolutePosition = function()
				return {
					x = 700,
					y = 420,
				}
			end,
		},
		screen = {
			mainScreen = function()
				return {
					frame = function()
						return { x = 0, y = 0, w = 1512, h = 982 }
					end,
				}
			end,
		},
		json = {
			encode = function(value)
				table.insert(ollama_recorded.encoded_payloads, value)
				ollama_recorded.encoded_payload = value
				return "encoded-payload"
			end,
			decode = function(_)
				return {
					message = {
						role = "assistant",
						content = "本地快速译文",
						thinking = "ignored",
					},
				}
			end,
		},
		http = {
			asyncPost = function(url, data, headers, callback)
				table.insert(ollama_recorded.async_posts, {
					url = url,
					data = data,
					headers = headers,
				})
				callback(200, "{\"ok\":true}", {})
			end,
		},
		pasteboard = {
			setContents = function(value)
				table.insert(ollama_recorded.pasteboard_sets, value)
				return true
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			model_service = build_model_service({
				provider = "ollama",
				ollama = {
					api_url = "http://localhost:11434/v1/chat/completions",
					model = "qwen3.5:35b",
					enable_warmup = true,
					keep_alive = "30m",
					disable_thinking = true,
				},
				openai_compatible = {
					api_key_env = "",
					api_key = "ollama",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(ollama_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully for local ollama mode")
	assert_equal(ollama_recorded.timers[1].seconds, 3, "local Ollama mode should schedule a delayed warmup")
	ollama_recorded.timers[1].callback()
	assert_equal(#ollama_recorded.async_posts, 1, "warmup should issue one silent request")
	assert_equal(
		ollama_recorded.encoded_payloads[1].keep_alive,
		"30m",
		"warmup should include the configured keep_alive value"
	)
	assert_equal(ollama_recorded.encoded_payloads[1].model, "qwen3.5:35b", "warmup should target the configured model")
	assert_true(ollama_recorded.encoded_payloads[1].messages == nil, "warmup should use a minimal preload payload")
	assert_equal(ollama_recorded.shown_canvases, 0, "warmup should not show a popup")
	ollama_recorded.bound_handler()

	assert_equal(
		ollama_recorded.async_posts[2].url,
		"http://localhost:11434/api/chat",
		"auto mode should route local Ollama requests to the native chat endpoint"
	)
	assert_equal(
		ollama_recorded.encoded_payload.think,
		false,
		"local Ollama mode should disable thinking by default when configured"
	)
	assert_equal(
		ollama_recorded.encoded_payload.keep_alive,
		"30m",
		"local Ollama mode should include keep_alive in the translation request"
	)
	assert_equal(
		ollama_recorded.encoded_payload.stream,
		false,
		"local Ollama mode should request a non-streaming response"
	)
	assert_equal(
		ollama_recorded.encoded_payload.messages[2].content,
		"fast local text",
		"local Ollama mode should translate the selected text"
	)
	assert_true(
		ollama_recorded.encoded_payload.temperature == nil,
		"local Ollama native mode should not inject OpenAI-specific temperature defaults"
	)
	assert_equal(ollama_recorded.shown_canvases, 1, "local Ollama mode should show the floating popup")
	assert_equal(ollama_recorded.started_watchers, 3, "local Ollama mode should start outside-click, hover, and escape watchers")
	assert_equal(ollama_recorded.canvas_states[1].frame.x, 540, "local Ollama mode should fall back to the mouse position when no selection bounds are available")
	assert_equal(ollama_recorded.canvas_states[1].frame.y, 268, "local Ollama mode should keep the popup arrow away from the mouse anchor when no selection bounds are available")
	assert_equal(find_element(ollama_recorded.canvas_states[1].elements, "body").text, "本地快速译文", "local Ollama mode should render the parsed translation in the popup")
	assert_true(translator.stop(), "translator stop should succeed after local Ollama request")
	assert_equal(ollama_recorded.hidden_canvases, 1, "translator stop should hide any active popup")
	assert_equal(ollama_recorded.deleted_canvases, 1, "translator stop should clean up the active popup canvas")
	assert_equal(ollama_recorded.stopped_watchers, 3, "translator stop should stop all popup watchers")
	assert_equal(ollama_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding in local Ollama mode")

	reset_modules()

	local persisted_recorded = {
		alerts = {},
		deleted_bindings = 0,
		menubar_created = 0,
		menubar_deleted = 0,
		settings_store = {
			["selected_text_translate.runtime_overrides"] = {
				key = "t",
				prefix = { "alt", "shift" },
				popup_theme = "forest",
				popup_duration_seconds = 15,
				model_service = {
					openai_compatible = {
						api_key = "sk-persisted",
					},
				},
			},
		},
	}

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					w = function() end,
					e = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return persisted_recorded.settings_store[key]
			end,
			set = function(key, value)
				persisted_recorded.settings_store[key] = value
			end,
			clear = function(key)
				persisted_recorded.settings_store[key] = nil
			end,
		},
		menubar = create_menu_stub(persisted_recorded),
		alert = {
			show = function(message)
				table.insert(persisted_recorded.alerts, message)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		selected_text_translate = {
			enabled = true,
			prefix = { "Option" },
			key = "R",
			message = "Translate Selection",
			target_language = "简体中文",
			chinese_target_language = "英文",
			model_service = build_model_service({
				provider = "openai_compatible",
				openai_compatible = {
					api_url = "https://example.com/v1/chat/completions",
					model = "gpt-test",
				},
			}),
		},
	}
	loaded_modules["hotkey_helper"] = create_hotkey_helper_stub(persisted_recorded)
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
		prompt_text = function()
			return nil
		end,
	}

	translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully with persisted menu overrides")
	assert_equal(translator.get_state().hotkey_key, "t", "persisted runtime overrides should restore the saved hotkey")
	assert_equal(translator.get_state().popup_theme, "forest", "persisted runtime overrides should restore the saved popup theme")
	assert_equal(translator.get_state().popup_duration_seconds, 15, "persisted runtime overrides should restore popup duration")
	assert_equal(translator.get_state().api_key_source, "菜单已保存", "persisted runtime overrides should restore the saved API key source")
	assert_equal(persisted_recorded.binding.key, "t", "persisted runtime overrides should affect the startup hotkey binding")
	assert_true(translator.stop(), "translator stop should succeed after loading persisted overrides")

	reset_modules()
	rawset(os, "getenv", original_getenv)
	hs = nil
end

return _M
