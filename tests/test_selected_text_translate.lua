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
	for _, watcher in ipairs(recorded.popup_watchers or {}) do
		for _, event_type in ipairs(watcher.event_types or {}) do
			if event_type == expected_event_type then
				return watcher
			end
		end
	end

	return nil
end

local function reset_modules()
	loaded_modules["selected_text_translate"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
	loaded_modules["clipboard_center"] = nil
end

local function create_hotkey_helper_stub(recorded)
	return {
		normalize_hotkey_modifiers = function(modifiers)
			return modifiers or {}
		end,
		bind = function(modifiers, key, message, pressedfn)
			recorded.binding = {
				modifiers = modifiers,
				key = key,
				message = message,
			}
			recorded.bound_handler = pressedfn

			return {
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
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
		pasteboard_sets = {},
		async_posts = {},
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
		alert = {
			show = function(message)
				table.insert(direct_recorded.alerts, message)
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
			target_language = "简体中文",
			api_url = "https://example.com/v1/chat/completions",
			model = "gpt-test",
			api_key_env = "OPENAI_API_KEY",
			request_timeout_seconds = 15,
			popup_duration_seconds = 8,
			popup_theme = "ocean",
			popup_background_alpha = 0.84,
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
	}

	local translator = require("selected_text_translate")

	assert_true(translator.start(), "translator should start successfully")
	assert_equal(direct_recorded.binding.key, "r", "translator should normalize its hotkey key")
	assert_true(type(direct_recorded.bound_handler) == "function", "translator should register a hotkey handler")

	direct_recorded.bound_handler()

	assert_equal(#direct_recorded.async_posts, 1, "direct accessibility path should issue one HTTP request")
	assert_equal(
		direct_recorded.async_posts[1].url,
		"https://example.com/v1/chat/completions",
		"translator should use the configured API URL"
	)
	assert_equal(
		direct_recorded.async_posts[1].headers["Authorization"],
		"Bearer sk-direct",
		"translator should send the configured bearer token"
	)
	assert_equal(direct_recorded.encoded_payload.model, "gpt-test", "translator should encode the configured model")
	assert_equal(direct_recorded.encoded_payload.temperature, 0.2, "openai-compatible mode should keep temperature in the payload")
	assert_equal(
		direct_recorded.encoded_payload.messages[2].content,
		"hello world",
		"translator should pass the selected text as the user message"
	)
	assert_equal(direct_recorded.shown_canvases, 1, "translator should show one floating popup")
	assert_equal(direct_recorded.canvas_levels[1], 17, "translator should use the modal panel window level for the popup")
	assert_equal(direct_recorded.started_watchers, 2, "translator should start outside-click and hover watchers while the popup is visible")
	assert_equal(direct_recorded.canvas_states[1].frame.x, 290, "translator should anchor the popup horizontally above the selection when bounds are available")
	assert_equal(direct_recorded.canvas_states[1].frame.y, 156, "translator should anchor the popup above the selected text when bounds are available")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.red, 0.09, 0.0001, "translator should use the selected theme background red channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.green, 0.18, 0.0001, "translator should use the selected theme background green channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.blue, 0.29, 0.0001, "translator should use the selected theme background blue channel")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "background").fillColor.alpha, 0.84, 0.0001, "translator should apply popup alpha separately from the theme")
	assert_equal(find_element(direct_recorded.canvas_states[1].elements, "title").text, "翻译结果", "translator should render the popup title")
	assert_equal(find_element(direct_recorded.canvas_states[1].elements, "body").text, "你好，世界", "translator should render the translated text")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "copy_button").fillColor.alpha, 0, 0.0001, "translator should keep the copy hit area invisible")
	assert_close(find_element(direct_recorded.canvas_states[1].elements, "copy_icon_front").strokeColor.red, 0.22, 0.0001, "translator should use the selected theme accent color for the copy icon")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "copy_icon_front") ~= nil, "translator should render the copy icon")
	assert_true(find_element(direct_recorded.canvas_states[1].elements, "close_button") == nil, "translator should not render a close button")
	assert_true(type(direct_recorded.canvas_states[1].mouse_callback) == "function", "translator should register popup mouse handlers")
	assert_equal(direct_recorded.timers[2].seconds, 8, "translator should use the configured popup auto-hide duration")

	direct_recorded.canvas_states[1].mouse_callback(nil, "mouseDown", "copy_button")

	assert_equal(direct_recorded.pasteboard_sets[1], "你好，世界", "copy button should write the translation to the clipboard")
	assert_contains(direct_recorded.alerts[1], "译文已复制", "copy success should be surfaced to the user")

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
	assert_equal(direct_recorded.stopped_watchers, 2, "outside clicks should stop all popup watchers")
	assert_true(translator.stop(), "translator stop should succeed")
	assert_equal(direct_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding")
	assert_equal(direct_recorded.deleted_canvases, 1, "translator stop should not delete an already closed popup twice")

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
			api_url = "https://example.com/v1/chat/completions",
			model = "gpt-fallback",
			api_key_env = "OPENAI_API_KEY",
			clipboard_poll_interval_seconds = 0.05,
			clipboard_max_wait_seconds = 0.3,
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

	local ollama_recorded = {
		alerts = {},
		block_alerts = {},
		pasteboard_sets = {},
		async_posts = {},
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
			api_mode = "auto",
			api_url = "http://localhost:11434/v1/chat/completions",
			model = "qwen3.5:35b",
			api_key_env = "",
			api_key = "ollama",
			disable_thinking = true,
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
	ollama_recorded.bound_handler()

	assert_equal(
		ollama_recorded.async_posts[1].url,
		"http://localhost:11434/api/chat",
		"auto mode should route local Ollama requests to the native chat endpoint"
	)
	assert_equal(
		ollama_recorded.encoded_payload.think,
		false,
		"local Ollama mode should disable thinking by default when configured"
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
	assert_equal(ollama_recorded.started_watchers, 2, "local Ollama mode should start outside-click and hover watchers")
	assert_equal(ollama_recorded.canvas_states[1].frame.x, 540, "local Ollama mode should fall back to the mouse position when no selection bounds are available")
	assert_equal(ollama_recorded.canvas_states[1].frame.y, 276, "local Ollama mode should show above the mouse position when no selection bounds are available")
	assert_equal(find_element(ollama_recorded.canvas_states[1].elements, "body").text, "本地快速译文", "local Ollama mode should render the parsed translation in the popup")
	assert_true(translator.stop(), "translator stop should succeed after local Ollama request")
	assert_equal(ollama_recorded.hidden_canvases, 1, "translator stop should hide any active popup")
	assert_equal(ollama_recorded.deleted_canvases, 1, "translator stop should clean up the active popup canvas")
	assert_equal(ollama_recorded.stopped_watchers, 2, "translator stop should stop all popup watchers")
	assert_equal(ollama_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding in local Ollama mode")

	reset_modules()
	rawset(os, "getenv", original_getenv)
	hs = nil
end

return _M
