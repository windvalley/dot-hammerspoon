local _M = {}

_M.name = "selected_text_translate"
_M.description = "翻译当前选中的文本"

local selected_text_translate = require("keybindings_config").selected_text_translate or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local copy_list = utils_lib.copy_list
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers

local log = hs.logger.new("selectionTranslate")

local default_api_url = "https://api.openai.com/v1/chat/completions"
local default_model = "gpt-4o-mini"
local default_target_language = "简体中文"
local default_request_timeout_seconds = 20
local default_clipboard_poll_interval_seconds = 0.05
local default_clipboard_max_wait_seconds = 0.4
local default_api_mode = "auto"
local dialog_copy_button = "复制译文"
local dialog_close_button = "关闭"

local state = {
	started = false,
	start_ok = true,
	hotkey = nil,
	request_inflight = false,
	request_id = 0,
	request_timeout_timer = nil,
	clipboard_poll_timer = nil,
}

local function normalize_hotkey_key(raw_key)
	if raw_key == nil then
		return nil
	end

	local normalized = string.lower(trim(tostring(raw_key)))

	if normalized == "" or normalized == "none" or normalized == "disabled" then
		return nil
	end

	return normalized
end

local function normalize_number(value, fallback, minimum, maximum)
	local number = tonumber(value)

	if number == nil then
		number = fallback
	end

	if minimum ~= nil then
		number = math.max(minimum, number)
	end

	if maximum ~= nil then
		number = math.min(maximum, number)
	end

	return number
end

local function stop_timer(timer)
	if timer == nil then
		return
	end

	if type(timer.stop) == "function" then
		timer:stop()
	end
end

local function clear_request_timeout_timer()
	stop_timer(state.request_timeout_timer)
	state.request_timeout_timer = nil
end

local function clear_clipboard_poll_timer()
	stop_timer(state.clipboard_poll_timer)
	state.clipboard_poll_timer = nil
end

local function finish_request()
	state.request_inflight = false
	clear_request_timeout_timer()
	clear_clipboard_poll_timer()
end

local function request_timeout_seconds()
	return normalize_number(selected_text_translate.request_timeout_seconds, default_request_timeout_seconds, 3, 120)
end

local function clipboard_poll_interval_seconds()
	return normalize_number(
		selected_text_translate.clipboard_poll_interval_seconds,
		default_clipboard_poll_interval_seconds,
		0.02,
		0.5
	)
end

local function clipboard_max_wait_seconds()
	return normalize_number(
		selected_text_translate.clipboard_max_wait_seconds,
		default_clipboard_max_wait_seconds,
		0.05,
		2
	)
end

local function clipboard_poll_attempts()
	return math.max(1, math.ceil(clipboard_max_wait_seconds() / clipboard_poll_interval_seconds()))
end

local function popup_title()
	local title = trim(tostring(selected_text_translate.popup_title or ""))

	if title == "" then
		return "翻译结果"
	end

	return title
end

local function target_language()
	local language = trim(tostring(selected_text_translate.target_language or default_target_language))

	if language == "" then
		return default_target_language
	end

	return language
end

local function request_message()
	local message = trim(tostring(selected_text_translate.message or ""))

	if message == "" then
		return "Translate Selection"
	end

	return message
end

local function api_url()
	local url = trim(tostring(selected_text_translate.api_url or default_api_url))

	if url == "" then
		return default_api_url
	end

	return url
end

local function api_model()
	local model = trim(tostring(selected_text_translate.model or default_model))

	if model == "" then
		return default_model
	end

	return model
end

local function api_mode()
	local mode = string.lower(trim(tostring(selected_text_translate.api_mode or default_api_mode)))

	if mode == "" then
		mode = default_api_mode
	end

	if mode == "openai_compatible" or mode == "ollama_native" then
		return mode
	end

	return "auto"
end

local function url_uses_local_ollama(raw_url)
	local normalized = string.lower(trim(tostring(raw_url or "")))

	if normalized == "" then
		return false
	end

	return normalized:match("^https?://localhost:11434/") ~= nil
		or normalized:match("^https?://127%.0%.0%.1:11434/") ~= nil
end

