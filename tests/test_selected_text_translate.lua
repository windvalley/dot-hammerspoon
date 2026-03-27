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

function _M.run()
	reset_modules()

	local original_getenv = os.getenv

	local direct_recorded = {
		alerts = {},
		block_alerts = {},
		pasteboard_sets = {},
		async_posts = {},
		deleted_bindings = 0,
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
		dialog = {
			blockAlert = function(message, informative_text, button_one, button_two)
				table.insert(direct_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
					button_one = button_one,
					button_two = button_two,
				})

				return "复制译文"
			end,
		},
		timer = {
			doAfter = function(_, _)
				return {
					stop = function() end,
				}
			end,
		},
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "hello world"
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
	assert_equal(direct_recorded.block_alerts[1].message, "翻译结果", "translator should show a popup title")
	assert_equal(
		direct_recorded.block_alerts[1].informative_text,
		"你好，世界",
		"translator should show the translated text in the popup"
	)
	assert_equal(direct_recorded.pasteboard_sets[1], "你好，世界", "copy button should write the translation to the clipboard")
	assert_contains(direct_recorded.alerts[1], "译文已复制", "copy success should be surfaced to the user")
	assert_true(translator.stop(), "translator stop should succeed")
	assert_equal(direct_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding")

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
		timer = {
			doAfter = function(_, _)
				return {
					stop = function() end,
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
		dialog = {
			blockAlert = function(message, informative_text)
				table.insert(ollama_recorded.block_alerts, {
					message = message,
					informative_text = informative_text,
				})

				return "关闭"
			end,
		},
		timer = {
			doAfter = function(_, _)
				return {
					stop = function() end,
				}
			end,
		},
		uielement = {
			focusedElement = function()
				return {
					selectedText = function()
						return "fast local text"
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
	assert_equal(
		ollama_recorded.block_alerts[1].informative_text,
		"本地快速译文",
		"local Ollama mode should parse translation content from the native chat response"
	)
	assert_equal(#ollama_recorded.alerts, 0, "closing the local Ollama popup should not emit extra alerts")
	assert_true(translator.stop(), "translator stop should succeed after local Ollama request")
	assert_equal(ollama_recorded.deleted_bindings, 1, "translator stop should delete its hotkey binding in local Ollama mode")

	reset_modules()
	rawset(os, "getenv", original_getenv)
	hs = nil
end

return _M
