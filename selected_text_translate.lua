local _M = {}

_M.name = "selected_text_translate"
_M.description = "翻译当前选中的文本或截图中的文字"

local selected_text_translate = require("keybindings_config").selected_text_translate or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local copy_list = utils_lib.copy_list
local prompt_text = utils_lib.prompt_text
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers
local format_hotkey = hotkey_helper.format_hotkey
local modifier_prompt_names = hotkey_helper.modifier_prompt_names or {}
local has_utf8, utf8_lib = pcall(require, "utf8")

if has_utf8 ~= true then
	utf8_lib = nil
end

local log = hs.logger.new("selectionTranslate")

local default_model_service = {
	provider = "openai_compatible",
	ollama = {
		api_url = "http://localhost:11434/api/chat",
		model = "qwen3.5:35b",
		supports_image_input = true,
	},
	openai_compatible = {
		api_url = "https://api.openai.com/v1/chat/completions",
		model = "gpt-4o-mini",
		api_key_env = "OPENAI_API_KEY",
		supports_image_input = true,
	},
	gemini = {
		api_url = "https://generativelanguage.googleapis.com/v1beta/models",
		model = "gemini-2.0-flash",
		api_key_env = "GEMINI_API_KEY",
		supports_image_input = true,
	},
	anthropic = {
		api_url = "https://api.anthropic.com/v1/messages",
		model = "claude-3-5-haiku-latest",
		api_key_env = "ANTHROPIC_API_KEY",
		supports_image_input = true,
	},
}
local default_target_language = "简体中文"
local default_chinese_target_language = "英文"
local default_translation_direction = "auto"
local default_request_message = "Translate Selection"
local default_screenshot_request_message = "Translate Screenshot"
local default_popup_title = "翻译结果"
local default_model_warmup_delay_seconds = 3
local default_request_timeout_seconds = 20
local default_clipboard_poll_interval_seconds = 0.05
local default_clipboard_max_wait_seconds = 0.4
local default_popup_duration_seconds = 10
local default_popup_theme = "paper"
local default_popup_background_color = {
	red = 0.98,
	green = 0.97,
	blue = 0.95,
}
local default_popup_background_alpha = 0.98
local runtime_settings_key = "selected_text_translate.runtime_overrides"
local menubar_autosave_name = "dot-hammerspoon.selected_text_translate"
local dialog_copy_button = "复制译文"
local dialog_close_button = "关闭"
local menubar_title_fallback = "译"
local default_image_translation_not_supported_message = "当前模型不支持图片输入，请切换到支持视觉的模型"
local default_screenshot_hotkey = {
	prefix = { "Option", "Shift" },
	key = "R",
	message = default_screenshot_request_message,
}
local popup_margin = 24
local popup_min_width = 320
local popup_max_width = 540
local popup_min_height = 132
local popup_max_height = 336
local popup_body_line_height = 22
local popup_anchor_gap = 12
local popup_body_top = 56
local popup_divider_y = 46
local popup_geometry = {
	body_min_height = 44,
	body_bottom_padding = 18,
	pager_height = 34,
	pager_button_width = 56,
	pager_button_height = 22,
	pager_button_inset = 14,
	corner_radius = 16,
	arrow_height = 8,
	arrow_outer_half_width = 15,
	arrow_inner_half_width = 9,
	arrow_overlap = 4,
	arrow_shoulder_offset = 2,
	border_arc_segments = 5,
}
local popup_copy_button_size = 28
local popup_copy_button_inset = 14
local menu_options = {
	target_language_presets = {
		"简体中文",
		"繁體中文",
		"英文",
		"日文",
		"韩文",
		"法文",
		"德文",
	},
	chinese_target_language_presets = {
		"繁體中文",
		"英文",
		"日文",
		"韩文",
		"法文",
		"德文",
	},
	popup_duration_presets = {
		0,
		5,
		8,
		10,
		15,
		20,
	},
	popup_alpha_presets = {
		0.72,
		0.82,
		0.88,
		0.94,
		1,
	},
	request_timeout_presets = {
		15,
		20,
		30,
		60,
	},
	popup_theme_order = {
		"paper",
		"mist",
		"graphite",
		"slate",
		"ocean",
		"forest",
		"amber",
		"rose",
		"cocoa",
		"mint",
	},
	popup_theme_labels = {
		paper = "Paper 米白",
		mist = "Mist 清雾",
		graphite = "Graphite 石墨",
		slate = "Slate 岩蓝",
		ocean = "Ocean 深海",
		forest = "Forest 松林",
		amber = "Amber 琥珀",
		rose = "Rose 玫瑰",
		cocoa = "Cocoa 可可",
		mint = "Mint 薄荷",
	},
	provider_order = {
		"ollama",
		"openai_compatible",
		"gemini",
		"anthropic",
	},
	provider_labels = {
		ollama = "Ollama",
		openai_compatible = "OpenAI 兼容",
		gemini = "Gemini",
		anthropic = "Anthropic",
	},
	translation_direction_labels = {
		auto = "自动双向",
		to_target = "固定目标语言",
	},
}
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
	screenshot_hotkey = nil,
	request_inflight = false,
	request_id = 0,
	request_timeout_timer = nil,
	clipboard_poll_timer = nil,
	model_warmup_timer = nil,
	popup_canvas = nil,
	popup_frame = nil,
	popup_hide_timer = nil,
	popup_click_watcher = nil,
	popup_hover_watcher = nil,
	popup_key_watcher = nil,
	popup_hovered = false,
	popup_result = nil,
	popup_anchor_bounds = nil,
	popup_page_index = 1,
	popup_page_count = 0,
	menubar = nil,
	menubar_forced = false,
	hotkey_error = nil,
	screenshot_hotkey_error = nil,
}

local runtime_overrides = {}
local config_utils = {}

function config_utils.copy_value(value)
	if type(value) ~= "table" then
		return value
	end

	local copied = {}

	for key, item in pairs(value or {}) do
		copied[key] = config_utils.copy_value(item)
	end

	return copied
end

local function copy_table(value)
	return config_utils.copy_value(value or {})
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

local function table_is_empty(table_value)
	return next(table_value or {}) == nil
end

function config_utils.merge_tables(base, overrides)
	local merged = copy_table(base or {})

	for key, value in pairs(overrides or {}) do
		if type(value) == "table" and type(merged[key]) == "table" then
			merged[key] = config_utils.merge_tables(merged[key], value)
		else
			merged[key] = config_utils.copy_value(value)
		end
	end

	return merged
end

function config_utils.normalize_path(path)
	if type(path) == "table" then
		return path
	end

	return { path }
end

function config_utils.get_path_value(root, path)
	local value = root

	for _, segment in ipairs(config_utils.normalize_path(path)) do
		if type(value) ~= "table" then
			return nil
		end

		value = value[segment]
	end

	return value
end

function config_utils.path_exists(root, path)
	return config_utils.get_path_value(root, path) ~= nil
end