local function resolved_api_mode()
	local configured_mode = api_mode()

	if configured_mode ~= "auto" then
		return configured_mode
	end

	if url_uses_local_ollama(api_url()) ~= true then
		return "openai_compatible"
	end

	local normalized = string.lower(api_url())

	if normalized:find("/api/chat", 1, true) ~= nil or normalized:find("/v1/chat/completions", 1, true) ~= nil then
		return "ollama_native"
	end

	return "openai_compatible"
end

local function disable_thinking()
	if selected_text_translate.disable_thinking ~= nil then
		return selected_text_translate.disable_thinking ~= false
	end

	return resolved_api_mode() == "ollama_native"
end

local function resolved_request_url()
	local url = api_url()

	if resolved_api_mode() ~= "ollama_native" then
		return url
	end

	if string.lower(url):find("/v1/chat/completions", 1, true) ~= nil then
		return (url:gsub("/v1/chat/completions$", "/api/chat"))
	end

	return url
end

local function api_key_env_name()
	return trim(tostring(selected_text_translate.api_key_env or "OPENAI_API_KEY"))
end

local function api_key()
	local configured = trim(tostring(selected_text_translate.api_key or ""))

	if configured ~= "" then
		return configured
	end

	local env_name = api_key_env_name()

	if env_name == "" then
		return ""
	end

	return trim(tostring(os.getenv(env_name) or ""))
end

local function sanitize_selected_text(text)
	local normalized = trim(tostring(text or ""))

	if normalized == "" then
		return nil
	end

	return normalized
end

local function current_selected_text()
	if type(hs.uielement) ~= "table" or type(hs.uielement.focusedElement) ~= "function" then
		return nil
	end

	local ok, element = pcall(hs.uielement.focusedElement)

	if ok ~= true or element == nil or type(element.selectedText) ~= "function" then
		return nil
	end

	local text_ok, text = pcall(function()
		return element:selectedText()
	end)

	if text_ok ~= true then
		log.w("failed to read selected text from accessibility element")
		return nil
	end

	return sanitize_selected_text(text)
end

local function clipboard_change_count()
	if type(hs.pasteboard) ~= "table" or type(hs.pasteboard.changeCount) ~= "function" then
		return nil
	end

	local ok, count = pcall(hs.pasteboard.changeCount)

	if ok ~= true then
		return nil
	end

	return tonumber(count)
end

local function snapshot_clipboard()
	local snapshot = {
		kind = "empty",
		change_count = clipboard_change_count(),
	}

	if type(hs.pasteboard) ~= "table" then
		return snapshot
	end

	if type(hs.pasteboard.readImage) == "function" then
		local ok, image = pcall(hs.pasteboard.readImage)

		if ok == true and image ~= nil then
			snapshot.kind = "image"
			snapshot.image = image
			return snapshot
		end
	end

	if type(hs.pasteboard.getContents) == "function" then
		local ok, text = pcall(hs.pasteboard.getContents)

		if ok == true and text ~= nil then
			snapshot.kind = "text"
			snapshot.text = text
		end
	end

	return snapshot
end

local function restore_clipboard(snapshot)
	if snapshot == nil or type(hs.pasteboard) ~= "table" then
		return
	end

	if snapshot.kind == "image" and type(hs.pasteboard.writeObjects) == "function" then
		pcall(hs.pasteboard.writeObjects, snapshot.image)
		return
	end

	if snapshot.kind == "text" and type(hs.pasteboard.setContents) == "function" then
		pcall(hs.pasteboard.setContents, snapshot.text)
		return
	end

	if snapshot.kind == "empty" and type(hs.pasteboard.clearContents) == "function" then
		pcall(hs.pasteboard.clearContents)
	end
end

local function suspend_clipboard_history(seconds)
	local clipboard_center = package.loaded["clipboard_center"]

	if type(clipboard_center) ~= "table" or type(clipboard_center.suspend_capture) ~= "function" then
		return
	end

	pcall(clipboard_center.suspend_capture, seconds)
end

local function system_prompt()
	return string.format(
		"你是翻译助手。请将用户提供的文本翻译成%s。只返回译文，不要解释，不要添加引号；尽量保留原文换行、列表和代码格式。",
		target_language()
	)
end

