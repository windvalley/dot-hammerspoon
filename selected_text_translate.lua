local _M = {}

_M.name = "selected_text_translate"
_M.description = "翻译当前选中的文本"

local selected_text_translate = require("keybindings_config").selected_text_translate or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local copy_list = utils_lib.copy_list
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers
local has_utf8, utf8_lib = pcall(require, "utf8")

if has_utf8 ~= true then
	utf8_lib = nil
end

local log = hs.logger.new("selectionTranslate")

local default_api_url = "https://api.openai.com/v1/chat/completions"
local default_model = "gpt-4o-mini"
local default_target_language = "简体中文"
local default_chinese_target_language = "英文"
local default_translation_direction = "auto"
local default_request_timeout_seconds = 20
local default_clipboard_poll_interval_seconds = 0.05
local default_clipboard_max_wait_seconds = 0.4
local default_api_mode = "auto"
local default_popup_duration_seconds = 10
local default_popup_theme = "paper"
local default_popup_background_color = {
	red = 0.98,
	green = 0.97,
	blue = 0.95,
}
local default_popup_background_alpha = 0.98
local dialog_copy_button = "复制译文"
local dialog_close_button = "关闭"
local popup_margin = 24
local popup_min_width = 320
local popup_max_width = 540
local popup_min_height = 132
local popup_max_height = 336
local popup_body_line_height = 22
local popup_anchor_gap = 12
local popup_body_top = 56
local popup_divider_y = 46
local popup_chrome_height = 74
local popup_copy_button_size = 28
local popup_copy_button_inset = 14
local popup_theme_presets = {
	paper = {
		background = { red = 0.98, green = 0.97, blue = 0.95 },
		shadow = { white = 0, alpha = 0.16 },
		border = { white = 0, alpha = 0.08 },
		divider = { white = 0, alpha = 0.08 },
		title = { white = 0.2, alpha = 1 },
		body = { white = 0.12, alpha = 0.95 },
		copy_button = { red = 0.11, green = 0.49, blue = 0.95, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	mist = {
		background = { red = 0.94, green = 0.97, blue = 0.99 },
		shadow = { white = 0, alpha = 0.16 },
		border = { white = 0, alpha = 0.08 },
		divider = { white = 0, alpha = 0.08 },
		title = { white = 0.2, alpha = 1 },
		body = { white = 0.12, alpha = 0.95 },
		copy_button = { red = 0.15, green = 0.53, blue = 0.84, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	graphite = {
		background = { red = 0.14, green = 0.16, blue = 0.18 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.84 },
		body = { white = 1, alpha = 0.94 },
		copy_button = { red = 0.28, green = 0.53, blue = 0.94, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	slate = {
		background = { red = 0.17, green = 0.2, blue = 0.25 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.84 },
		body = { white = 1, alpha = 0.94 },
		copy_button = { red = 0.37, green = 0.62, blue = 0.98, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	ocean = {
		background = { red = 0.09, green = 0.18, blue = 0.29 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.86 },
		body = { white = 1, alpha = 0.95 },
		copy_button = { red = 0.22, green = 0.63, blue = 0.92, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	forest = {
		background = { red = 0.12, green = 0.23, blue = 0.18 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.86 },
		body = { white = 1, alpha = 0.95 },
		copy_button = { red = 0.24, green = 0.71, blue = 0.49, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	amber = {
		background = { red = 0.29, green = 0.2, blue = 0.08 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.88 },
		body = { white = 1, alpha = 0.96 },
		copy_button = { red = 0.95, green = 0.67, blue = 0.18, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	rose = {
		background = { red = 0.3, green = 0.17, blue = 0.18 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.88 },
		body = { white = 1, alpha = 0.96 },
		copy_button = { red = 0.93, green = 0.42, blue = 0.55, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	cocoa = {
		background = { red = 0.24, green = 0.18, blue = 0.15 },
		shadow = { white = 0, alpha = 0.28 },
		border = { white = 1, alpha = 0.12 },
		divider = { white = 1, alpha = 0.1 },
		title = { white = 1, alpha = 0.86 },
		body = { white = 1, alpha = 0.95 },
		copy_button = { red = 0.82, green = 0.6, blue = 0.39, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
	mint = {
		background = { red = 0.9, green = 0.97, blue = 0.94 },
		shadow = { white = 0, alpha = 0.16 },
		border = { white = 0, alpha = 0.08 },
		divider = { white = 0, alpha = 0.08 },
		title = { white = 0.2, alpha = 1 },
		body = { white = 0.12, alpha = 0.95 },
		copy_button = { red = 0.22, green = 0.68, blue = 0.56, alpha = 1 },
		copy_icon = { white = 1, alpha = 1 },
	},
}

local state = {
	started = false,
	start_ok = true,
	hotkey = nil,
	request_inflight = false,
	request_id = 0,
	request_timeout_timer = nil,
	clipboard_poll_timer = nil,
	popup_canvas = nil,
	popup_frame = nil,
	popup_hide_timer = nil,
	popup_click_watcher = nil,
	popup_hover_watcher = nil,
	popup_hovered = false,
}

local function copy_table(value)
	local copied = {}

	for key, item in pairs(value or {}) do
		copied[key] = item
	end

	return copied
end

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

local function clear_popup_hide_timer()
	stop_timer(state.popup_hide_timer)
	state.popup_hide_timer = nil
end

local function clear_popup_click_watcher()
	stop_timer(state.popup_click_watcher)
	state.popup_click_watcher = nil
end

local function clear_popup_hover_watcher()
	stop_timer(state.popup_hover_watcher)
	state.popup_hover_watcher = nil
end

local function destroy_popup()
	clear_popup_hide_timer()
	clear_popup_click_watcher()
	clear_popup_hover_watcher()
	state.popup_frame = nil
	state.popup_hovered = false

	if state.popup_canvas == nil then
		return
	end

	if type(state.popup_canvas.hide) == "function" then
		pcall(state.popup_canvas.hide, state.popup_canvas, 0)
	end

	if type(state.popup_canvas.delete) == "function" then
		pcall(state.popup_canvas.delete, state.popup_canvas)
	end

	state.popup_canvas = nil
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

local function popup_duration_seconds()
	return normalize_number(selected_text_translate.popup_duration_seconds, default_popup_duration_seconds, 0, 60)
end

local function normalize_unit_interval(value, fallback)
	return normalize_number(value, fallback, 0, 1)
end

local function parse_hex_color(value)
	local normalized = trim(tostring(value or "")):gsub("^#", "")

	if normalized:match("^[%da-fA-F]+$") == nil then
		return nil
	end

	if #normalized ~= 6 and #normalized ~= 8 then
		return nil
	end

	local function parse_channel(start_index)
		return tonumber(normalized:sub(start_index, start_index + 1), 16) / 255
	end

	local color = {
		red = parse_channel(1),
		green = parse_channel(3),
		blue = parse_channel(5),
	}

	if #normalized == 8 then
		color.alpha = parse_channel(7)
	end

	return color
end

local function normalize_color_table(value, fallback)
	local normalized = {}
	local source = type(value) == "table" and value or {}
	local parsed_hex = type(value) == "string" and parse_hex_color(value) or parse_hex_color(source.hex)

	if parsed_hex ~= nil then
		normalized = copy_table(parsed_hex)
	end

	if source.white ~= nil then
		normalized = {
			white = normalize_unit_interval(source.white, 1),
		}
	end

	if source.red ~= nil or source.green ~= nil or source.blue ~= nil then
		normalized.white = nil
		normalized.red = normalize_unit_interval(source.red, normalized.red or 0)
		normalized.green = normalize_unit_interval(source.green, normalized.green or 0)
		normalized.blue = normalize_unit_interval(source.blue, normalized.blue or 0)
	end

	if source.alpha ~= nil then
		normalized.alpha = normalize_unit_interval(source.alpha, normalized.alpha or default_popup_background_alpha)
	end

	if next(normalized) == nil then
		return copy_table(fallback)
	end

	return normalized
end

local function popup_theme_name()
	local theme_name = string.lower(trim(tostring(selected_text_translate.popup_theme or default_popup_theme)))

	if theme_name == "" then
		theme_name = default_popup_theme
	end

	if popup_theme_presets[theme_name] == nil then
		return default_popup_theme
	end

	return theme_name
end

local function popup_theme_preset()
	return popup_theme_presets[popup_theme_name()] or popup_theme_presets[default_popup_theme]
end

local function has_legacy_popup_background()
	return selected_text_translate.popup_background ~= nil or selected_text_translate.popup_background_color ~= nil
end

local function resolved_popup_background_alpha(color)
	if selected_text_translate.popup_background_alpha ~= nil then
		return normalize_unit_interval(selected_text_translate.popup_background_alpha, default_popup_background_alpha)
	end

	return normalize_unit_interval(type(color) == "table" and color.alpha, default_popup_background_alpha)
end

local function legacy_popup_background_fill_color()
	if has_legacy_popup_background() ~= true then
		return nil
	end

	local configured_background = selected_text_translate.popup_background

	if configured_background == nil then
		configured_background = selected_text_translate.popup_background_color
	end

	local color = normalize_color_table(configured_background, default_popup_background_color)
	color.alpha = resolved_popup_background_alpha(color)

	return color
end

local function popup_background_fill_color()
	local legacy_background = legacy_popup_background_fill_color()

	if legacy_background ~= nil then
		return legacy_background
	end

	local background = normalize_color_table(popup_theme_preset().background, default_popup_background_color)
	background.alpha = resolved_popup_background_alpha(background)

	return background
end

local function color_rgb_components(color)
	if type(color) ~= "table" then
		return 1, 1, 1
	end

	if color.white ~= nil then
		local white = normalize_unit_interval(color.white, 1)
		return white, white, white
	end

	return normalize_unit_interval(color.red, 1), normalize_unit_interval(color.green, 1), normalize_unit_interval(color.blue, 1)
end

local function popup_surface_is_light(color)
	local red, green, blue = color_rgb_components(color or popup_background_fill_color())
	local luminance = (red * 0.2126) + (green * 0.7152) + (blue * 0.0722)

	return luminance >= 0.62
end

local function popup_theme_colors()
	local legacy_background = legacy_popup_background_fill_color()

	if legacy_background ~= nil then
		local light_surface = popup_surface_is_light(legacy_background)

		return {
			background = legacy_background,
			shadow = {
				white = 0,
				alpha = light_surface == true and 0.18 or 0.28,
			},
			border = light_surface == true and { white = 0, alpha = 0.08 } or { white = 1, alpha = 0.12 },
			divider = light_surface == true and { white = 0, alpha = 0.08 } or { white = 1, alpha = 0.12 },
			title = light_surface == true and { white = 0.2, alpha = 1 } or { white = 1, alpha = 0.82 },
			body = light_surface == true and { white = 0.12, alpha = 0.95 } or { white = 1, alpha = 0.94 },
			copy_button = {
				red = 0.11,
				green = 0.49,
				blue = 0.95,
				alpha = 1,
			},
			copy_icon = {
				white = 1,
				alpha = 1,
			},
		}
	end

	local preset = popup_theme_preset()
	local background = popup_background_fill_color()

	return {
		background = background,
		shadow = normalize_color_table(preset.shadow, { white = 0, alpha = 0.18 }),
		border = normalize_color_table(preset.border, { white = 0, alpha = 0.08 }),
		divider = normalize_color_table(preset.divider, { white = 0, alpha = 0.08 }),
		title = normalize_color_table(preset.title, { white = 0.2, alpha = 1 }),
		body = normalize_color_table(preset.body, { white = 0.12, alpha = 0.95 }),
		copy_button = normalize_color_table(preset.copy_button, {
			red = 0.11,
			green = 0.49,
			blue = 0.95,
			alpha = 1,
		}),
		copy_icon = normalize_color_table(preset.copy_icon, {
			white = 1,
			alpha = 1,
		}),
	}
end

local function popup_title()
	local title = trim(tostring(selected_text_translate.popup_title or ""))

	if title == "" then
		return "翻译结果"
	end

	return title
end

local function translation_direction()
	local direction = string.lower(trim(tostring(selected_text_translate.translation_direction or default_translation_direction)))

	if direction == "to_target" then
		return "to_target"
	end

	return "auto"
end

local function target_language()
	local language = trim(tostring(selected_text_translate.target_language or default_target_language))

	if language == "" then
		return default_target_language
	end

	return language
end

local function chinese_target_language()
	local language = trim(tostring(selected_text_translate.chinese_target_language or default_chinese_target_language))

	if language == "" then
		return default_chinese_target_language
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

local function normalize_rect(rect)
	if type(rect) ~= "table" then
		return nil
	end

	local x = tonumber(rect.x)
	local y = tonumber(rect.y)
	local w = tonumber(rect.w)
	local h = tonumber(rect.h)

	if x == nil or y == nil or w == nil or h == nil or w < 0 or h < 0 then
		return nil
	end

	return {
		x = x,
		y = y,
		w = w,
		h = h,
	}
end

local function normalize_point(point)
	if type(point) ~= "table" then
		return nil
	end

	local x = tonumber(point.x)
	local y = tonumber(point.y)

	if x == nil or y == nil then
		return nil
	end

	return {
		x = x,
		y = y,
	}
end

local function normalize_text_range(range)
	if type(range) ~= "table" then
		return nil
	end

	local location = tonumber(range.location)
	local length = tonumber(range.length)

	if location == nil or length == nil or location < 0 or length <= 0 then
		return nil
	end

	return {
		location = location,
		length = length,
	}
end

local function current_focused_ax_element()
	if type(hs.axuielement) ~= "table" or type(hs.axuielement.systemWideElement) ~= "function" then
		return nil
	end

	local ok, system_wide_element = pcall(hs.axuielement.systemWideElement)

	if ok ~= true or system_wide_element == nil then
		return nil
	end

	local focused_ok, focused_element = pcall(function()
		return system_wide_element.AXFocusedUIElement
	end)

	if focused_ok ~= true then
		return nil
	end

	return focused_element
end

local function current_selection_bounds()
	local focused_element = current_focused_ax_element()

	if focused_element == nil then
		return nil
	end

	local text_range = normalize_text_range(focused_element.AXSelectedTextRange)

	if text_range == nil and type(focused_element.AXSelectedTextRanges) == "table" then
		text_range = normalize_text_range(focused_element.AXSelectedTextRanges[1])
	end

	if text_range == nil or type(focused_element.parameterizedAttributeValue) ~= "function" then
		return nil
	end

	local ok, bounds = pcall(
		focused_element.parameterizedAttributeValue,
		focused_element,
		"AXBoundsForRange",
		text_range
	)

	if ok ~= true then
		log.w("failed to resolve selected text bounds from accessibility element")
		return nil
	end

	return normalize_rect(bounds)
end

local function current_mouse_bounds()
	if type(hs.mouse) ~= "table" or type(hs.mouse.absolutePosition) ~= "function" then
		return nil
	end

	local ok, point = pcall(hs.mouse.absolutePosition)

	if ok ~= true then
		return nil
	end

	local normalized = normalize_point(point)

	if normalized == nil then
		return nil
	end

	return {
		x = normalized.x,
		y = normalized.y,
		w = 0,
		h = 0,
	}
end

local function current_popup_anchor_bounds()
	return current_selection_bounds() or current_mouse_bounds()
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

local function codepoint_is_han(codepoint)
	return (codepoint >= 0x3400 and codepoint <= 0x4DBF)
		or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
		or (codepoint >= 0xF900 and codepoint <= 0xFAFF)
		or (codepoint >= 0x20000 and codepoint <= 0x2A6DF)
		or (codepoint >= 0x2A700 and codepoint <= 0x2B73F)
		or (codepoint >= 0x2B740 and codepoint <= 0x2B81F)
		or (codepoint >= 0x2B820 and codepoint <= 0x2CEAF)
		or (codepoint >= 0x2CEB0 and codepoint <= 0x2EBEF)
		or (codepoint >= 0x30000 and codepoint <= 0x3134F)
end

local function contains_han_characters(text)
	local normalized = tostring(text or "")

	if normalized == "" then
		return false
	end

	if type(utf8_lib) == "table" and type(utf8_lib.codes) == "function" then
		local found = false
		local ok = pcall(function()
			for _, codepoint in utf8_lib.codes(normalized) do
				if codepoint_is_han(codepoint) == true then
					found = true
					break
				end
			end
		end)

		if ok == true then
			return found
		end
	end

	return normalized:find("[\228-\233][\128-\191][\128-\191]") ~= nil
end

local function resolved_target_language(text)
	if translation_direction() ~= "auto" then
		return target_language()
	end

	if contains_han_characters(text) == true then
		return chinese_target_language()
	end

	return target_language()
end

local function system_prompt(text)
	return string.format(
		"你是翻译助手。请将用户提供的文本翻译成%s。只返回译文，不要解释，不要添加引号；尽量保留原文换行、列表和代码格式。",
		resolved_target_language(text)
	)
end

local function copy_translation_to_clipboard(result, show_alert)
	if type(hs.pasteboard) ~= "table" or type(hs.pasteboard.setContents) ~= "function" then
		if show_alert == true then
			hs.alert.show("当前 Hammerspoon 无法写入剪贴板")
		end

		return false
	end

	local ok, copied = pcall(hs.pasteboard.setContents, result)

	if ok == true and copied == true then
		if show_alert == true then
			hs.alert.show("译文已复制到剪贴板")
		end

		return true
	end

	if show_alert == true then
		hs.alert.show("复制译文失败")
	end

	return false
end

local function resolve_target_screen_frame()
	local target_screen = nil

	if type(hs.window) == "table" and type(hs.window.focusedWindow) == "function" then
		local ok, focused_window = pcall(hs.window.focusedWindow)

		if ok == true and focused_window ~= nil and type(focused_window.screen) == "function" then
			local screen_ok, screen = pcall(function()
				return focused_window:screen()
			end)

			if screen_ok == true then
				target_screen = screen
			end
		end
	end

	if target_screen == nil and type(hs.screen) == "table" and type(hs.screen.mainScreen) == "function" then
		local ok, screen = pcall(hs.screen.mainScreen)

		if ok == true then
			target_screen = screen
		end
	end

	if target_screen ~= nil then
		if type(target_screen.frame) == "function" then
			local ok, frame = pcall(function()
				return target_screen:frame()
			end)

			if ok == true and type(frame) == "table" then
				return frame
			end
		end

		if type(target_screen.fullFrame) == "function" then
			local ok, frame = pcall(function()
				return target_screen:fullFrame()
			end)

			if ok == true and type(frame) == "table" then
				return frame
			end
		end
	end

	return {
		x = 0,
		y = 0,
		w = 1440,
		h = 900,
	}
end

local function estimate_text_units(text)
	local normalized = tostring(text or "")

	if normalized == "" then
		return 0
	end

	if type(utf8_lib) ~= "table" or type(utf8_lib.codes) ~= "function" then
		return #normalized
	end

	local units = 0
	local ok = pcall(function()
		for _, codepoint in utf8_lib.codes(normalized) do
			if codepoint == 9 then
				units = units + 2.5
			elseif codepoint == 32 then
				units = units + 0.45
			elseif codepoint <= 127 then
				units = units + 0.62
			else
				units = units + 1
			end
		end
	end)

	if ok ~= true then
		return #normalized
	end

	return units
end

local function split_lines(text)
	local lines = {}
	local normalized = tostring(text or "")

	if normalized == "" then
		return { "" }
	end

	for line in (normalized .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end

	if #lines == 0 then
		return { normalized }
	end

	return lines
end

local function clamp_number(value, minimum, maximum)
	if minimum ~= nil and maximum ~= nil and minimum > maximum then
		maximum = minimum
	end

	if minimum ~= nil then
		value = math.max(minimum, value)
	end

	if maximum ~= nil then
		value = math.min(maximum, value)
	end

	return value
end

local function point_in_rect(point, rect)
	if type(point) ~= "table" or type(rect) ~= "table" then
		return false
	end

	local x = tonumber(point.x)
	local y = tonumber(point.y)
	local rect_x = tonumber(rect.x)
	local rect_y = tonumber(rect.y)
	local rect_w = tonumber(rect.w)
	local rect_h = tonumber(rect.h)

	if x == nil or y == nil or rect_x == nil or rect_y == nil or rect_w == nil or rect_h == nil then
		return false
	end

	return x >= rect_x and x <= (rect_x + rect_w) and y >= rect_y and y <= (rect_y + rect_h)
end

local function current_mouse_position()
	if type(hs.mouse) ~= "table" or type(hs.mouse.absolutePosition) ~= "function" then
		return nil
	end

	local ok, point = pcall(hs.mouse.absolutePosition)

	if ok ~= true then
		return nil
	end

	return normalize_point(point)
end

local function schedule_popup_auto_hide()
	clear_popup_hide_timer()

	if state.popup_hovered == true then
		return
	end

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		return
	end

	local duration = popup_duration_seconds()

	if duration <= 0 then
		return
	end

	state.popup_hide_timer = hs.timer.doAfter(duration, function()
		state.popup_hide_timer = nil

		if state.popup_hovered ~= true then
			destroy_popup()
		end
	end)
end

local function set_popup_hovered(is_hovered)
	if state.popup_hovered == is_hovered then
		return
	end

	state.popup_hovered = is_hovered

	if is_hovered == true then
		clear_popup_hide_timer()
	else
		schedule_popup_auto_hide()
	end
end

local function refresh_popup_hover_state()
	local mouse_point = current_mouse_position()

	if mouse_point == nil then
		return
	end

	set_popup_hovered(point_in_rect(mouse_point, state.popup_frame))
end

local function resolve_popup_click_event_types()
	if
		type(hs.eventtap) ~= "table"
		or type(hs.eventtap.new) ~= "function"
		or type(hs.eventtap.event) ~= "table"
		or type(hs.eventtap.event.types) ~= "table"
	then
		return nil
	end

	local event_types = {}

	for _, name in ipairs({ "leftMouseDown", "rightMouseDown", "otherMouseDown" }) do
		if hs.eventtap.event.types[name] ~= nil then
			table.insert(event_types, hs.eventtap.event.types[name])
		end
	end

	if #event_types == 0 then
		return nil
	end

	return event_types
end

local function resolve_popup_hover_event_types()
	if
		type(hs.eventtap) ~= "table"
		or type(hs.eventtap.new) ~= "function"
		or type(hs.eventtap.event) ~= "table"
		or type(hs.eventtap.event.types) ~= "table"
	then
		return nil
	end

	local event_types = {}

	for _, name in ipairs({ "mouseMoved", "leftMouseDragged", "rightMouseDragged", "otherMouseDragged" }) do
		if hs.eventtap.event.types[name] ~= nil then
			table.insert(event_types, hs.eventtap.event.types[name])
		end
	end

	if #event_types == 0 then
		return nil
	end

	return event_types
end

local function start_popup_click_watcher()
	local event_types = resolve_popup_click_event_types()

	if event_types == nil then
		return
	end

	clear_popup_click_watcher()

	local ok, watcher = pcall(hs.eventtap.new, event_types, function()
		local click_point = current_mouse_position()

		if click_point == nil or point_in_rect(click_point, state.popup_frame) then
			return false
		end

		destroy_popup()
		return false
	end)

	if ok ~= true or watcher == nil then
		return
	end

	state.popup_click_watcher = watcher

	if type(watcher.start) == "function" then
		pcall(watcher.start, watcher)
	end
end

local function start_popup_hover_watcher()
	local event_types = resolve_popup_hover_event_types()

	if event_types == nil then
		return
	end

	clear_popup_hover_watcher()

	local ok, watcher = pcall(hs.eventtap.new, event_types, function()
		refresh_popup_hover_state()
		return false
	end)

	if ok ~= true or watcher == nil then
		return
	end

	state.popup_hover_watcher = watcher

	if type(watcher.start) == "function" then
		pcall(watcher.start, watcher)
	end
end

local function resolve_popup_origin(screen_frame, width, height, anchor_bounds)
	local min_x = screen_frame.x + popup_margin
	local max_x = screen_frame.x + screen_frame.w - popup_margin - width
	local min_y = screen_frame.y + popup_margin
	local max_y = screen_frame.y + screen_frame.h - popup_margin - height

	max_x = math.max(min_x, max_x)
	max_y = math.max(min_y, max_y)

	if anchor_bounds ~= nil then
		local anchored_x = anchor_bounds.x + ((anchor_bounds.w - width) / 2)
		local anchored_y = anchor_bounds.y - height - popup_anchor_gap

		if anchored_y < min_y then
			anchored_y = anchor_bounds.y + anchor_bounds.h + popup_anchor_gap
		end

		return {
			x = math.floor(clamp_number(anchored_x, min_x, max_x)),
			y = math.floor(clamp_number(anchored_y, min_y, max_y)),
		}
	end

	return {
		x = max_x,
		y = min_y,
	}
end

local function resolve_popup_layout(result, anchor_bounds)
	local screen_frame = resolve_target_screen_frame()
	local max_width = math.max(260, math.min(popup_max_width, screen_frame.w - (popup_margin * 2)))
	local min_width = math.min(popup_min_width, max_width)
	local natural_units = 0
	local wrapped_lines = 0

	for _, line in ipairs(split_lines(result)) do
		natural_units = math.max(natural_units, estimate_text_units(line))
	end

	local width = math.min(max_width, math.max(min_width, math.floor((natural_units * 10.5) + 64)))
	local body_width = width - 40

	local units_per_line = math.max(12, math.floor(body_width / 10.5))

	for _, line in ipairs(split_lines(result)) do
		wrapped_lines = wrapped_lines + math.max(1, math.ceil(estimate_text_units(line) / units_per_line))
	end

	local body_height = math.max(44, wrapped_lines * popup_body_line_height)
	local height = body_height + popup_chrome_height

	local max_height = math.max(150, math.min(popup_max_height, screen_frame.h - (popup_margin * 2)))
	local min_height = math.min(popup_min_height, max_height)

	height = math.min(max_height, math.max(min_height, height))
	body_height = math.max(44, height - popup_chrome_height)
	local popup_origin = resolve_popup_origin(screen_frame, width, height, anchor_bounds)

	return {
		x = popup_origin.x,
		y = popup_origin.y,
		w = width,
		h = height,
		body_width = body_width,
		body_height = body_height,
	}
end

local function resolve_popup_level()
	if type(hs.canvas) ~= "table" or type(hs.canvas.windowLevels) ~= "table" then
		return nil
	end

	if hs.canvas.windowLevels.modalPanel ~= nil then
		return hs.canvas.windowLevels.modalPanel
	end

	if hs.canvas.windowLevels.floating ~= nil then
		return hs.canvas.windowLevels.floating
	end

	if hs.canvas.windowLevels.overlay ~= nil then
		return hs.canvas.windowLevels.overlay
	end

	if hs.canvas.windowLevels.screenSaver ~= nil then
		return hs.canvas.windowLevels.screenSaver
	end

	return nil
end

local function show_translation_popup(result, anchor_bounds)
	if type(hs.canvas) ~= "table" or type(hs.canvas.new) ~= "function" then
		return false
	end

	local layout = resolve_popup_layout(result, anchor_bounds)

	destroy_popup()

	local canvas = hs.canvas.new({
		x = layout.x,
		y = layout.y,
		w = layout.w,
		h = layout.h,
	})

	if canvas == nil then
		return false
	end

	state.popup_canvas = canvas
	state.popup_frame = {
		x = layout.x,
		y = layout.y,
		w = layout.w,
		h = layout.h,
	}

	if type(canvas.behaviorAsLabels) == "function" then
		canvas:behaviorAsLabels({
			"canJoinAllSpaces",
			"fullScreenAuxiliary",
			"stationary",
			"ignoresCycle",
		})
	end

	if type(canvas.clickActivating) == "function" then
		canvas:clickActivating(false)
	end

	local level = resolve_popup_level()

	if level ~= nil and type(canvas.level) == "function" then
		canvas:level(level)
	end

	local theme = popup_theme_colors()
	local copy_button_x = layout.w - popup_copy_button_size - popup_copy_button_inset
	local copy_button_y = 10
	local copy_back_icon_frame = {
		x = copy_button_x + 9,
		y = copy_button_y + 6,
		w = 10,
		h = 11,
	}
	local copy_front_icon_frame = {
		x = copy_button_x + 7,
		y = copy_button_y + 9,
		w = 10,
		h = 11,
	}

	canvas:appendElements({
		id = "background",
		type = "rectangle",
		action = "fill",
		fillColor = theme.background,
		roundedRectRadii = {
			xRadius = 16,
			yRadius = 16,
		},
		withShadow = true,
		shadow = {
			blurRadius = 20,
			color = theme.shadow,
			offset = {
				h = 0,
				w = 0,
			},
		},
		frame = {
			x = 0,
			y = 0,
			w = layout.w,
			h = layout.h,
		},
	}, {
		id = "border",
		type = "rectangle",
		action = "stroke",
		strokeColor = theme.border,
		strokeWidth = 1,
		roundedRectRadii = {
			xRadius = 16,
			yRadius = 16,
		},
		frame = {
			x = 0.5,
			y = 0.5,
			w = layout.w - 1,
			h = layout.h - 1,
		},
	}, {
		id = "title",
		type = "text",
		text = popup_title(),
		textSize = 13,
		textColor = theme.title,
		frame = {
			x = 18,
			y = 14,
			w = layout.w - 68,
			h = 18,
		},
	}, {
		id = "copy_button",
		type = "rectangle",
		action = "fill",
		fillColor = {
			white = 0,
			alpha = 0,
		},
		frame = {
			x = copy_button_x,
			y = copy_button_y,
			w = popup_copy_button_size,
			h = popup_copy_button_size,
		},
		trackMouseDown = true,
		trackMouseByBounds = true,
	}, {
		id = "copy_icon_back",
		type = "rectangle",
		action = "stroke",
		strokeColor = theme.copy_button,
		strokeWidth = 1.6,
		roundedRectRadii = {
			xRadius = 2,
			yRadius = 2,
		},
		frame = copy_back_icon_frame,
		trackMouseDown = true,
		trackMouseByBounds = true,
	}, {
		id = "copy_icon_front",
		type = "rectangle",
		action = "stroke",
		strokeColor = theme.copy_button,
		strokeWidth = 1.6,
		roundedRectRadii = {
			xRadius = 2,
			yRadius = 2,
		},
		frame = copy_front_icon_frame,
		trackMouseDown = true,
		trackMouseByBounds = true,
	}, {
		id = "divider",
		type = "rectangle",
		action = "fill",
		fillColor = theme.divider,
		frame = {
			x = 18,
			y = popup_divider_y,
			w = layout.w - 36,
			h = 1,
		},
	}, {
		id = "body",
		type = "text",
		text = result,
		textSize = 15,
		textColor = theme.body,
		frame = {
			x = 18,
			y = popup_body_top,
			w = layout.body_width,
			h = layout.body_height,
		},
	})

	if type(canvas.mouseCallback) == "function" then
		canvas:mouseCallback(function(_, callback_message, element_id)
			if callback_message ~= "mouseDown" then
				return
			end

			if
				element_id == "copy_button"
				or element_id == "copy_icon_back"
				or element_id == "copy_icon_front"
			then
				copy_translation_to_clipboard(result, true)
			end
		end)
	end

	if type(canvas.show) == "function" then
		pcall(canvas.show, canvas, 0.08)
	end

	state.popup_hovered = false
	start_popup_click_watcher()
	start_popup_hover_watcher()
	refresh_popup_hover_state()
	schedule_popup_auto_hide()

	return true
end

local function show_translation_dialog(result, anchor_bounds)
	if show_translation_popup(result, anchor_bounds) == true then
		return
	end

	if type(hs.dialog) == "table" and type(hs.dialog.blockAlert) == "function" then
		local button = hs.dialog.blockAlert(popup_title(), result, dialog_copy_button, dialog_close_button)

		if button == dialog_copy_button then
			copy_translation_to_clipboard(result, true)
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

local function request_translation(text, anchor_bounds)
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
				content = system_prompt(text),
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

			show_translation_dialog(translation, anchor_bounds)
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
	local selection_bounds = current_popup_anchor_bounds()

	local text = current_selected_text()

	if text ~= nil then
		request_translation(text, selection_bounds)
		return
	end

	capture_selection_from_clipboard(function(copied_text, error_message)
		if copied_text == nil then
			show_request_error(error_message or "未检测到选中文本")
			return
		end

		request_translation(copied_text, selection_bounds)
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
	destroy_popup()

	if state.hotkey ~= nil then
		state.hotkey:delete()
		state.hotkey = nil
	end

	state.started = false
	state.start_ok = true

	return true
end

return _M