function config_utils.set_path_value(root, path, value)
	local segments = config_utils.normalize_path(path)

	if #segments == 0 then
		return
	end

	local current = root

	for index = 1, #segments - 1 do
		local segment = segments[index]

		if type(current[segment]) ~= "table" then
			current[segment] = {}
		end

		current = current[segment]
	end

	current[segments[#segments]] = config_utils.copy_value(value)
end

function config_utils.clear_path_value(root, path)
	local segments = config_utils.normalize_path(path)

	if #segments == 0 then
		return
	end

	if #segments == 1 then
		root[segments[1]] = nil
		return
	end

	local stack = {}
	local current = root

	for index = 1, #segments - 1 do
		local segment = segments[index]

		if type(current[segment]) ~= "table" then
			return
		end

		stack[index] = {
			parent = current,
			key = segment,
		}
		current = current[segment]
	end

	current[segments[#segments]] = nil

	for index = #stack, 1, -1 do
		local parent = stack[index].parent
		local key = stack[index].key

		if type(parent[key]) == "table" and next(parent[key]) == nil then
			parent[key] = nil
		else
			break
		end
	end
end

function config_utils.sanitize_model_service_overrides(overrides)
	local sanitized = {}

	if type(overrides) ~= "table" then
		return sanitized
	end

	local provider_name = string.lower(trim(tostring(overrides.provider or "")))

	if menu_options.provider_labels[provider_name] ~= nil then
		sanitized.provider = provider_name
	end

	if tonumber(overrides.request_timeout_seconds) ~= nil then
		sanitized.request_timeout_seconds = tonumber(overrides.request_timeout_seconds)
	end

	if type(overrides.ollama) == "table" then
		local ollama = {}

		for _, field in ipairs({ "api_url", "model", "keep_alive" }) do
			if type(overrides.ollama[field]) == "string" then
				ollama[field] = tostring(overrides.ollama[field])
			end
		end

		if type(overrides.ollama.enable_warmup) == "boolean" then
			ollama.enable_warmup = overrides.ollama.enable_warmup
		end

	if type(overrides.ollama.disable_thinking) == "boolean" then
		ollama.disable_thinking = overrides.ollama.disable_thinking
	end

	if type(overrides.ollama.supports_image_input) == "boolean" then
		ollama.supports_image_input = overrides.ollama.supports_image_input
	end

		if table_is_empty(ollama) ~= true then
			sanitized.ollama = ollama
		end
	end

	for _, provider_key in ipairs({ "openai_compatible", "gemini", "anthropic" }) do
		if type(overrides[provider_key]) == "table" then
			local provider_settings = {}

		for _, field in ipairs({ "api_url", "model", "api_key_env", "api_key" }) do
			if type(overrides[provider_key][field]) == "string" then
				provider_settings[field] = tostring(overrides[provider_key][field])
			end
		end

		if type(overrides[provider_key].supports_image_input) == "boolean" then
			provider_settings.supports_image_input = overrides[provider_key].supports_image_input
		end

			if table_is_empty(provider_settings) ~= true then
				sanitized[provider_key] = provider_settings
			end
		end
	end

	return sanitized
end

local function current_config()
	return config_utils.merge_tables(selected_text_translate or {}, runtime_overrides or {})
end

local function sanitize_runtime_overrides(overrides)
	local sanitized = {}

	local function sanitize_hotkey_override_group(source)
		local normalized = {}

		if type(source) ~= "table" then
			return nil
		end

		if source.prefix ~= nil then
			local normalized_modifiers = normalize_hotkey_modifiers(source.prefix)

			if normalized_modifiers ~= nil then
				normalized.prefix = normalized_modifiers
			end
		end

		if source.key ~= nil then
			local normalized_key = normalize_hotkey_key(source.key)
			normalized.key = normalized_key == nil and "disabled" or normalized_key
		end

		if type(source.message) == "string" then
			normalized.message = tostring(source.message)
		end

		if table_is_empty(normalized) == true then
			return nil
		end

		return normalized
	end

	if type(overrides) ~= "table" then
		return sanitized
	end

	if type(overrides.enabled) == "boolean" then
		sanitized.enabled = overrides.enabled
	end

	if type(overrides.show_menubar) == "boolean" then
		sanitized.show_menubar = overrides.show_menubar
	end

	if overrides.prefix ~= nil then
		local normalized_modifiers = normalize_hotkey_modifiers(overrides.prefix)

		if normalized_modifiers ~= nil then
			sanitized.prefix = normalized_modifiers
		end
	end

	if overrides.key ~= nil then
		local normalized_key = normalize_hotkey_key(overrides.key)
		sanitized.key = normalized_key == nil and "disabled" or normalized_key
	end

	local screenshot_hotkey = sanitize_hotkey_override_group(overrides.screenshot_hotkey)

	if screenshot_hotkey ~= nil then
		sanitized.screenshot_hotkey = screenshot_hotkey
	end

	for _, field in ipairs({
		"message",
		"popup_title",
		"translation_direction",
		"target_language",
		"chinese_target_language",
		"popup_theme",
	}) do
		if type(overrides[field]) == "string" then
			sanitized[field] = tostring(overrides[field])
		end
	end

	for _, field in ipairs({
		"clipboard_poll_interval_seconds",
		"clipboard_max_wait_seconds",
		"popup_duration_seconds",
		"popup_background_alpha",
	}) do
		if tonumber(overrides[field]) ~= nil then
			sanitized[field] = tonumber(overrides[field])
		end
	end

	local model_service = config_utils.sanitize_model_service_overrides(overrides.model_service)

	if table_is_empty(model_service) ~= true then
		sanitized.model_service = model_service
	end

	return sanitized
end

local function persist_runtime_overrides()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" then
		return
	end

	if table_is_empty(runtime_overrides) == true then
		if type(hs.settings.clear) == "function" then
			hs.settings.clear(runtime_settings_key)
		end

		return
	end

	if type(hs.settings.set) == "function" then
		hs.settings.set(runtime_settings_key, runtime_overrides)
	end
end

local function load_runtime_overrides()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return {}
	end

	local saved = hs.settings.get(runtime_settings_key)
	local sanitized = sanitize_runtime_overrides(saved)

	if table_is_empty(sanitized) == true then
		if saved ~= nil and type(hs.settings.clear) == "function" then
			hs.settings.clear(runtime_settings_key)
		end

		return {}
	end

	if type(hs.settings.set) == "function" then
		hs.settings.set(runtime_settings_key, sanitized)
	end

	return sanitized
end

local function set_runtime_override(field, value)
	if value == nil then
		config_utils.clear_path_value(runtime_overrides, field)
	else
		config_utils.set_path_value(runtime_overrides, field, value)
	end

	persist_runtime_overrides()
end

runtime_overrides = load_runtime_overrides()

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

local function clear_model_warmup_timer()
	stop_timer(state.model_warmup_timer)
	state.model_warmup_timer = nil
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
	stop_timer(state.popup_key_watcher)
	state.popup_key_watcher = nil
	state.popup_frame = nil
	state.popup_hovered = false
	state.popup_result = nil
	state.popup_anchor_bounds = nil
	state.popup_page_index = 1
	state.popup_page_count = 0

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
	local config = current_config()
	local model_service = type(config.model_service) == "table" and config.model_service or {}

	return normalize_number(model_service.request_timeout_seconds, default_request_timeout_seconds, 3, 120)
end

local function clipboard_poll_interval_seconds()
	local config = current_config()
	return normalize_number(
		config.clipboard_poll_interval_seconds,
		default_clipboard_poll_interval_seconds,
		0.02,
		0.5
	)
end

local function clipboard_max_wait_seconds()
	local config = current_config()
	return normalize_number(
		config.clipboard_max_wait_seconds,
		default_clipboard_max_wait_seconds,
		0.05,
		2
	)
end

local function clipboard_poll_attempts()
	return math.max(1, math.ceil(clipboard_max_wait_seconds() / clipboard_poll_interval_seconds()))
end

local function popup_duration_seconds()
	local config = current_config()
	return normalize_number(config.popup_duration_seconds, default_popup_duration_seconds, 0, 60)
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
	local config = current_config()
	local theme_name = string.lower(trim(tostring(config.popup_theme or default_popup_theme)))

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
	local config = current_config()
	return config.popup_background ~= nil or config.popup_background_color ~= nil
end

local function resolved_popup_background_alpha(color)
	local config = current_config()

	if config.popup_background_alpha ~= nil then
		return normalize_unit_interval(config.popup_background_alpha, default_popup_background_alpha)
	end

	return normalize_unit_interval(type(color) == "table" and color.alpha, default_popup_background_alpha)
end

local function legacy_popup_background_fill_color()
	if has_legacy_popup_background() ~= true then
		return nil
	end

	local config = current_config()
	local configured_background = config.popup_background

	if configured_background == nil then
		configured_background = config.popup_background_color
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
	local config = current_config()
	local title = trim(tostring(config.popup_title or ""))

	if title == "" then
		return default_popup_title
	end

	return title
end

local function translation_direction()
	local config = current_config()
	local direction = string.lower(trim(tostring(config.translation_direction or default_translation_direction)))

	if direction == "to_target" then
		return "to_target"
	end

	return "auto"
end

local function target_language()
	local config = current_config()
	local language = trim(tostring(config.target_language or default_target_language))

	if language == "" then
		return default_target_language
	end

	return language
end

local function chinese_target_language()
	local config = current_config()
	local language = trim(tostring(config.chinese_target_language or default_chinese_target_language))

	if language == "" then
		return default_chinese_target_language
	end

	return language
end

local function request_message()
	local config = current_config()
	local message = trim(tostring(config.message or ""))

	if message == "" then
		return default_request_message
	end

	return message
end

function config_utils.screenshot_hotkey_config()
	local config = current_config()
	local hotkey = type(config.screenshot_hotkey) == "table" and config.screenshot_hotkey or {}

	return {
		prefix = copy_list(hotkey.prefix or default_screenshot_hotkey.prefix),
		key = hotkey.key ~= nil and hotkey.key or default_screenshot_hotkey.key,
		message = trim(tostring(hotkey.message or default_screenshot_hotkey.message)),
	}
end

function config_utils.screenshot_request_message()
	local hotkey = config_utils.screenshot_hotkey_config()

	if hotkey.message == "" then
		return default_screenshot_request_message
	end

	return hotkey.message
end

function config_utils.model_service_config()
	local config = current_config()

	if type(config.model_service) == "table" then
		return config.model_service
	end

	return {}
end

local function provider()
	local config = config_utils.model_service_config()
	local provider_name = string.lower(trim(tostring(config.provider or default_model_service.provider)))

	if menu_options.provider_labels[provider_name] ~= nil then
		return provider_name
	end

	return default_model_service.provider
end

local function normalized_provider_name(provider_name)
	local normalized = string.lower(trim(tostring(provider_name or "")))

	if menu_options.provider_labels[normalized] ~= nil then
		return normalized
	end

	return provider()
end

function config_utils.provider_config(provider_name)
	local config = config_utils.model_service_config()
	local settings = config[provider_name]

	if type(settings) == "table" then
		return settings
	end

	return {}
end

function config_utils.provider_supports_image_input(provider_name)
	provider_name = normalized_provider_name(provider_name)

	local config = config_utils.provider_config(provider_name)

	if type(config.supports_image_input) == "boolean" then
		return config.supports_image_input
	end

	local defaults = type(default_model_service[provider_name]) == "table" and default_model_service[provider_name] or {}

	if type(defaults.supports_image_input) == "boolean" then
		return defaults.supports_image_input
	end

	return true
end

local function api_url(provider_name)
	provider_name = normalized_provider_name(provider_name)
	local config = config_utils.provider_config(provider_name)
	local default_url = type(default_model_service[provider_name]) == "table" and default_model_service[provider_name].api_url
		or default_model_service.openai_compatible.api_url
	local url = trim(tostring(config.api_url or default_url))

	if url == "" then
		return default_url
	end

	return url
end

local function api_model(provider_name)
	provider_name = normalized_provider_name(provider_name)
	local config = config_utils.provider_config(provider_name)
	local default_value = type(default_model_service[provider_name]) == "table" and default_model_service[provider_name].model
		or default_model_service.openai_compatible.model
	local model = trim(tostring(config.model or default_value))

	if model == "" then
		return default_value
	end

	return model
end

local function resolved_api_mode()
	if provider() == "ollama" then
		return "ollama_native"
	end

	return provider()
end

local function disable_thinking()
	if provider() ~= "ollama" then
		return false
	end

	local config = config_utils.provider_config("ollama")

	if config.disable_thinking ~= nil then
		return config.disable_thinking ~= false
	end

	return true
end

local function resolved_request_url()
	local url = api_url()
	local provider_name = provider()

	if provider_name == "ollama" and string.lower(url):find("/v1/chat/completions", 1, true) ~= nil then
		return (url:gsub("/v1/chat/completions$", "/api/chat"))
	end

	if provider_name ~= "gemini" then
		return url
	end

	local normalized = trim(url):gsub("/+$", "")

	if normalized:find("{model}", 1, true) ~= nil then
		return normalized:gsub("{model}", api_model())
	end

	if normalized:find(":generateContent", 1, true) ~= nil then
		return normalized
	end

	if normalized:match("/models$") ~= nil then
		return normalized .. "/" .. api_model() .. ":generateContent"
	end

	if normalized:match("/models/[^/]+$") ~= nil then
		return normalized .. ":generateContent"
	end

	return normalized
end

local function api_key_env_name(provider_name)
	provider_name = normalized_provider_name(provider_name)

	if provider_name == "ollama" then
		return ""
	end

	local config = config_utils.provider_config(provider_name)
	local defaults = type(default_model_service[provider_name]) == "table" and default_model_service[provider_name] or {}

	return trim(tostring(config.api_key_env or defaults.api_key_env or ""))
end

function config_utils.provider_api_key(provider_name)
	provider_name = normalized_provider_name(provider_name)

	if provider_name == "ollama" then
		return ""
	end

	local config = config_utils.provider_config(provider_name)
	local configured = trim(tostring(config.api_key or ""))

	if configured ~= "" then
		return configured
	end

	local env_name = api_key_env_name(provider_name)

	if env_name == "" then
		return ""
	end

	return trim(tostring(os.getenv(env_name) or ""))
end

local function api_key()
	return config_utils.provider_api_key(provider())
end

local function model_keep_alive()
	if provider() ~= "ollama" then
		return nil
	end

	local config = config_utils.provider_config("ollama")
	local keep_alive = trim(tostring(config.keep_alive or ""))

	if keep_alive == "" then
		return nil
	end

	return keep_alive
end

local function enable_model_warmup()
	local config = config_utils.provider_config("ollama")
	return config.enable_warmup == true
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

local function current_selected_text_range()
	local focused_element = current_focused_ax_element()

	if focused_element == nil then
		return nil, nil
	end

	local text_range = normalize_text_range(focused_element.AXSelectedTextRange)

	if text_range == nil and type(focused_element.AXSelectedTextRanges) == "table" then
		text_range = normalize_text_range(focused_element.AXSelectedTextRanges[1])
	end

	return text_range, focused_element
end

local function current_selection_bounds()
	local text_range, focused_element = current_selected_text_range()

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

function config_utils.shell_quote(value)
	local normalized = tostring(value or "")
	return "'" .. normalized:gsub("'", "'\\''") .. "'"
end

function config_utils.url_decode(value)
	return tostring(value or ""):gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
end

function config_utils.remove_file(path)
	if type(path) ~= "string" or path == "" then
		return
	end

	pcall(os.remove, path)
end

function config_utils.file_exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local file = io.open(path, "rb")

	if file == nil then
		return false
	end

	file:close()
	return true
end

function config_utils.parse_data_url(data_url)
	local mime_type, encoded_data = tostring(data_url or ""):match("^data:([^;]+);base64,(.+)$")

	if mime_type == nil or encoded_data == nil then
		return nil
	end

	local base64_data = config_utils.url_decode(encoded_data)

	return {
		mime_type = mime_type,
		base64_data = base64_data,
		data_url = string.format("data:%s;base64,%s", mime_type, base64_data),
	}
end

function config_utils.image_payload_from_path(path)
	if type(hs.image) ~= "table" or type(hs.image.imageFromPath) ~= "function" then
		return nil, "当前 Hammerspoon 不支持图片读取"
	end

	local image = hs.image.imageFromPath(path)

	if image == nil then
		return nil, "读取截图失败"
	end

	if type(image.encodeAsURLString) ~= "function" then
		return nil, "当前 Hammerspoon 不支持图片编码"
	end

	local encoded_ok, encoded = pcall(function()
		return image:encodeAsURLString(true, "PNG")
	end)

	if encoded_ok ~= true or type(encoded) ~= "string" or encoded == "" then
		return nil, "截图编码失败"
	end

	local payload = config_utils.parse_data_url(encoded)

	if payload == nil then
		return nil, "截图编码失败"
	end

	return payload, nil
end

function config_utils.capture_screenshot_image_payload()
	if type(hs.execute) ~= "function" then
		return nil, "当前 Hammerspoon 不支持截图命令", false
	end

	local temp_path = os.tmpname()

	if type(temp_path) ~= "string" or temp_path == "" then
		return nil, "无法创建截图临时文件", false
	end

	if temp_path:sub(-4):lower() ~= ".png" then
		temp_path = temp_path .. ".png"
	end

	config_utils.remove_file(temp_path)

	local ok = pcall(function()
		hs.execute("/usr/sbin/screencapture -i -x " .. config_utils.shell_quote(temp_path), true)
	end)

	local payload = nil
	local error_message = nil

	if config_utils.file_exists(temp_path) == true then
		payload, error_message = config_utils.image_payload_from_path(temp_path)
	end

	config_utils.remove_file(temp_path)

	if payload ~= nil then
		return payload, nil, false
	end

	if ok ~= true then
		return nil, "发起截图失败", false
	end

	if error_message ~= nil then
		return nil, error_message, false
	end

	return nil, "已取消截图翻译", true
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

	if type(hs.pasteboard.readAllData) == "function" then
		local ok, raw_data = pcall(hs.pasteboard.readAllData)

		if ok == true and type(raw_data) == "table" then
			snapshot.has_raw_data = true
			snapshot.raw_data = raw_data
		end
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

	if snapshot.has_raw_data == true and type(snapshot.raw_data) == "table" and type(hs.pasteboard.writeAllData) == "function" then
		local ok, restored = pcall(hs.pasteboard.writeAllData, snapshot.raw_data)

		if ok == true and restored == true then
			return
		end
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

local function text_system_prompt(text)
	return string.format(
		"你是翻译助手。请将用户提供的文本翻译成%s。只返回译文，不要解释，不要添加引号；尽量保留原文的段落、列表和代码格式，但不要为了贴合原文逐行硬换行，也不要拆开英文单词。",
		resolved_target_language(text)
	)
end

local function image_system_prompt()
	if translation_direction() == "to_target" then
		return string.format(
			"你是翻译助手。请先识别截图中的文字，再将其翻译成%s。必须翻译所有人类可读的自然语言内容，包括标题、状态标签、终端输出中的说明文字、表头、菜单项、按钮文字、提示语和普通句子；不要只是转写原文。只有命令、文件路径、URL、代码标识符、参数名、文件名、数字和符号等技术片段可以按需保留。只返回最终译文，不要解释，不要描述画面，不要添加引号；尽量保留原文的段落、列表和代码格式，但不要为了贴合截图逐行硬换行，也不要拆开英文单词。如果截图中没有可识别文字，只返回“未识别到可翻译文字”。",
			target_language()
		)
	end

	return string.format(
		"你是翻译助手。请先识别截图中的文字，再执行翻译：如果截图中的主要文字包含中文字符，则翻译成%s；否则翻译成%s。必须翻译所有人类可读的自然语言内容，包括标题、状态标签、终端输出中的说明文字、表头、菜单项、按钮文字、提示语和普通句子；不要只是转写原文。只有命令、文件路径、URL、代码标识符、参数名、文件名、数字和符号等技术片段可以按需保留。只返回最终译文，不要解释，不要描述画面，不要添加引号；尽量保留原文的段落、列表和代码格式，但不要为了贴合截图逐行硬换行，也不要拆开英文单词。如果截图中没有可识别文字，只返回“未识别到可翻译文字”。",
		chinese_target_language(),
		target_language()
	)
end

local function image_user_prompt()
	return "请先识别并翻译这张截图中的文字。英文标题、标签、按钮、菜单和终端说明文字不要原样抄回；如果它们是人类可读文本，请翻译。请输出适合阅读的最终译文，保留段落或列表结构，不要逐行硬换行。"
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
				units = units + 3.2
			elseif codepoint == 32 then
				units = units + 0.4
			elseif codepoint <= 127 then
				units = units + 0.68
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

function config_utils.split_text_characters(text)
	local characters = {}
	local normalized = tostring(text or "")

	if normalized == "" then
		return characters
	end

	if type(utf8_lib) == "table" and type(utf8_lib.codes) == "function" then
		local positions = {}
		local ok = pcall(function()
			for position in utf8_lib.codes(normalized) do
				table.insert(positions, position)
			end
		end)

		if ok == true and #positions > 0 then
			for index, position in ipairs(positions) do
				local next_position = positions[index + 1] or (#normalized + 1)
				table.insert(characters, normalized:sub(position, next_position - 1))
			end

			return characters
		end
	end

	for index = 1, #normalized do
		table.insert(characters, normalized:sub(index, index))
	end

	return characters
end

local function append_wrapped_line(wrapped, line)
	local normalized = tostring(line or "")
	local trimmed = normalized:gsub("%s+$", "")

	if trimmed == "" and normalized ~= "" and normalized:match("^%s+$") ~= nil then
		trimmed = normalized
	end

	table.insert(wrapped, trimmed)
end

local function is_ascii_non_space_character(character)
	local byte = type(character) == "string" and string.byte(character) or nil

	return byte ~= nil and byte <= 127 and character:match("%s") == nil
end

function config_utils.wrap_text_tokens(line)
	local tokens = {}
	local buffer = ""
	local buffer_mode = nil

	for _, character in ipairs(config_utils.split_text_characters(line)) do
		local current_mode

		if character:match("%s") ~= nil then
			current_mode = "space"
		elseif is_ascii_non_space_character(character) == true then
			current_mode = "ascii"
		else
			current_mode = "other"
		end

		if current_mode == "other" then
			if buffer ~= "" then
				table.insert(tokens, buffer)
				buffer = ""
				buffer_mode = nil
			end

			table.insert(tokens, character)
		elseif buffer_mode == current_mode then
			buffer = buffer .. character
		else
			if buffer ~= "" then
				table.insert(tokens, buffer)
			end

			buffer = character
			buffer_mode = current_mode
		end
	end

	if buffer ~= "" then
		table.insert(tokens, buffer)
	end

	if #tokens == 0 then
		return { "" }
	end

	return tokens
end

function config_utils.wrap_text_line(line, units_per_line)
	local wrapped = {}
	local current_line = ""
	local current_units = 0
	local safe_units_per_line = math.max(1, tonumber(units_per_line) or 1)

	if line == "" then
		return { "" }
	end

	local function push_current_line()
		if current_line == "" then
			return
		end

		append_wrapped_line(wrapped, current_line)
		current_line = ""
		current_units = 0
	end

	local function append_character(character)
		local character_units = math.max(0.25, estimate_text_units(character))

		if current_line ~= "" and (current_units + character_units) > safe_units_per_line then
			push_current_line()
		end

		current_line = current_line .. character
		current_units = current_units + character_units
	end

	for _, token in ipairs(config_utils.wrap_text_tokens(line)) do
		local token_units = math.max(0.25, estimate_text_units(token))
		local token_is_space = token:match("^%s+$") ~= nil

		if token_units > safe_units_per_line and token_is_space ~= true then
			for _, character in ipairs(config_utils.split_text_characters(token)) do
				append_character(character)
			end
		else
			if current_line ~= "" and (current_units + token_units) > safe_units_per_line then
				push_current_line()

				if token_is_space == true then
					goto continue
				end
			end

			current_line = current_line .. token
			current_units = current_units + token_units
		end

		::continue::
	end

	if current_line ~= "" then
		append_wrapped_line(wrapped, current_line)
	end

	if #wrapped == 0 then
		return { "" }
	end

	return wrapped
end

function config_utils.wrap_text_lines(text, units_per_line)
	local wrapped = {}

	for _, line in ipairs(split_lines(text)) do
		for _, wrapped_line in ipairs(config_utils.wrap_text_line(line, units_per_line)) do
			table.insert(wrapped, wrapped_line)
		end
	end

	if #wrapped == 0 then
		return { "" }
	end

	return wrapped
end

function config_utils.build_popup_pages(wrapped_lines, visible_line_count)
	local pages = {}
	local page_size = math.max(1, math.floor(visible_line_count or 1))
	local start_index = 1

	while start_index <= #wrapped_lines do
		local page_lines = {}
		local end_index = math.min(#wrapped_lines, start_index + page_size - 1)

		for line_index = start_index, end_index do
			table.insert(page_lines, wrapped_lines[line_index])
		end

		table.insert(pages, table.concat(page_lines, "\n"))
		start_index = end_index + 1
	end

	if #pages == 0 then
		return { "" }
	end

	return pages
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

function config_utils.popup_chrome_height(has_pager)
	return popup_body_top + (has_pager == true and popup_geometry.pager_height or popup_geometry.body_bottom_padding)
end

function config_utils.popup_page_indicator_text(page_index, page_count)
	return string.format("第 %d / %d 页", page_index, page_count)
end

function config_utils.popup_control_color(color, is_enabled)
	local resolved = copy_table(color or {})
	local base_alpha = tonumber(resolved.alpha)

	if base_alpha == nil then
		base_alpha = 1
	end

	resolved.alpha = clamp_number(base_alpha * (is_enabled == true and 1 or 0.38), 0, 1)

	return resolved
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
		local anchor_gap = popup_anchor_gap + popup_geometry.arrow_height
		local anchored_x = anchor_bounds.x + ((anchor_bounds.w - width) / 2)
		local anchored_y = anchor_bounds.y - height - anchor_gap
		local placement = "above"
		local below_y = anchor_bounds.y + anchor_bounds.h + anchor_gap

		if anchored_y < min_y and below_y <= max_y then
			anchored_y = below_y
			placement = "below"
		elseif anchored_y < min_y then
			anchored_y = min_y
		end

		return {
			x = math.floor(clamp_number(anchored_x, min_x, max_x)),
			y = math.floor(clamp_number(anchored_y, min_y, max_y)),
			placement = placement,
		}
	end

	return {
		x = max_x,
		y = min_y,
		placement = "none",
	}
end

local function resolve_popup_layout(result, anchor_bounds, page_index)
	local screen_frame = resolve_target_screen_frame()
	local max_width = math.max(260, math.min(popup_max_width, screen_frame.w - (popup_margin * 2)))
	local min_width = math.min(popup_min_width, max_width)
	local natural_units = 0

	for _, line in ipairs(split_lines(result)) do
		natural_units = math.max(natural_units, estimate_text_units(line))
	end

	local width = math.min(max_width, math.max(min_width, math.floor((natural_units * 10.5) + 64)))
	local body_width = width - 40
	local units_per_line = math.max(10, math.floor((body_width - 10) / 11.6))
	local wrapped_lines = config_utils.wrap_text_lines(result, units_per_line)
	local natural_body_height = math.max(popup_geometry.body_min_height, #wrapped_lines * popup_body_line_height)

	local max_height = math.max(150, math.min(popup_max_height, screen_frame.h - (popup_margin * 2)))
	local base_min_height = math.min(popup_min_height, max_height)
	local base_chrome_height = config_utils.popup_chrome_height(false)
	local base_height = math.min(max_height, math.max(base_min_height, natural_body_height + base_chrome_height))
	local base_body_height = math.max(popup_geometry.body_min_height, base_height - base_chrome_height)
	local visible_lines = math.max(1, math.floor(base_body_height / popup_body_line_height))
	local pages = config_utils.build_popup_pages(wrapped_lines, visible_lines)
	local show_pager = #pages > 1
	local chrome_height = config_utils.popup_chrome_height(show_pager)
	local min_height = math.max(base_min_height, math.min(max_height, chrome_height + popup_geometry.body_min_height))
	local height = math.min(max_height, math.max(min_height, natural_body_height + chrome_height))
	local body_height = math.max(popup_geometry.body_min_height, height - chrome_height)
	local footer_height = show_pager == true and popup_geometry.pager_height or 0

	visible_lines = math.max(1, math.floor(body_height / popup_body_line_height))
	pages = config_utils.build_popup_pages(wrapped_lines, visible_lines)

	local page_count = math.max(1, #pages)
	local safe_page_index = clamp_number(math.floor(tonumber(page_index) or 1), 1, page_count)
	local popup_origin = resolve_popup_origin(screen_frame, width, height, anchor_bounds)
	local surface_y = 0
	local canvas_y = popup_origin.y
	local canvas_height = height
	local arrow_tip_x = nil

	if anchor_bounds ~= nil then
		local anchor_center_x = anchor_bounds.x + (anchor_bounds.w / 2)
		local arrow_edge_inset = popup_geometry.corner_radius + popup_geometry.arrow_outer_half_width + 6
		local max_arrow_x = math.max(arrow_edge_inset, width - arrow_edge_inset)

		arrow_tip_x = math.floor(clamp_number(anchor_center_x - popup_origin.x, arrow_edge_inset, max_arrow_x) + 0.5)
		canvas_height = height + popup_geometry.arrow_height

		if popup_origin.placement == "below" then
			surface_y = popup_geometry.arrow_height
			canvas_y = popup_origin.y - popup_geometry.arrow_height
		end
	end

	return {
		x = popup_origin.x,
		y = canvas_y,
		w = width,
		h = canvas_height,
		surface_y = surface_y,
		surface_h = height,
		body_width = body_width,
		body_height = body_height,
		footer_height = footer_height,
		placement = popup_origin.placement,
		arrow_tip_x = arrow_tip_x,
		page_index = safe_page_index,
		page_count = page_count,
		page_text = pages[safe_page_index],
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

function config_utils.change_popup_page(delta)
	local current_result = state.popup_result

	if current_result == nil or state.popup_page_count <= 1 then
		return false
	end

	local next_page_index = clamp_number((state.popup_page_index or 1) + delta, 1, state.popup_page_count)

	if next_page_index == state.popup_page_index then
		return false
	end

	return config_utils.show_translation_popup(current_result, state.popup_anchor_bounds, next_page_index)
end

function config_utils.build_popup_arrow_elements(layout, theme)
	if layout.arrow_tip_x == nil then
		return nil, nil
	end

	local tip_y = 0.5
	local shoulder_y = layout.surface_y - popup_geometry.arrow_shoulder_offset + 0.5
	local hidden_y = layout.surface_y + popup_geometry.arrow_overlap - 0.5

	if layout.placement ~= "below" then
		local surface_bottom = layout.surface_y + layout.surface_h
		tip_y = layout.h - 0.5
		shoulder_y = surface_bottom + popup_geometry.arrow_shoulder_offset - 0.5
		hidden_y = surface_bottom - popup_geometry.arrow_overlap + 0.5
	end

	local coordinates = {
		{ x = layout.arrow_tip_x - popup_geometry.arrow_outer_half_width, y = hidden_y },
		{ x = layout.arrow_tip_x - popup_geometry.arrow_inner_half_width, y = shoulder_y },
		{ x = layout.arrow_tip_x, y = tip_y },
		{ x = layout.arrow_tip_x + popup_geometry.arrow_inner_half_width, y = shoulder_y },
		{ x = layout.arrow_tip_x + popup_geometry.arrow_outer_half_width, y = hidden_y },
	}

	local shadow = {
		id = "arrow_shadow",
		type = "segments",
		action = "fill",
		closed = true,
		fillColor = theme.background,
		withShadow = true,
		shadow = {
			blurRadius = 20,
			color = theme.shadow,
			offset = {
				h = 0,
				w = 0,
			},
		},
		coordinates = coordinates,
	}
	local fill = {
		id = "arrow_fill",
		type = "segments",
		action = "fill",
		closed = true,
		fillColor = theme.background,
		coordinates = coordinates,
	}
	return shadow, fill
end

function config_utils.append_arc_points(points, center_x, center_y, radius, start_angle, end_angle, segments)
	local safe_segments = math.max(1, segments or popup_geometry.border_arc_segments)

	for step = 1, safe_segments do
		local progress = step / safe_segments
		local angle = start_angle + ((end_angle - start_angle) * progress)
		local radians = math.rad(angle)

		table.insert(points, {
			x = center_x + (math.cos(radians) * radius),
			y = center_y + (math.sin(radians) * radius),
		})
	end
end

function config_utils.build_popup_border_coordinates(layout)
	local left = 0.5
	local top = layout.surface_y + 0.5
	local right = layout.w - 0.5
	local bottom = layout.surface_y + layout.surface_h - 0.5
	local radius = math.max(0, popup_geometry.corner_radius - 0.5)
	local points = {
		{ x = left + radius, y = top },
	}

	if layout.arrow_tip_x ~= nil and layout.placement == "below" then
		table.insert(points, {
			x = layout.arrow_tip_x - popup_geometry.arrow_outer_half_width,
			y = top,
		})
		table.insert(points, {
			x = layout.arrow_tip_x - popup_geometry.arrow_inner_half_width,
			y = top - popup_geometry.arrow_shoulder_offset,
		})
		table.insert(points, {
			x = layout.arrow_tip_x,
			y = top - popup_geometry.arrow_height,
		})
		table.insert(points, {
			x = layout.arrow_tip_x + popup_geometry.arrow_inner_half_width,
			y = top - popup_geometry.arrow_shoulder_offset,
		})
		table.insert(points, {
			x = layout.arrow_tip_x + popup_geometry.arrow_outer_half_width,
			y = top,
		})
	end

	table.insert(points, { x = right - radius, y = top })
	config_utils.append_arc_points(
		points,
		right - radius,
		top + radius,
		radius,
		270,
		360,
		popup_geometry.border_arc_segments
	)
	table.insert(points, { x = right, y = bottom - radius })
	config_utils.append_arc_points(
		points,
		right - radius,
		bottom - radius,
		radius,
		0,
		90,
		popup_geometry.border_arc_segments
	)

	if layout.arrow_tip_x ~= nil and layout.placement ~= "below" then
		table.insert(points, {
			x = layout.arrow_tip_x + popup_geometry.arrow_outer_half_width,
			y = bottom,
		})
		table.insert(points, {
			x = layout.arrow_tip_x + popup_geometry.arrow_inner_half_width,
			y = bottom + popup_geometry.arrow_shoulder_offset,
		})
		table.insert(points, {
			x = layout.arrow_tip_x,
			y = bottom + popup_geometry.arrow_height,
		})
		table.insert(points, {
			x = layout.arrow_tip_x - popup_geometry.arrow_inner_half_width,
			y = bottom + popup_geometry.arrow_shoulder_offset,
		})
		table.insert(points, {
			x = layout.arrow_tip_x - popup_geometry.arrow_outer_half_width,
			y = bottom,
		})
	end

	table.insert(points, { x = left + radius, y = bottom })
	config_utils.append_arc_points(
		points,
		left + radius,
		bottom - radius,
		radius,
		90,
		180,
		popup_geometry.border_arc_segments
	)
	table.insert(points, { x = left, y = top + radius })
	config_utils.append_arc_points(
		points,
		left + radius,
		top + radius,
		radius,
		180,
		270,
		popup_geometry.border_arc_segments
	)

	return points
end

function config_utils.show_translation_popup(result, anchor_bounds, page_index)
	if type(hs.canvas) ~= "table" or type(hs.canvas.new) ~= "function" then
		return false
	end

	local layout = resolve_popup_layout(result, anchor_bounds, page_index)

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
	state.popup_result = result
	state.popup_anchor_bounds = anchor_bounds == nil and nil or copy_table(anchor_bounds)
	state.popup_page_index = layout.page_index
	state.popup_page_count = layout.page_count

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
	local arrow_shadow, arrow_fill = config_utils.build_popup_arrow_elements(layout, theme)
	local popup_border = {
		id = "arrow_border",
		type = "segments",
		action = "stroke",
		closed = true,
		strokeColor = theme.border,
		strokeWidth = 1,
		strokeJoinStyle = "round",
		strokeCapStyle = "round",
		coordinates = config_utils.build_popup_border_coordinates(layout),
	}

	local copy_button_x = layout.w - popup_copy_button_size - popup_copy_button_inset
	local copy_button_y = layout.surface_y + 10
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
	local pager_top = layout.surface_y + layout.surface_h - layout.footer_height
	local prev_page_enabled = layout.page_index > 1
	local next_page_enabled = layout.page_index < layout.page_count
	local prev_page_button_frame = {
		x = popup_geometry.pager_button_inset,
		y = pager_top + 6,
		w = popup_geometry.pager_button_width,
		h = popup_geometry.pager_button_height,
	}
	local next_page_button_frame = {
		x = layout.w - popup_geometry.pager_button_width - popup_geometry.pager_button_inset,
		y = pager_top + 6,
		w = popup_geometry.pager_button_width,
		h = popup_geometry.pager_button_height,
	}

	local elements = {}

	if arrow_shadow ~= nil then
		table.insert(elements, arrow_shadow)
	end

	table.insert(elements, {
		id = "background",
		type = "rectangle",
		action = "fill",
		fillColor = theme.background,
		roundedRectRadii = {
			xRadius = popup_geometry.corner_radius,
			yRadius = popup_geometry.corner_radius,
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
			y = layout.surface_y,
			w = layout.w,
			h = layout.surface_h,
		},
	})
	if arrow_fill ~= nil then
		table.insert(elements, arrow_fill)
	end

	table.insert(elements, popup_border)

	table.insert(elements, {
		id = "title",
		type = "text",
		text = popup_title(),
		textSize = 13,
		textColor = theme.title,
		frame = {
			x = 18,
			y = layout.surface_y + 14,
			w = layout.w - 68,
			h = 18,
		},
	})
	table.insert(elements, {
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
	})
	table.insert(elements, {
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
	})
	table.insert(elements, {
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
	})
	table.insert(elements, {
		id = "divider",
		type = "rectangle",
		action = "fill",
		fillColor = theme.divider,
		frame = {
			x = 18,
			y = layout.surface_y + popup_divider_y,
			w = layout.w - 36,
			h = 1,
		},
	})
	table.insert(elements, {
		id = "body",
		type = "text",
		text = layout.page_text,
		textSize = 15,
		textLineBreak = "clip",
		textColor = theme.body,
		frame = {
			x = 18,
			y = layout.surface_y + popup_body_top,
			w = layout.body_width,
			h = layout.body_height,
		},
	})

	if layout.page_count > 1 then
		table.insert(elements, {
			id = "pager_divider",
			type = "rectangle",
			action = "fill",
			fillColor = theme.divider,
			frame = {
				x = 18,
				y = pager_top,
				w = layout.w - 36,
				h = 1,
			},
		})
		table.insert(elements, {
			id = "prev_page_button",
			type = "rectangle",
			action = "fill",
			fillColor = {
				white = 0,
				alpha = 0,
			},
			frame = prev_page_button_frame,
			trackMouseDown = true,
			trackMouseByBounds = true,
		})
		table.insert(elements, {
			id = "prev_page_label",
			type = "text",
			text = "上一页",
			textSize = 12,
			textColor = config_utils.popup_control_color(theme.copy_button, prev_page_enabled),
			frame = prev_page_button_frame,
			trackMouseDown = true,
			trackMouseByBounds = true,
		})
		table.insert(elements, {
			id = "page_indicator",
			type = "text",
			text = config_utils.popup_page_indicator_text(layout.page_index, layout.page_count),
			textSize = 12,
			textColor = theme.title,
			frame = {
				x = 84,
				y = pager_top + 7,
				w = layout.w - 168,
				h = 18,
			},
		})
		table.insert(elements, {
			id = "next_page_button",
			type = "rectangle",
			action = "fill",
			fillColor = {
				white = 0,
				alpha = 0,
			},
			frame = next_page_button_frame,
			trackMouseDown = true,
			trackMouseByBounds = true,
		})
		table.insert(elements, {
			id = "next_page_label",
			type = "text",
			text = "下一页",
			textSize = 12,
			textColor = config_utils.popup_control_color(theme.copy_button, next_page_enabled),
			frame = next_page_button_frame,
			trackMouseDown = true,
			trackMouseByBounds = true,
		})
	end

	canvas:appendElements(table.unpack(elements))

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
			elseif element_id == "prev_page_button" or element_id == "prev_page_label" then
				config_utils.change_popup_page(-1)
			elseif element_id == "next_page_button" or element_id == "next_page_label" then
				config_utils.change_popup_page(1)
			end
		end)
	end

	if type(canvas.show) == "function" then
		pcall(canvas.show, canvas, 0.08)
	end

	state.popup_hovered = false
	start_popup_click_watcher()
	start_popup_hover_watcher()

	if
		type(hs.eventtap) == "table"
		and type(hs.eventtap.new) == "function"
		and type(hs.eventtap.event) == "table"
		and type(hs.eventtap.event.types) == "table"
		and hs.eventtap.event.types.keyDown ~= nil
	then
		local ok, watcher = pcall(hs.eventtap.new, { hs.eventtap.event.types.keyDown }, function(event)
			if state.popup_canvas == nil or event == nil or type(event.getKeyCode) ~= "function" then
				return false
			end

			local key_code = event:getKeyCode()
			local key_name = nil

			if type(hs.keycodes) == "table" and type(hs.keycodes.map) == "table" then
				key_name = hs.keycodes.map[key_code]
			end

			if key_name ~= nil then
				key_name = string.lower(tostring(key_name))
			elseif tonumber(key_code) == 53 then
				key_name = "escape"
			end

			if key_name == "escape" or key_name == "esc" then
				destroy_popup()
				return true
			end

			if
				key_name == "left"
				or key_name == "up"
				or key_name == "pageup"
			then
				config_utils.change_popup_page(-1)
				return state.popup_page_count > 1
			end

			if
				key_name == "right"
				or key_name == "down"
				or key_name == "pagedown"
			then
				config_utils.change_popup_page(1)
				return state.popup_page_count > 1
			end

			return false
		end)

		if ok == true and watcher ~= nil then
			state.popup_key_watcher = watcher

			if type(watcher.start) == "function" then
				pcall(watcher.start, watcher)
			end
		end
	end

	refresh_popup_hover_state()
	schedule_popup_auto_hide()

	return true
end

local function show_translation_dialog(result, anchor_bounds)
	if config_utils.show_translation_popup(result, anchor_bounds) == true then
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

function config_utils.error_indicates_image_not_supported(message)
	local normalized = string.lower(trim(tostring(message or "")))

	if normalized == "" then
		return false
	end

	for _, phrase in ipairs({
		"不支持图片",
		"不支持图像",
		"不支持视觉",
		"not support image",
		"does not support image",
		"doesn't support image",
		"unsupported image",
		"unsupported vision",
		"text-only",
		"only supports text",
		"multimodal",
		"vision",
		"image_url",
	}) do
		if normalized:find(phrase, 1, true) ~= nil then
			if
				phrase == "multimodal"
				or phrase == "vision"
				or phrase == "image_url"
			then
				if
					normalized:find("unsupported", 1, true) ~= nil
					or normalized:find("not support", 1, true) ~= nil
					or normalized:find("does not support", 1, true) ~= nil
					or normalized:find("doesn't support", 1, true) ~= nil
				then
					return true
				end
			else
				return true
			end
		end
	end

	return false
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

	if provider() == "gemini" then
		local candidates = response.candidates

		if type(candidates) ~= "table" or type(candidates[1]) ~= "table" then
			return nil
		end

		local parts = candidates[1].content and candidates[1].content.parts

		if type(parts) ~= "table" then
			return nil
		end

		local texts = {}

		for _, part in ipairs(parts) do
			local text = type(part) == "table" and sanitize_selected_text(part.text) or sanitize_selected_text(part)

			if text ~= nil then
				table.insert(texts, text)
			end
		end

		if #texts > 0 then
			return table.concat(texts, "\n")
		end

		return nil
	end

	if provider() == "anthropic" then
		local content = response.content

		if type(content) ~= "table" then
			return nil
		end

		local texts = {}

		for _, block in ipairs(content) do
			local text = type(block) == "table" and sanitize_selected_text(block.text) or sanitize_selected_text(block)

			if text ~= nil then
				table.insert(texts, text)
			end
		end

		if #texts > 0 then
			return table.concat(texts, "\n")
		end

		return nil
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

function config_utils.build_request_headers(provider_name, key)
	local headers = {
		["Content-Type"] = "application/json",
	}

	if provider_name == "openai_compatible" and key ~= "" then
		headers["Authorization"] = "Bearer " .. key
	end

	if provider_name == "gemini" and key ~= "" then
		headers["x-goog-api-key"] = key
	end

	if provider_name == "anthropic" then
		headers["anthropic-version"] = "2023-06-01"

		if key ~= "" then
			headers["x-api-key"] = key
		end
	end

	return headers
end

local function show_request_error(message)
	finish_request()
	hs.alert.show(message)
end

local function apply_ollama_request_options(payload)
	if type(payload) ~= "table" or resolved_api_mode() ~= "ollama_native" then
		return payload
	end

	payload.stream = false

	if disable_thinking() == true then
		payload.think = false
	else
		payload.think = true
	end

	local keep_alive = model_keep_alive()

	if keep_alive ~= nil then
		payload.keep_alive = keep_alive
	end

	return payload
end

local function build_text_translation_payload(text)
	local provider_name = provider()
	local payload = {
		model = api_model(),
		messages = {
			{
				role = "system",
				content = text_system_prompt(text),
			},
			{
				role = "user",
				content = text,
			},
		},
	}

	if provider_name == "ollama" then
		return apply_ollama_request_options(payload)
	end

	if provider_name == "gemini" then
		return {
			systemInstruction = {
				parts = {
					{ text = text_system_prompt(text) },
				},
			},
			contents = {
				{
					role = "user",
					parts = {
						{ text = text },
					},
				},
			},
			generationConfig = {
				temperature = 0.2,
			},
		}
	end

	if provider_name == "anthropic" then
		return {
			model = api_model(),
			system = text_system_prompt(text),
			messages = {
				{
					role = "user",
					content = text,
				},
			},
			max_tokens = 1024,
			temperature = 0.2,
		}
	end

	payload.temperature = 0.2

	return payload
end

local function build_image_translation_payload(image_payload)
	local provider_name = provider()
	local prompt = image_user_prompt()
	local system_prompt = image_system_prompt()
	local payload = {
		model = api_model(),
		messages = {
			{
				role = "system",
				content = system_prompt,
			},
			{
				role = "user",
				content = {
					{
						type = "text",
						text = prompt,
					},
					{
						type = "image_url",
						image_url = {
							url = image_payload.data_url,
						},
					},
				},
			},
		},
	}

	if provider_name == "ollama" then
		payload.messages[2] = {
			role = "user",
			content = prompt,
			images = {
				image_payload.base64_data,
			},
		}

		return apply_ollama_request_options(payload)
	end

	if provider_name == "gemini" then
		return {
			systemInstruction = {
				parts = {
					{ text = system_prompt },
				},
			},
			contents = {
				{
					role = "user",
					parts = {
						{ text = prompt },
						{
							inline_data = {
								mime_type = image_payload.mime_type,
								data = image_payload.base64_data,
							},
						},
					},
				},
			},
			generationConfig = {
				temperature = 0.2,
			},
		}
	end

	if provider_name == "anthropic" then
		return {
			model = api_model(),
			system = system_prompt,
			messages = {
				{
					role = "user",
					content = {
						{
							type = "text",
							text = prompt,
						},
						{
							type = "image",
							source = {
								type = "base64",
								media_type = image_payload.mime_type,
								data = image_payload.base64_data,
							},
						},
					},
				},
			},
			max_tokens = 1024,
			temperature = 0.2,
		}
	end

	payload.temperature = 0.2

	return payload
end

local function build_model_warmup_payload()
	local payload = {
		model = api_model(),
	}

	payload = apply_ollama_request_options(payload)

	return payload
end

local function warmup_model()
	if enable_model_warmup() ~= true or resolved_api_mode() ~= "ollama_native" then
		return
	end

	if type(hs.http) ~= "table" or type(hs.http.asyncPost) ~= "function" then
		return
	end

	if type(hs.json) ~= "table" or type(hs.json.encode) ~= "function" then
		return
	end

	if state.request_inflight == true then
		return
	end

	local payload = build_model_warmup_payload()
	local encoded_ok, encoded_payload = pcall(hs.json.encode, payload)

	if encoded_ok ~= true or type(encoded_payload) ~= "string" or encoded_payload == "" then
		return
	end

	local key = api_key()
	local headers = config_utils.build_request_headers(provider(), key)

	pcall(function()
		hs.http.asyncPost(resolved_request_url(), encoded_payload, headers, function()
		end)
	end)
end

local function schedule_model_warmup()
	clear_model_warmup_timer()

	if enable_model_warmup() ~= true or resolved_api_mode() ~= "ollama_native" then
		return
	end

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		return
	end

	state.model_warmup_timer = hs.timer.doAfter(default_model_warmup_delay_seconds, function()
		state.model_warmup_timer = nil
		warmup_model()
	end)
end

local function request_translation(payload, anchor_bounds, request_kind)
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
		show_request_error("未找到翻译 API Key，请在模型服务中配置 API Key 或环境变量")
		return
	end

	if request_kind == "image" and config_utils.provider_supports_image_input() ~= true then
		show_request_error(default_image_translation_not_supported_message)
		return
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

	local headers = config_utils.build_request_headers(provider(), key)

	local ok, request_error = pcall(function()
		hs.http.asyncPost(resolved_request_url(), encoded_payload, headers, function(status, body, _)
			if current_request_id ~= state.request_id then
				return
			end

			finish_request()

			if tonumber(status) == nil or tonumber(status) < 200 or tonumber(status) >= 300 then
				local error_message = summarize_error_message(body)

				if request_kind == "image" and config_utils.error_indicates_image_not_supported(error_message) == true then
					hs.alert.show(default_image_translation_not_supported_message)
					return
				end

				hs.alert.show("翻译失败: " .. error_message)
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

		callback({
			copied_text = copied_text,
			error_message = copied_text ~= nil and nil or "当前选区不是可复制文本",
			clipboard_changed = true,
		})
		return
	end

	if remaining_attempts <= 0 then
		callback({
			copied_text = nil,
			error_message = "未检测到选中文本，请确认应用支持复制",
			clipboard_changed = false,
		})
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
	local config = current_config()
	local copy_shortcuts = {}
	local seen_shortcuts = {}
	local frontmost_bundle_id = nil
	local has_accessible_selection = current_selected_text_range() ~= nil

	if type(hs.application) == "table" and type(hs.application.frontmostApplication) == "function" then
		local app_ok, frontmost_app = pcall(hs.application.frontmostApplication)

		if app_ok == true and frontmost_app ~= nil and type(frontmost_app.bundleID) == "function" then
			local bundle_ok, bundle_id = pcall(frontmost_app.bundleID, frontmost_app)

			if bundle_ok == true and type(bundle_id) == "string" and bundle_id ~= "" then
				frontmost_bundle_id = bundle_id
			end
		end
	end

	if
		frontmost_bundle_id ~= nil
		and type(config.selection_auto_copy_by_bundle_id) == "table"
		and config.selection_auto_copy_by_bundle_id[frontmost_bundle_id] == true
		and has_accessible_selection == true
	then
		local clipboard_text = sanitize_selected_text(snapshot.text)

		if clipboard_text ~= nil then
			callback(clipboard_text, nil)
			return
		end
	end

	local function append_copy_shortcut(shortcut)
		if type(shortcut) ~= "table" then
			return
		end

		local modifiers = normalize_hotkey_modifiers(shortcut.modifiers or shortcut.prefix or {})
		local key = normalize_hotkey_key(shortcut.key)

		if modifiers == nil or key == nil then
			return
		end

		local signature = table.concat(modifiers, "+") .. ":" .. key

		if seen_shortcuts[signature] == true then
			return
		end

		seen_shortcuts[signature] = true
		table.insert(copy_shortcuts, {
			modifiers = modifiers,
			key = key,
		})
	end

	local function append_copy_shortcut_group(shortcut_group)
		if type(shortcut_group) ~= "table" then
			return
		end

		if shortcut_group.key ~= nil then
			append_copy_shortcut(shortcut_group)
			return
		end

		for _, shortcut in ipairs(shortcut_group) do
			append_copy_shortcut(shortcut)
		end
	end

	if frontmost_bundle_id ~= nil and type(config.copy_shortcuts_by_bundle_id) == "table" then
		append_copy_shortcut_group(config.copy_shortcuts_by_bundle_id[frontmost_bundle_id])
	end

	append_copy_shortcut({
		modifiers = { "cmd" },
		key = "c",
	})

	local function finish_capture(copied_text, error_message)
		restore_clipboard(snapshot)
		callback(copied_text, error_message)
	end

	local function try_copy_shortcut(index)
		local shortcut = copy_shortcuts[index]

		if shortcut == nil then
			finish_capture(nil, "未检测到选中文本，请确认应用支持复制")
			return
		end

		hs.eventtap.keyStroke(copy_list(shortcut.modifiers), shortcut.key, 0)
		wait_for_copied_selection(snapshot, clipboard_poll_attempts(), function(result)
			if result.copied_text ~= nil then
				finish_capture(result.copied_text, nil)
				return
			end

			if result.clipboard_changed ~= true and copy_shortcuts[index + 1] ~= nil then
				try_copy_shortcut(index + 1)
				return
			end

			finish_capture(nil, result.error_message)
		end)
	end

	suspend_clipboard_history(clipboard_max_wait_seconds() + 0.5)
	try_copy_shortcut(1)
end

function config_utils.request_text_translation(text, anchor_bounds)
	request_translation(build_text_translation_payload(text), anchor_bounds, "text")
end

function config_utils.request_image_translation(image_payload, anchor_bounds)
	request_translation(build_image_translation_payload(image_payload), anchor_bounds, "image")
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
		config_utils.request_text_translation(text, selection_bounds)
		return
	end

	capture_selection_from_clipboard(function(copied_text, error_message)
		if copied_text == nil then
			show_request_error(error_message or "未检测到选中文本")
			return
		end

		config_utils.request_text_translation(copied_text, selection_bounds)
	end)
end

local function translate_current_screenshot()
	if state.request_inflight == true then
		hs.alert.show("翻译请求进行中")
		return
	end

	state.request_inflight = true
	local anchor_bounds = current_mouse_bounds()
	local image_payload, error_message = config_utils.capture_screenshot_image_payload()

	if image_payload == nil then
		show_request_error(error_message or "截图失败")
		return
	end

	config_utils.request_image_translation(image_payload, anchor_bounds)
end

function config_utils.hotkey_kind_label(kind)
	if kind == "screenshot" then
		return "截图翻译"
	end

	return "划词翻译"
end

function config_utils.hotkey_override_field(kind, field)
	if kind == "screenshot" then
		return { "screenshot_hotkey", field }
	end

	return field
end

local function current_hotkey_components(kind)
	if kind == "screenshot" then
		local hotkey = config_utils.screenshot_hotkey_config()
		local modifiers = normalize_hotkey_modifiers(hotkey.prefix or {}) or {}
		local key = normalize_hotkey_key(hotkey.key)

		return modifiers, key
	end

	local config = current_config()
	local modifiers = normalize_hotkey_modifiers(config.prefix or {}) or {}
	local key = normalize_hotkey_key(config.key)

	return modifiers, key
end

local function display_hotkey_label(kind)
	local modifiers, key = current_hotkey_components(kind)

	if key == nil then
		return "未设置"
	end

	if type(format_hotkey) == "function" then
		return format_hotkey(modifiers, key)
	end

	return key
end

local function create_hotkey_binding(kind)
	local config = current_config()
	local raw_modifiers = config.prefix or {}
	local key = config.key
	local message = request_message()
	local handler = translate_current_selection

	if kind == "screenshot" then
		local screenshot_hotkey = config_utils.screenshot_hotkey_config()
		raw_modifiers = screenshot_hotkey.prefix or {}
		key = screenshot_hotkey.key
		message = config_utils.screenshot_request_message()
		handler = translate_current_screenshot
	end

	local modifiers, invalid_modifier = normalize_hotkey_modifiers(raw_modifiers)

	if modifiers == nil then
		log.e(
			string.format(
				"invalid %s hotkey modifier in config: %s",
				kind == "screenshot" and "screenshot translate" or "selected text translate",
				tostring(invalid_modifier)
			)
		)
		return false, nil, "快捷键修饰键无效"
	end

	key = normalize_hotkey_key(key)

	if key == nil then
		return true, nil, nil
	end

	local binding, binding_error = hotkey_helper.bind(copy_list(modifiers), key, message, function()
		handler()
	end, nil, nil, { logger = log })

	if binding == nil then
		return false, nil, tostring(binding_error or "快捷键绑定失败")
	end

	return true, binding, nil
end

local function hotkey_enabled()
	local config = current_config()
	return config.enabled ~= false
end

local function menubar_enabled()
	local config = current_config()

	if state.menubar_forced == true then
		return true
	end

	return config.show_menubar ~= false
end

function config_utils.format_duration_label(seconds)
	seconds = tonumber(seconds) or 0

	if math.abs(seconds) < 0.000001 then
		return "常驻"
	end

	if math.abs(seconds - math.floor(seconds)) < 0.000001 then
		return string.format("%d 秒", math.floor(seconds))
	end

	return string.format("%.1f 秒", seconds)
end

function config_utils.format_alpha_label(alpha)
	return string.format("%d%%", math.floor((tonumber(alpha) or 0) * 100 + 0.5))
end

function config_utils.translation_direction_label(direction)
	return menu_options.translation_direction_labels[direction or translation_direction()]
		or menu_options.translation_direction_labels.auto
end

function config_utils.popup_theme_label(theme_name)
	theme_name = theme_name or popup_theme_name()

	return menu_options.popup_theme_labels[theme_name] or theme_name
end

function config_utils.provider_label(provider_name)
	return menu_options.provider_labels[normalized_provider_name(provider_name)] or menu_options.provider_labels[default_model_service.provider]
end

function config_utils.api_key_source_label(provider_name)
	provider_name = normalized_provider_name(provider_name)

	if provider_name == "ollama" then
		return "不需要"
	end

	local config = config_utils.provider_config(provider_name)
	local configured = trim(tostring(config.api_key or ""))

	if configured ~= "" then
		if config_utils.path_exists(runtime_overrides, { "model_service", provider_name, "api_key" }) == true then
			return "菜单已保存"
		end

		return "配置文件"
	end

	local env_name = api_key_env_name(provider_name)

	if env_name ~= "" and trim(tostring(os.getenv(env_name) or "")) ~= "" then
		return "环境变量 " .. env_name
	end

	return "未配置"
end

function config_utils.menu_config_source_label()
	if table_is_empty(runtime_overrides) == true then
		return "配置: 文件"
	end

	return "配置: 文件+菜单"
end

function config_utils.tooltip_text()
	return string.format(
		"划词翻译\n状态: %s\n划词热键: %s\n截图热键: %s\n方向: %s\n非中文: %s\n中文: %s\n模型: %s\n模型服务: %s\n主题: %s | 透明度: %s | 停留: %s",
		hotkey_enabled() == true and "已启用" or "已停用",
		display_hotkey_label("selection"),
		display_hotkey_label("screenshot"),
		config_utils.translation_direction_label(),
		target_language(),
		chinese_target_language(),
		api_model(),
		config_utils.provider_label(),
		config_utils.popup_theme_label(),
		config_utils.format_alpha_label(resolved_popup_background_alpha({ alpha = popup_background_fill_color().alpha })),
		config_utils.format_duration_label(popup_duration_seconds())
	)
end

function config_utils.prompt_number(message, informative_text, default_value, minimum, maximum, options)
	options = options or {}

	if type(prompt_text) ~= "function" then
		hs.alert.show("当前环境不支持输入配置")
		return nil
	end

	local value = prompt_text(message, informative_text, tostring(default_value or ""))

	if value == nil then
		return nil
	end

	local number = tonumber(trim(value))

	if number == nil then
		hs.alert.show("请输入有效数字")
		return nil
	end

	if options.integer == true then
		number = math.floor(number)
	end

	if minimum ~= nil then
		number = math.max(minimum, number)
	end

	if maximum ~= nil then
		number = math.min(maximum, number)
	end

	return number
end

function config_utils.format_hotkey_for_prompt(modifiers, key)
	local modifier_names = {}

	for _, modifier in ipairs(modifiers or {}) do
		table.insert(modifier_names, modifier_prompt_names[modifier] or modifier)
	end

	return table.concat(modifier_names, "+"), key or ""
end

local refresh_menubar

function config_utils.destroy_menubar()
	if state.menubar == nil then
		return
	end

	state.menubar:delete()
	state.menubar = nil
end

function config_utils.replace_runtime_overrides(snapshot)
	runtime_overrides = sanitize_runtime_overrides(snapshot)
	persist_runtime_overrides()
end

local function rebind_hotkeys(_, options)
	options = options or {}

	if state.hotkey ~= nil then
		state.hotkey:delete()
		state.hotkey = nil
	end

	if state.screenshot_hotkey ~= nil then
		state.screenshot_hotkey:delete()
		state.screenshot_hotkey = nil
	end

	state.hotkey_error = nil
	state.screenshot_hotkey_error = nil

	if hotkey_enabled() ~= true then
		if options.refresh_menubar ~= false and refresh_menubar ~= nil then
			refresh_menubar()
		end

		return true
	end

	local hotkey_ok, binding, error_message = create_hotkey_binding("selection")
	state.hotkey = binding

	if hotkey_ok ~= true then
		state.hotkey = nil
		state.hotkey_error = error_message or "快捷键绑定失败"
	end

	local screenshot_ok, screenshot_binding, screenshot_error_message = create_hotkey_binding("screenshot")
	state.screenshot_hotkey = screenshot_binding

	if screenshot_ok ~= true then
		state.screenshot_hotkey = nil
		state.screenshot_hotkey_error = screenshot_error_message or "快捷键绑定失败"
	end

	local ok = hotkey_ok == true and screenshot_ok == true

	if ok ~= true then
		state.menubar_forced = true

		if options.show_alert ~= false then
			hs.alert.show("翻译快捷键绑定失败，已保留菜单栏入口")
		end
	else
		state.hotkey_error = nil
		state.screenshot_hotkey_error = nil

		if current_config().show_menubar ~= false then
			state.menubar_forced = false
		end
	end

	if options.refresh_menubar ~= false and refresh_menubar ~= nil then
		refresh_menubar()
	end

	return ok
end

local function clear_runtime_override(field)
	config_utils.clear_path_value(runtime_overrides, field)
	persist_runtime_overrides()
end

local function set_enabled(enabled, reason)
	set_runtime_override("enabled", enabled == true)

	if enabled ~= true then
		finish_request()
		destroy_popup()
	end

	rebind_hotkeys(reason or "menu update enabled", { show_alert = enabled ~= true })
	hs.alert.show(enabled == true and "划词翻译已开启" or "划词翻译已关闭")
end

local function set_hotkey_configuration(kind, modifiers, key, reason)
	local snapshot = copy_table(runtime_overrides)
	local hotkey_label = config_utils.hotkey_kind_label(kind)

	set_runtime_override(config_utils.hotkey_override_field(kind, "prefix"), copy_list(modifiers or {}))
	set_runtime_override(config_utils.hotkey_override_field(kind, "key"), key == nil and "disabled" or key)

	local ok = rebind_hotkeys(reason or "menu update hotkey", { show_alert = false })

	if ok ~= true and hotkey_enabled() == true then
		config_utils.replace_runtime_overrides(snapshot)
		rebind_hotkeys("restore previous selection translate hotkey", { show_alert = false })
		hs.alert.show(hotkey_label .. "快捷键设置失败")
		return false
	end

	hs.alert.show(key == nil and ("已禁用" .. hotkey_label .. "快捷键") or (hotkey_label .. "快捷键已更新: " .. display_hotkey_label(kind)))
	return true
end

local function restore_default_hotkey(kind)
	local snapshot = copy_table(runtime_overrides)
	local hotkey_label = config_utils.hotkey_kind_label(kind)

	clear_runtime_override(config_utils.hotkey_override_field(kind, "prefix"))
	clear_runtime_override(config_utils.hotkey_override_field(kind, "key"))
	clear_runtime_override(config_utils.hotkey_override_field(kind, "message"))

	local ok = rebind_hotkeys("restore default selection translate hotkey", { show_alert = false })

	if ok ~= true and hotkey_enabled() == true then
		config_utils.replace_runtime_overrides(snapshot)
		rebind_hotkeys("restore previous selection translate hotkey", { show_alert = false })
		hs.alert.show("恢复默认快捷键失败")
		return false
	end

	hs.alert.show("已恢复" .. hotkey_label .. "默认快捷键: " .. display_hotkey_label(kind))
	return true
end

local function prompt_hotkey_configuration(kind)
	local modifiers, key = current_hotkey_components(kind)
	local current_modifiers, current_key = config_utils.format_hotkey_for_prompt(modifiers, key)
	local hotkey_label = config_utils.hotkey_kind_label(kind)
	local modifier_text = prompt_text(
		"设置" .. hotkey_label .. "快捷键",
		"请输入修饰键，多个值用 + 分隔。\n可用: ctrl option command shift fn\n留空表示无修饰键。",
		current_modifiers
	)

	if modifier_text == nil then
		return
	end

	local key_text = prompt_text(
		"设置" .. hotkey_label .. "快捷键",
		"请输入主键，例如 r、t、space、return、f18。",
		current_key
	)

	if key_text == nil then
		return
	end

	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(modifier_text)
	local normalized_key = normalize_hotkey_key(key_text)

	if normalized_modifiers == nil then
		hs.alert.show("无效修饰键: " .. tostring(invalid_modifier))
		return
	end

	if normalized_key == nil then
		hs.alert.show("主键不能为空")
		return
	end

	set_hotkey_configuration(kind, normalized_modifiers, normalized_key, "menu prompt hotkey")
end

local function set_translation_direction(direction)
	set_runtime_override("translation_direction", direction)
	refresh_menubar()
	hs.alert.show("翻译方向已切换为" .. config_utils.translation_direction_label(direction))
end

local function set_language_field(field, value, success_message)
	local language = trim(tostring(value or ""))

	if language == "" then
		hs.alert.show("目标语言不能为空")
		return
	end

	set_runtime_override(field, language)
	refresh_menubar()
	hs.alert.show(success_message .. language)
end

local function prompt_language_field(field, title, informative_text, success_message)
	local value = prompt_text(title, informative_text, current_config()[field] or "")

	if value == nil then
		return
	end

	set_language_field(field, value, success_message)
end

local function set_popup_theme(theme_name)
	set_runtime_override("popup_theme", theme_name)
	refresh_menubar()
	hs.alert.show("悬浮窗主题已切换为" .. config_utils.popup_theme_label(theme_name))
end

local function set_popup_alpha(alpha)
	alpha = normalize_unit_interval(alpha, default_popup_background_alpha)
	set_runtime_override("popup_background_alpha", alpha)
	refresh_menubar()
	hs.alert.show("悬浮窗透明度已更新为 " .. config_utils.format_alpha_label(alpha))
end

local function set_popup_duration(seconds)
	seconds = normalize_number(seconds, default_popup_duration_seconds, 0, 60)
	set_runtime_override("popup_duration_seconds", seconds)
	refresh_menubar()
	hs.alert.show("悬浮窗停留时间已更新为 " .. config_utils.format_duration_label(seconds))
end

local function set_provider(provider_name)
	set_runtime_override({ "model_service", "provider" }, provider_name)
	clear_model_warmup_timer()

	if state.started == true then
		schedule_model_warmup()
	end

	refresh_menubar()
	hs.alert.show("模型服务已切换为" .. config_utils.provider_label(provider_name))
end

local function set_request_timeout(seconds)
	seconds = normalize_number(seconds, default_request_timeout_seconds, 3, 120)
	set_runtime_override({ "model_service", "request_timeout_seconds" }, seconds)
	refresh_menubar()
	hs.alert.show("请求超时已更新为 " .. config_utils.format_duration_label(seconds))
end

local function maybe_refresh_provider_warmup(provider_name)
	if provider_name ~= provider() then
		return
	end

	clear_model_warmup_timer()

	if state.started == true then
		schedule_model_warmup()
	end
end

local function prompt_api_url_configuration(provider_name)
	provider_name = normalized_provider_name(provider_name)

	local provider_label_text = config_utils.provider_label(provider_name)
	local value = prompt_text(
		"设置模型服务地址",
		"请输入当前模型服务的接口地址。\n当前提供方: " .. provider_label_text,
		api_url(provider_name)
	)

	if value == nil then
		return
	end

	local url = trim(value)

	if url == "" then
		hs.alert.show("接口地址不能为空")
		return
	end

	set_runtime_override({ "model_service", provider_name, "api_url" }, url)
	maybe_refresh_provider_warmup(provider_name)
	refresh_menubar()
	hs.alert.show(provider_label_text .. " 接口地址已更新")
end

local function prompt_model_configuration(provider_name)
	provider_name = normalized_provider_name(provider_name)

	local value = prompt_text(
		"设置翻译模型",
		"请输入当前模型服务要调用的模型名称。\n当前提供方: " .. config_utils.provider_label(provider_name),
		api_model(provider_name)
	)

	if value == nil then
		return
	end

	local model = trim(value)

	if model == "" then
		hs.alert.show("模型名称不能为空")
		return
	end

	set_runtime_override({ "model_service", provider_name, "model" }, model)
	maybe_refresh_provider_warmup(provider_name)
	refresh_menubar()
	hs.alert.show(config_utils.provider_label(provider_name) .. " 模型已更新为 " .. model)
end

local function prompt_api_key_configuration(provider_name)
	provider_name = normalized_provider_name(provider_name)

	if provider_name == "ollama" then
		hs.alert.show("当前模型服务不需要 API Key")
		return
	end

	local value = prompt_text(
		"设置 " .. config_utils.provider_label(provider_name) .. " API Key",
		"将保存到 hs.settings，重启 Hammerspoon 或电脑后仍可继续使用。\n留空表示清除菜单中保存的 API Key，并回退到配置文件或环境变量。",
		tostring(config_utils.get_path_value(current_config(), { "model_service", provider_name, "api_key" }) or "")
	)

	if value == nil then
		return
	end

	local key = trim(value)

	if key == "" then
		clear_runtime_override({ "model_service", provider_name, "api_key" })
		refresh_menubar()
		hs.alert.show("已清除 " .. config_utils.provider_label(provider_name) .. " 的菜单 API Key")
		return
	end

	set_runtime_override({ "model_service", provider_name, "api_key" }, key)
	refresh_menubar()
	hs.alert.show(config_utils.provider_label(provider_name) .. " API Key 已保存")
end

local function restore_default_field(field, success_message)
	local normalized_field = config_utils.normalize_path(field)
	clear_runtime_override(field)

	if normalized_field[1] == "model_service" then
		local affected_provider = normalized_field[2]

		if affected_provider == nil or affected_provider == "provider" then
			maybe_refresh_provider_warmup(provider())
		elseif menu_options.provider_labels[affected_provider] ~= nil then
			maybe_refresh_provider_warmup(affected_provider)
		end
	end

	refresh_menubar()

	if success_message ~= nil then
		hs.alert.show(success_message)
	end
end

local function restore_persisted_menu_configuration()
	config_utils.replace_runtime_overrides({})
	rebind_hotkeys("restore selection translate defaults", { show_alert = false })
	refresh_menubar()
end

local function confirm_restore_defaults()
	if table_is_empty(runtime_overrides) == true then
		return false
	end

	local button = "恢复默认"

	if type(hs.dialog) == "table" and type(hs.dialog.blockAlert) == "function" then
		button = hs.dialog.blockAlert(
			"恢复默认",
			"这会清除当前通过菜单栏保存的划词翻译配置，并恢复为 keybindings_config.lua 中定义的默认值。是否继续？",
			"恢复默认",
			"取消"
		)
	end

	if button ~= "恢复默认" then
		return false
	end

	restore_persisted_menu_configuration()
	hs.alert.show("已恢复默认配置")

	return true
end

local function build_translation_direction_menu()
	return {
		{
			title = "自动双向",
			checked = translation_direction() == "auto",
			fn = function()
				set_translation_direction("auto")
			end,
		},
		{
			title = "固定翻译到非中文目标语言",
			checked = translation_direction() == "to_target",
			fn = function()
				set_translation_direction("to_target")
			end,
		},
		{
			title = "恢复文件配置",
			disabled = runtime_overrides.translation_direction == nil,
			fn = function()
				restore_default_field("translation_direction", "已恢复文件中的翻译方向配置")
			end,
		},
	}
end

local function build_language_menu(field, current_value, title, informative_text, success_message, presets)
	local menu = {
		{ title = "当前: " .. tostring(current_value), disabled = true },
	}

	for _, language in ipairs(presets or menu_options.target_language_presets) do
		table.insert(menu, {
			title = language,
			checked = current_value == language,
			fn = function()
				set_language_field(field, language, success_message)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义...",
		fn = function()
			prompt_language_field(field, title, informative_text, success_message)
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件配置",
		disabled = runtime_overrides[field] == nil,
		fn = function()
			restore_default_field(field, "已恢复文件中的语言配置")
		end,
	})

	return menu
end

local function build_popup_theme_menu()
	local menu = {
		{ title = "当前: " .. config_utils.popup_theme_label(), disabled = true },
	}

	for _, theme_name in ipairs(menu_options.popup_theme_order) do
		table.insert(menu, {
			title = config_utils.popup_theme_label(theme_name),
			checked = popup_theme_name() == theme_name,
			fn = function()
				set_popup_theme(theme_name)
			end,
		})
	end

	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件配置",
		disabled = runtime_overrides.popup_theme == nil,
		fn = function()
			restore_default_field("popup_theme", "已恢复文件中的主题配置")
		end,
	})

	return menu
end

local function build_popup_alpha_menu()
	local menu = {
		{ title = "当前: " .. config_utils.format_alpha_label(popup_background_fill_color().alpha), disabled = true },
	}

	for _, alpha in ipairs(menu_options.popup_alpha_presets) do
		table.insert(menu, {
			title = config_utils.format_alpha_label(alpha),
			checked = math.abs(popup_background_fill_color().alpha - alpha) < 0.001,
			fn = function()
				set_popup_alpha(alpha)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义透明度...",
		fn = function()
			local percent = config_utils.prompt_number(
				"设置悬浮窗透明度",
				"请输入 0 到 100 之间的透明度百分比。",
				math.floor((popup_background_fill_color().alpha or default_popup_background_alpha) * 100 + 0.5),
				0,
				100,
				{ integer = true }
			)

			if percent == nil then
				return
			end

			set_popup_alpha(percent / 100)
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件配置",
		disabled = runtime_overrides.popup_background_alpha == nil,
		fn = function()
			restore_default_field("popup_background_alpha", "已恢复文件中的透明度配置")
		end,
	})

	return menu
end

local function build_popup_duration_menu()
	local current_seconds = popup_duration_seconds()
	local menu = {
		{ title = "当前: " .. config_utils.format_duration_label(current_seconds), disabled = true },
	}

	for _, seconds in ipairs(menu_options.popup_duration_presets) do
		table.insert(menu, {
			title = config_utils.format_duration_label(seconds),
			checked = math.abs(current_seconds - seconds) < 0.001,
			fn = function()
				set_popup_duration(seconds)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义停留时间...",
		fn = function()
			local seconds = config_utils.prompt_number(
				"设置悬浮窗停留时间",
				"请输入悬浮窗停留秒数，输入 0 表示不自动关闭。",
				current_seconds,
				0,
				60
			)

			if seconds == nil then
				return
			end

			set_popup_duration(seconds)
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件配置",
		disabled = runtime_overrides.popup_duration_seconds == nil,
		fn = function()
			restore_default_field("popup_duration_seconds", "已恢复文件中的停留时间配置")
		end,
	})

	return menu
end

local function build_request_timeout_menu()
	local current_seconds = request_timeout_seconds()
	local menu = {
		{ title = "当前: " .. config_utils.format_duration_label(current_seconds), disabled = true },
	}

	for _, seconds in ipairs(menu_options.request_timeout_presets) do
		table.insert(menu, {
			title = config_utils.format_duration_label(seconds),
			checked = math.abs(current_seconds - seconds) < 0.001,
			fn = function()
				set_request_timeout(seconds)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义超时...",
		fn = function()
			local seconds = config_utils.prompt_number(
				"设置请求超时",
				"请输入请求超时秒数，范围 3 到 120。",
				current_seconds,
				3,
				120
			)

			if seconds == nil then
				return
			end

			set_request_timeout(seconds)
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件配置",
		disabled = config_utils.path_exists(runtime_overrides, { "model_service", "request_timeout_seconds" }) ~= true,
		fn = function()
			restore_default_field({ "model_service", "request_timeout_seconds" }, "已恢复文件中的超时配置")
		end,
	})

	return menu
end

local function build_provider_configuration_menu(provider_name)
	local active_provider = provider() == provider_name
	local provider_title = config_utils.provider_label(provider_name)
	local menu = {
		{ title = active_provider and "状态: 当前使用中" or "状态: 可切换", disabled = true },
		{ title = "模型: " .. api_model(provider_name), disabled = true },
		{ title = "地址: " .. api_url(provider_name), disabled = true },
		{ title = "API Key: " .. config_utils.api_key_source_label(provider_name), disabled = true },
		{
			title = "图片输入: " .. (config_utils.provider_supports_image_input(provider_name) == true and "已启用" or "已禁用"),
			disabled = true,
		},
		{ title = "-" },
		{
			title = active_provider and "当前提供方" or "设为当前提供方",
			disabled = active_provider,
			fn = function()
				set_provider(provider_name)
			end,
		},
		{
			title = "模型名称...",
			fn = function()
				prompt_model_configuration(provider_name)
			end,
		},
		{
			title = "恢复文件中的模型",
			disabled = config_utils.path_exists(runtime_overrides, { "model_service", provider_name, "model" }) ~= true,
			fn = function()
				restore_default_field(
					{ "model_service", provider_name, "model" },
					"已恢复文件中的 " .. provider_title .. " 模型配置"
				)
			end,
		},
		{
			title = "接口地址...",
			fn = function()
				prompt_api_url_configuration(provider_name)
			end,
		},
		{
			title = "恢复文件中的地址",
			disabled = config_utils.path_exists(runtime_overrides, { "model_service", provider_name, "api_url" }) ~= true,
			fn = function()
				restore_default_field(
					{ "model_service", provider_name, "api_url" },
					"已恢复文件中的 " .. provider_title .. " 接口地址配置"
				)
			end,
		},
	}

	if provider_name ~= "ollama" then
		table.insert(menu, {
			title = "设置 API Key...",
			fn = function()
				prompt_api_key_configuration(provider_name)
			end,
		})
		table.insert(menu, {
			title = "清除菜单中保存的 API Key",
			disabled = config_utils.path_exists(runtime_overrides, { "model_service", provider_name, "api_key" }) ~= true,
			fn = function()
				clear_runtime_override({ "model_service", provider_name, "api_key" })
				refresh_menubar()
				hs.alert.show("已清除 " .. provider_title .. " 的菜单 API Key")
			end,
		})
	end

	return menu
end

local function build_api_settings_menu()
	local menu = {
		{ title = "当前提供方: " .. config_utils.provider_label(), disabled = true },
		{ title = "当前模型: " .. api_model(), disabled = true },
		{
			title = "请求超时",
			menu = build_request_timeout_menu(),
		},
		{ title = "-" },
	}

	for _, provider_name in ipairs(menu_options.provider_order) do
		table.insert(menu, {
			title = config_utils.provider_label(provider_name),
			menu = build_provider_configuration_menu(provider_name),
		})
	end

	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复文件中的当前提供方",
		disabled = config_utils.path_exists(runtime_overrides, { "model_service", "provider" }) ~= true,
		fn = function()
			restore_default_field({ "model_service", "provider" }, "已恢复文件中的模型服务配置")
		end,
	})

	return menu
end

local function build_hotkey_menu(kind)
	local current_label = display_hotkey_label(kind)
	local has_runtime_override = kind == "screenshot"
			and (config_utils.path_exists(runtime_overrides, { "screenshot_hotkey" }) == true)
		or (runtime_overrides.prefix ~= nil or runtime_overrides.key ~= nil)

	return {
		{ title = "当前: " .. current_label, disabled = true },
		{
			title = "设置快捷键...",
			fn = function()
				prompt_hotkey_configuration(kind)
			end,
		},
		{
			title = "恢复默认快捷键",
			disabled = has_runtime_override ~= true,
			fn = function()
				restore_default_hotkey(kind)
			end,
		},
	}
end

local function build_menu()
	return {
		{ title = "划词翻译", disabled = true },
		{
			title = string.format(
				"状态: %s | 划词: %s | 截图: %s",
				hotkey_enabled() == true and "已启用" or "已停用",
				display_hotkey_label("selection"),
				display_hotkey_label("screenshot")
			),
			disabled = true,
		},
		{
			title = string.format(
				"方向: %s | 非中文: %s | 中文: %s",
				config_utils.translation_direction_label(),
				target_language(),
				chinese_target_language()
			),
			disabled = true,
		},
		{
			title = string.format(
				"主题: %s | 透明度: %s | 停留: %s",
				config_utils.popup_theme_label(),
				config_utils.format_alpha_label(popup_background_fill_color().alpha),
				config_utils.format_duration_label(popup_duration_seconds())
			),
			disabled = true,
		},
		{
			title = string.format(
				"模型: %s | 服务: %s",
				api_model(),
				config_utils.provider_label()
			),
			disabled = true,
		},
		{ title = config_utils.menu_config_source_label(), disabled = true },
		{ title = "-" },
		{
			title = "翻译当前选区",
			fn = translate_current_selection,
		},
		{
			title = "翻译截图",
			fn = translate_current_screenshot,
		},
		{
			title = "启用划词翻译",
			checked = hotkey_enabled(),
			fn = function()
				set_enabled(not hotkey_enabled(), "menu toggle enabled")
			end,
		},
		{
			title = "快捷键",
			menu = build_hotkey_menu("selection"),
		},
		{
			title = "截图快捷键",
			menu = build_hotkey_menu("screenshot"),
		},
		{
			title = "翻译方向",
			menu = build_translation_direction_menu(),
		},
		{
			title = "非中文目标语言",
			menu = build_language_menu(
				"target_language",
				target_language(),
				"设置非中文目标语言",
				"请输入非中文文本的目标语言名称，例如 简体中文、英文、日文。",
				"非中文目标语言已更新为 ",
				menu_options.target_language_presets
			),
		},
		{
			title = "中文目标语言",
			menu = build_language_menu(
				"chinese_target_language",
				chinese_target_language(),
				"设置中文目标语言",
				"请输入中文文本的目标语言名称，例如 英文、繁體中文、日文。",
				"中文目标语言已更新为 ",
				menu_options.chinese_target_language_presets
			),
		},
		{
			title = "悬浮窗主题",
			menu = build_popup_theme_menu(),
		},
		{
			title = "悬浮窗透明度",
			menu = build_popup_alpha_menu(),
		},
		{
			title = "悬浮窗停留时间",
			menu = build_popup_duration_menu(),
		},
		{
			title = "模型服务",
			menu = build_api_settings_menu(),
		},
		{ title = "-" },
		{
			title = "恢复默认",
			disabled = table_is_empty(runtime_overrides) == true,
			fn = confirm_restore_defaults,
		},
	}
end

refresh_menubar = function()
	if type(hs.menubar) ~= "table" or type(hs.menubar.new) ~= "function" then
		return
	end

	if menubar_enabled() ~= true then
		config_utils.destroy_menubar()
		return
	end

	if state.menubar == nil then
		state.menubar = hs.menubar.new()

		if state.menubar == nil then
			log.e("failed to create selected text translate menubar item")
			return
		end
	end

	if type(state.menubar.autosaveName) == "function" then
		pcall(state.menubar.autosaveName, state.menubar, menubar_autosave_name)
	end

	if type(state.menubar.setIcon) == "function" then
		state.menubar:setIcon(nil)
	end

	if type(state.menubar.setTitle) == "function" then
		state.menubar:setTitle(menubar_title_fallback)
	end

	if type(state.menubar.setTooltip) == "function" then
		state.menubar:setTooltip(config_utils.tooltip_text())
	end

	if type(state.menubar.setMenu) == "function" then
		state.menubar:setMenu(build_menu)
	end
end

function _M.start()
	if state.started == true then
		return state.start_ok
	end

	state.started = true
	state.start_ok = true
	refresh_menubar()

	local ok = rebind_hotkeys("startup selected text translate", { show_alert = false })

	if ok ~= true and hotkey_enabled() == true then
		hs.alert.show("翻译快捷键绑定失败，已临时显示菜单栏图标")
	end

	schedule_model_warmup()

	return true
end

function _M.stop()
	finish_request()
	clear_model_warmup_timer()
	destroy_popup()

	if state.hotkey ~= nil then
		state.hotkey:delete()
		state.hotkey = nil
	end

	if state.screenshot_hotkey ~= nil then
		state.screenshot_hotkey:delete()
		state.screenshot_hotkey = nil
	end

	config_utils.destroy_menubar()
	state.menubar_forced = false
	state.hotkey_error = nil
	state.screenshot_hotkey_error = nil

	state.started = false
	state.start_ok = true

	return true
end

_M.translate_current_selection = translate_current_selection
_M.translate_current_screenshot = translate_current_screenshot
_M.refresh_menubar = function()
	refresh_menubar()
end
_M.restore_defaults = function()
	return confirm_restore_defaults()
end
_M.get_state = function()
	local modifiers, key = current_hotkey_components("selection")
	local screenshot_modifiers, screenshot_key = current_hotkey_components("screenshot")

	return {
		started = state.started,
		enabled = hotkey_enabled(),
		hotkey_modifiers = copy_list(modifiers),
		hotkey_key = key,
		hotkey_label = display_hotkey_label("selection"),
		hotkey_error = state.hotkey_error,
		screenshot_hotkey_modifiers = copy_list(screenshot_modifiers),
		screenshot_hotkey_key = screenshot_key,
		screenshot_hotkey_label = display_hotkey_label("screenshot"),
		screenshot_hotkey_error = state.screenshot_hotkey_error,
		menubar_exists = state.menubar ~= nil,
		translation_direction = translation_direction(),
		target_language = target_language(),
		chinese_target_language = chinese_target_language(),
		popup_theme = popup_theme_name(),
		popup_background_alpha = popup_background_fill_color().alpha,
		popup_duration_seconds = popup_duration_seconds(),
		popup_page_index = state.popup_page_index,
		popup_page_count = state.popup_page_count,
		provider = provider(),
		model_service = copy_table(config_utils.model_service_config()),
		api_mode = resolved_api_mode(),
		resolved_api_mode = resolved_api_mode(),
		api_url = api_url(),
		model = api_model(),
		enable_model_warmup = enable_model_warmup(),
		model_keep_alive = model_keep_alive(),
		supports_image_input = config_utils.provider_supports_image_input(),
		api_key_source = config_utils.api_key_source_label(),
		runtime_overrides = copy_table(runtime_overrides),
	}
end

return _M