local function show_translation_dialog(result)
	if type(hs.dialog) == "table" and type(hs.dialog.blockAlert) == "function" then
		local button = hs.dialog.blockAlert(popup_title(), result, dialog_copy_button, dialog_close_button)

		if button == dialog_copy_button and type(hs.pasteboard) == "table" and type(hs.pasteboard.setContents) == "function" then
			if hs.pasteboard.setContents(result) == true then
				hs.alert.show("译文已复制到剪贴板")
			else
				hs.alert.show("复制译文失败")
			end
		end

		return
	end

	hs.alert.show(result)
end

local function decode_json(body)
	if type(hs.json) ~= "table" or type(hs.json.decode) ~= "function" then
		return nil
	end

	local ok, decoded = pcall(hs.json.decode, body)

	if ok ~= true then
		return nil
	end

	return decoded
end

local function summarize_error_message(body)
	local decoded = decode_json(body)

	if type(decoded) == "table" and type(decoded.error) == "table" then
		local message = sanitize_selected_text(decoded.error.message)

		if message ~= nil then
			return message
		end
	end

	local text = sanitize_selected_text(body)

	if text == nil then
		return "未知错误"
	end

	if #text > 120 then
		return string.sub(text, 1, 117) .. "..."
	end

	return text
end

local function extract_translation(response)
	if type(response) ~= "table" then
		return nil
	end

	if resolved_api_mode() == "ollama_native" then
		local message = response.message

		if type(message) == "table" then
			return sanitize_selected_text(message.content)
		end

		return sanitize_selected_text(response.response)
	end

	local choices = response.choices

	if type(choices) ~= "table" or type(choices[1]) ~= "table" then
		return nil
	end

	local first_choice = choices[1]
	local message = first_choice.message

	if type(message) == "table" then
		local content = message.content

		if type(content) == "string" then
			return sanitize_selected_text(content)
		end

		if type(content) == "table" then
			local parts = {}

			for _, part in ipairs(content) do
				if type(part) == "string" then
					local text = sanitize_selected_text(part)

					if text ~= nil then
						table.insert(parts, text)
					end
				elseif type(part) == "table" then
					local text = sanitize_selected_text(part.text or part.content)

					if text ~= nil then
						table.insert(parts, text)
					end
				end
			end

			if #parts > 0 then
				return table.concat(parts, "\n")
			end
		end
	end

	return sanitize_selected_text(first_choice.text)
end

local function show_request_error(message)
	finish_request()
	hs.alert.show(message)
end

local function request_translation(text)
	if type(hs.http) ~= "table" or type(hs.http.asyncPost) ~= "function" then
		show_request_error("当前 Hammerspoon 不支持 HTTP 请求")
		return
	end

	if type(hs.json) ~= "table" or type(hs.json.encode) ~= "function" then
		show_request_error("当前 Hammerspoon 不支持 JSON 编码")
		return
	end

	local key = api_key()

	if resolved_api_mode() ~= "ollama_native" and key == "" then
		show_request_error("未找到翻译 API Key，请配置 api_key 或环境变量")
		return
	end

	local payload = {
		model = api_model(),
		messages = {
			{
				role = "system",
				content = system_prompt(),
			},
			{
				role = "user",
				content = text,
			},
		},
	}

	if resolved_api_mode() == "ollama_native" then
		payload.stream = false

		if disable_thinking() == true then
			payload.think = false
		else
			payload.think = true
		end
	else
		payload.temperature = 0.2
	end

	local encoded_ok, encoded_payload = pcall(hs.json.encode, payload)

	if encoded_ok ~= true or type(encoded_payload) ~= "string" or encoded_payload == "" then
		show_request_error("翻译请求编码失败")
		return
	end

	state.request_id = state.request_id + 1
	local current_request_id = state.request_id

	clear_request_timeout_timer()
	state.request_timeout_timer = hs.timer.doAfter(request_timeout_seconds(), function()
		state.request_timeout_timer = nil

		if state.request_inflight == true and state.request_id == current_request_id then
			state.request_inflight = false
			clear_clipboard_poll_timer()
			state.request_id = state.request_id + 1
			hs.alert.show("翻译请求超时")
		end
	end)

	local headers = {
		["Content-Type"] = "application/json",
	}

	if resolved_api_mode() ~= "ollama_native" or key ~= "" then
		headers["Authorization"] = "Bearer " .. key
	end

	local ok, request_error = pcall(function()
		hs.http.asyncPost(resolved_request_url(), encoded_payload, headers, function(status, body, _)
			if current_request_id ~= state.request_id then
				return
			end

			finish_request()

			if tonumber(status) == nil or tonumber(status) < 200 or tonumber(status) >= 300 then
				hs.alert.show("翻译失败: " .. summarize_error_message(body))
				return
			end

			local response = decode_json(body)
			local translation = extract_translation(response)

			if translation == nil then
				hs.alert.show("翻译结果解析失败")
				return
			end

			show_translation_dialog(translation)
		end)
	end)

	if ok ~= true then
		log.e("failed to send translation request: " .. tostring(request_error))
		show_request_error("发起翻译请求失败")
	end
end

local function wait_for_copied_selection(snapshot, remaining_attempts, callback)
	local current_count = clipboard_change_count()

	if current_count ~= nil and snapshot.change_count ~= nil and current_count ~= snapshot.change_count then
		local copied_text = nil

		if type(hs.pasteboard) == "table" and type(hs.pasteboard.getContents) == "function" then
			copied_text = sanitize_selected_text(hs.pasteboard.getContents())
		end

		restore_clipboard(snapshot)
		callback(copied_text, copied_text ~= nil and nil or "当前选区不是可复制文本")
		return
	end

	if remaining_attempts <= 0 then
		restore_clipboard(snapshot)
		callback(nil, "未检测到选中文本，请确认应用支持复制")
		return
	end

	state.clipboard_poll_timer = hs.timer.doAfter(clipboard_poll_interval_seconds(), function()
		state.clipboard_poll_timer = nil
		wait_for_copied_selection(snapshot, remaining_attempts - 1, callback)
	end)
end

local function capture_selection_from_clipboard(callback)
	if
		type(hs.pasteboard) ~= "table"
		or type(hs.pasteboard.getContents) ~= "function"
		or type(hs.pasteboard.changeCount) ~= "function"
	then
		callback(nil, "当前 Hammerspoon 无法读取剪贴板")
		return
	end

	if type(hs.eventtap) ~= "table" or type(hs.eventtap.keyStroke) ~= "function" then
		callback(nil, "当前 Hammerspoon 无法模拟复制快捷键")
		return
	end

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		callback(nil, "当前 Hammerspoon 无法等待复制结果")
		return
	end

	local snapshot = snapshot_clipboard()
	suspend_clipboard_history(clipboard_max_wait_seconds() + 0.5)
	hs.eventtap.keyStroke({ "cmd" }, "c", 0)
	wait_for_copied_selection(snapshot, clipboard_poll_attempts(), callback)
end

local function translate_current_selection()
	if state.request_inflight == true then
		hs.alert.show("翻译请求进行中")
		return
	end

	state.request_inflight = true

	local text = current_selected_text()

	if text ~= nil then
		request_translation(text)
		return
	end

	capture_selection_from_clipboard(function(copied_text, error_message)
		if copied_text == nil then
			show_request_error(error_message or "未检测到选中文本")
			return
		end

		request_translation(copied_text)
	end)
end

local function create_hotkey_binding()
	local modifiers, invalid_modifier = normalize_hotkey_modifiers(selected_text_translate.prefix or {})

	if modifiers == nil then
		log.e("invalid selected text translate hotkey modifier in config: " .. tostring(invalid_modifier))
		return false, nil
	end

	local key = normalize_hotkey_key(selected_text_translate.key)

	if key == nil then
		return true, nil
	end

	local binding = hotkey_helper.bind(copy_list(modifiers), key, request_message(), function()
		translate_current_selection()
	end, nil, nil, { logger = log })

	if binding == nil then
		return false, nil
	end

	return true, binding
end

function _M.start()
	if state.started == true then
		return state.start_ok
	end

	if selected_text_translate.enabled == false then
		state.started = true
		state.start_ok = true
		return true
	end

	local ok, binding = create_hotkey_binding()

	state.started = true
	state.start_ok = ok
	state.hotkey = binding

	return ok
end

function _M.stop()
	finish_request()

	if state.hotkey ~= nil then
		state.hotkey:delete()
		state.hotkey = nil
	end

	state.started = false
	state.start_ok = true

	return true
end

return _M
