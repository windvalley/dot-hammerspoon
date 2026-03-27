local _M = {}

_M.name = "clipboard_center"
_M.description = "剪贴板历史"

-------------------------------------------------------------------------------
-- 模块架构说明
--
-- 本模块实现了一个支持文本和图片的剪贴板历史管理器，
-- 包含 chooser 面板、预览窗口和菜单栏图标三个 UI 组件。
--
-- [配置与状态] L1-80
--   从 keybindings_config.clipboard 读取配置
--   state 表管理运行时状态（watcher/chooser/menubar/preview 等）
--   支持运行时动态调整菜单显示条数
--
-- [工具函数] L80-170
--   normalize_number / normalize_menu_history_size — 配置值校验
--   next_history_id — 生成唯一项目 ID
--   normalize_hotkey_key — 快捷键标准化
--
-- [布局计算] L170-330
--   resolve_target_screen_frame — 获取当前屏幕尺寸
--   chooser_layout — 计算 chooser + preview 面板的位置和尺寸
--   支持 preview 面板与 chooser 自动对齐居中
--
-- [剪贴板操作] L330-650
--   文本去重（duplicate_suppression_seconds 秒内相同内容不重复记录）
--   图片缓存管理（保存到磁盘，删除时清理缓存文件）
--   历史记录持久化到 hs.settings
--   sanitize_text / capture_clipboard — 输入清洗与捕获
--
-- [预览面板] L650-900
--   hs.canvas 实现的富文本/图片预览窗口
--   支持深色/浅色主题自动适配
--   preview_signature 防止无变化时重复渲染
--   poll timer 轮询 chooser 选中项变化
--
-- [Chooser 面板] L900-1200
--   hs.chooser 实现的搜索/选择界面
--   支持行内图片缩略图
--   选中后自动粘贴到前台应用
--
-- [菜单栏] L1200-1700
--   矢量图标绘制（剪贴板图标）
--   右键菜单：最近记录（可配置条数）、清空历史、快捷键设置
--   支持运行时修改快捷键并持久化
--
-- [公共 API 与生命周期] L1700-2010
--   _M.start() / _M.stop() 模块生命周期
--   hs.pasteboard.watcher 监听剪贴板变化
--   启动时从 hs.settings 恢复历史和配置
--
-- 关键设计决策：
-- 1. 图片以文件路径形式存储在 history 中，实际文件缓存在 Library/Caches
-- 2. chooser 和 preview 面板位置根据当前屏幕动态计算
-- 3. 支持运行时通过菜单栏修改快捷键，修改后持久化到 hs.settings
-------------------------------------------------------------------------------

local clipboard = require("keybindings_config").clipboard or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local utf8len = utils_lib.utf8len
local utf8sub = utils_lib.utf8sub
local copy_list = utils_lib.copy_list
local file_exists = utils_lib.file_exists
local ensure_directory = utils_lib.ensure_directory
local expand_home_path = utils_lib.expand_home_path
local prompt_text = utils_lib.prompt_text
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers
local format_hotkey = hotkey_helper.format_hotkey
local modifier_prompt_names = hotkey_helper.modifier_prompt_names

local log = hs.logger.new("clipboard")

local history_settings_key = "clipboard_center.history"
local menu_history_size_settings_key = "clipboard_center.menu_history_size"
local hotkey_modifiers_settings_key = "clipboard_center.hotkey.modifiers"
local hotkey_key_settings_key = "clipboard_center.hotkey.key"
local default_history_size = math.max(10, math.floor(tonumber(clipboard.history_size) or 80))
local default_menu_history_size = math.max(1, math.floor(tonumber(clipboard.menu_history_size) or 12))
local default_max_item_length = math.max(200, math.floor(tonumber(clipboard.max_item_length) or 30000))
local default_capture_images = clipboard.capture_images ~= false
local chooser_inline_thumbnail_size = 28
local default_menu_thumbnail_size = math.max(14, math.floor(tonumber(clipboard.image_menu_thumbnail_size) or 18))
local preview_enabled_config = clipboard.preview_enabled
local preview_width_config = clipboard.preview_width
local preview_height_config = clipboard.preview_height
local preview_poll_interval_config = clipboard.preview_poll_interval
local preview_body_max_chars = math.max(1000, math.floor(tonumber(clipboard.preview_body_max_chars) or 6000))

if preview_enabled_config == nil then
	preview_enabled_config = clipboard.image_preview_enabled
end

if preview_width_config == nil then
	preview_width_config = clipboard.image_preview_width
end

if preview_height_config == nil then
	preview_height_config = clipboard.image_preview_height
end

if preview_poll_interval_config == nil then
	preview_poll_interval_config = clipboard.image_preview_poll_interval
end

local default_preview_enabled = preview_enabled_config ~= false
local default_preview_width = math.max(260, math.floor(tonumber(preview_width_config) or 420))
local default_preview_height = math.max(220, math.floor(tonumber(preview_height_config) or 320))
local default_preview_poll_interval = math.max(0.05, tonumber(preview_poll_interval_config) or 0.08)
local default_preview_gap = 24
local default_preview_margin = 28
local history_preview_length = 72
local menu_preview_length = 40
local tooltip_preview_length = 220
local duplicate_suppression_seconds = 3
local default_hotkey_modifiers
local default_hotkey_key
local image_cache_dir = nil
local history_id_counter = 0
local menubar_icon_size = 18
local menu_history_shortcut_limit = 9
local chooser_row_height = 40
local chooser_row_spacing = 2
local chooser_window_chrome_height = 94
local started = false
local history_loaded = false
local startup_synchronized = false

local state = {
	show_menubar = clipboard.show_menubar ~= false,
	history = {},
	menu_history_size = default_menu_history_size,
	watcher = nil,
	chooser = nil,
	menubar = nil,
	hotkey = nil,
	hotkey_modifiers = {},
	hotkey_key = nil,
	preview_canvas = nil,
	preview_timer = nil,
	preview_signature = nil,
	chooser_screen_frame = nil,
	suppressed_signature = nil,
	suppressed_at = nil,
	capture_suspended_until = nil,
	menubar_icon = nil,
}

local function current_absolute_time()
	if type(hs.timer) == "table" and type(hs.timer.absoluteTime) == "function" then
		return tonumber(hs.timer.absoluteTime()) or 0
	end

	return 0
end

local function normalize_number(value, fallback, minimum)
	local number = tonumber(value)

	if number == nil then
		number = fallback
	end

	return math.max(minimum, math.floor(number))
end

local function normalize_menu_history_size(value, fallback)
	local number = tonumber(value)

	if number == nil then
		number = fallback
	end

	if number == nil then
		return nil
	end

	return math.max(1, math.floor(number))
end

local function same_list(left, right)
	if #left ~= #right then
		return false
	end

	for index, value in ipairs(left) do
		if right[index] ~= value then
			return false
		end
	end

	return true
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

local function format_hotkey_for_prompt(modifiers, key)
	local modifier_names = {}

	for _, modifier in ipairs(modifiers or {}) do
		table.insert(modifier_names, modifier_prompt_names[modifier] or modifier)
	end

	return table.concat(modifier_names, "+"), key or ""
end

do
	local configured_modifiers, invalid_modifier = normalize_hotkey_modifiers(clipboard.prefix or {})

	if configured_modifiers == nil then
		log.e("invalid clipboard hotkey modifier in config: " .. tostring(invalid_modifier))
		configured_modifiers = {}
	end

	default_hotkey_modifiers = configured_modifiers
	default_hotkey_key = normalize_hotkey_key(clipboard.key)
	state.hotkey_modifiers = copy_list(default_hotkey_modifiers)
	state.hotkey_key = default_hotkey_key

	local persisted_hotkey_modifiers = hs.settings.get(hotkey_modifiers_settings_key)
	local persisted_hotkey_key = hs.settings.get(hotkey_key_settings_key)

	if persisted_hotkey_modifiers ~= nil or persisted_hotkey_key ~= nil then
		local normalized_modifiers, persisted_invalid_modifier = normalize_hotkey_modifiers(persisted_hotkey_modifiers)
		local normalized_key = normalize_hotkey_key(persisted_hotkey_key)

		if normalized_modifiers == nil then
			log.w("ignore invalid persisted clipboard hotkey modifier: " .. tostring(persisted_invalid_modifier))
			hs.settings.clear(hotkey_modifiers_settings_key)
			hs.settings.clear(hotkey_key_settings_key)
		else
			state.hotkey_modifiers = normalized_modifiers
			state.hotkey_key = normalized_key
		end
	end
end

local function next_history_id()
	history_id_counter = history_id_counter + 1

	return string.format("history-%d-%d-%d", os.time(), math.floor(tonumber(hs.timer.absoluteTime()) or 0), history_id_counter)
end

local function resolve_cache_dir()
	local configured = trim(tostring(clipboard.image_cache_dir or ""))

	if configured == "" then
		local home = os.getenv("HOME") or ""
		local bundle_id = trim(tostring(hs.settings.bundleID or ""))

		if bundle_id == "" then
			bundle_id = "org.hammerspoon.Hammerspoon"
		end

		return string.format("%s/Library/Caches/%s/clipboard_center_images", home, bundle_id)
	end

	configured = expand_home_path(configured)

	if string.sub(configured, 1, 1) == "/" then
		return configured
	end

	return hs.configdir .. "/" .. configured
end

local function resolve_target_screen_frame()
	local target_screen = nil
	local focused_window = hs.window.focusedWindow()

	if focused_window ~= nil then
		target_screen = focused_window:screen()
	end

	if target_screen == nil then
		target_screen = hs.screen.mainScreen()
	end

	if target_screen == nil then
		return nil
	end

	return target_screen:frame()
end

local function chooser_window_height()
	local chooser_rows = normalize_number(clipboard.chooser_rows, 12, 6)

	-- Mirrors HSChooser.m + HSChooserWindow.xib:
	-- finalHeight = non-table chrome + (rowHeight + intercellSpacing) * numRows
	return chooser_window_chrome_height + ((chooser_row_height + chooser_row_spacing) * chooser_rows)
end

local function chooser_layout(screen_frame)
	if screen_frame == nil then
		return nil
	end

	local chooser_width_percent = normalize_number(clipboard.chooser_width, 40, 20)
	local chooser_width = math.floor(screen_frame.w * chooser_width_percent / 100)
	local chooser_height = chooser_window_height()
	local preview_width = math.min(default_preview_width, math.floor(screen_frame.w * 0.34))
	local preview_height = math.min(default_preview_height, math.floor(screen_frame.h * 0.56))
	local chooser_x = screen_frame.x + math.floor((screen_frame.w - chooser_width) / 2)
	local preview_x = screen_frame.x + screen_frame.w - preview_width - default_preview_margin
	local preview_y = screen_frame.y + math.floor((screen_frame.h - preview_height) / 2)
	local chooser_y = screen_frame.y + math.floor((screen_frame.h - chooser_height) / 2)

	if default_preview_enabled == true then
		local total_width = chooser_width + default_preview_gap + preview_width + (default_preview_margin * 2)

		if total_width <= screen_frame.w then
			chooser_x = screen_frame.x + math.floor((screen_frame.w - (chooser_width + default_preview_gap + preview_width)) / 2)
			preview_x = chooser_x + chooser_width + default_preview_gap
		end
	end

	return {
		chooser_point = hs.geometry.point(chooser_x, chooser_y),
		preview_frame = {
			x = preview_x,
			y = preview_y,
			w = preview_width,
			h = preview_height,
		},
	}
end

local function preview_colors()
	if hs.host.interfaceStyle() == "Dark" then
		return {
			background = { red = 0.13, green = 0.14, blue = 0.17, alpha = 0.97 },
			border = { white = 1, alpha = 0.12 },
			title = { white = 1, alpha = 0.96 },
			detail = { white = 1, alpha = 0.56 },
			body = { white = 1, alpha = 0.9 },
			image_background = { white = 1, alpha = 0.04 },
			shadow = { alpha = 0.28, white = 0 },
		}
	end

	return {
		background = { white = 1, alpha = 0.98 },
		border = { white = 0, alpha = 0.1 },
		title = { white = 0.08, alpha = 1 },
		detail = { white = 0.22, alpha = 0.74 },
		body = { white = 0.08, alpha = 0.96 },
		image_background = { white = 0, alpha = 0.04 },
		shadow = { alpha = 0.18, white = 0 },
	}
end

local function safe_remove_file(path)
	if file_exists(path) ~= true then
		return
	end

	local ok, err = os.remove(path)

	if ok ~= true then
		log.w(string.format("failed to remove cached clipboard image: %s (%s)", path, tostring(err)))
	end
end

local function sanitize_text(text)
	if type(text) ~= "string" then
		return nil
	end

	text = text:gsub("\r\n", "\n")
	text = text:gsub("\r", "\n")

	if trim(text) == "" then
		return nil
	end

	if #text > default_max_item_length then
		log.w(string.format("ignore clipboard text larger than %d bytes", default_max_item_length))
		return nil
	end

	return text
end

local function safe_utf8len(text)
	local ok, length = pcall(utf8len, text or "")

	if ok ~= true or type(length) ~= "number" then
		return #(text or "")
	end

	return length
end

local function truncate_text(text, max_chars)
	local length = safe_utf8len(text)

	if length <= max_chars then
		return text
	end

	return utf8sub(text, 1, max_chars) .. "..."
end

local function compact_preview(text, max_chars)
	local preview = trim(text or "")

	preview = preview:gsub("%s*\n%s*", " ⏎ ")
	preview = preview:gsub("%s+", " ")

	if preview == "" then
		preview = "(空白)"
	end

	return truncate_text(preview, max_chars)
end

local function normalize_search_text(text)
	if type(text) ~= "string" then
		return ""
	end

	text = text:gsub("\r\n", "\n")
	text = text:gsub("\r", "\n")
	text = text:gsub("%s+", " ")
	text = trim(text)

	if text == "" then
		return ""
	end

	return string.lower(text)
end

local function line_count(text)
	local _, count = string.gsub(text or "", "\n", "\n")

	return count + 1
end

local function describe_text(text)
	local lines = line_count(text)
	local characters = safe_utf8len(text)

	if lines > 1 then
		return string.format("%d 行 · %d 字符", lines, characters)
	end

	return string.format("%d 字符", characters)
end

local function format_timestamp(timestamp)
	if type(timestamp) ~= "number" then
		return "未知时间"
	end

	return os.date("%m-%d %H:%M", timestamp)
end

local function image_dimensions(item)
	local width = math.max(0, math.floor(tonumber(item.width) or 0))
	local height = math.max(0, math.floor(tonumber(item.height) or 0))

	if width > 0 and height > 0 then
		return string.format("%dx%d", width, height)
	end

	return "未知尺寸"
end

local function describe_history_item(item)
	if type(item) ~= "table" then
		return "未知内容"
	end

	if item.kind == "image" then
		return "图片 · " .. image_dimensions(item)
	end

	return "文本 · " .. describe_text(item.content or "")
end

local function truncate_preview_body(text)
	text = tostring(text or "")

	if safe_utf8len(text) <= preview_body_max_chars then
		return text
	end

	return truncate_text(text, preview_body_max_chars) .. "\n\n..."
end

local function looks_like_code(text)
	if type(text) ~= "string" or text == "" then
		return false
	end

	local lower_text = string.lower(text)
	local has_code_keywords = lower_text:find("function", 1, true) ~= nil
		or lower_text:find("local ", 1, true) ~= nil
		or lower_text:find("return ", 1, true) ~= nil
		or lower_text:find("select ", 1, true) ~= nil
		or lower_text:find("insert ", 1, true) ~= nil
		or lower_text:find("update ", 1, true) ~= nil
		or lower_text:find("delete ", 1, true) ~= nil
		or lower_text:find("from ", 1, true) ~= nil
		or lower_text:find("const ", 1, true) ~= nil
		or lower_text:find("import ", 1, true) ~= nil
		or lower_text:find("class ", 1, true) ~= nil

	if has_code_keywords == true then
		return true
	end

	if text:find("[{}();=<>]") ~= nil and text:find("\n", 1, true) ~= nil then
		return true
	end

	if text:find("^%s*[%-%*]%s") ~= nil then
		return false
	end

	return false
end

local function preview_body_font(choice, body)
	local preview_group = tostring(choice.preview_group or "")
	local preview_title = string.lower(tostring(choice.preview_title or choice.text or ""))

	if choice.preview_body_font ~= nil then
		return choice.preview_body_font
	end

	if preview_group:find("代码") ~= nil or preview_title:find("code", 1, true) ~= nil or preview_title:find("lua", 1, true) ~= nil then
		return "Menlo"
	end

	if looks_like_code(body) == true then
		return "Menlo"
	end

	return nil
end

local function build_text_preview_model(choice)
	if type(choice) ~= "table" or type(choice.content) ~= "string" then
		return nil
	end

	local body = truncate_preview_body(choice.content)
	local title = trim(tostring(choice.preview_title or choice.text or ""))
	local detail = trim(tostring(choice.preview_detail or choice.subText or ""))

	if title == "" then
		title = "文本预览"
	end

	return {
		kind = "text",
		title = title,
		detail = detail,
		body = body,
		body_font = preview_body_font(choice, body),
	}
end

local function item_signature(item)
	if type(item) ~= "table" then
		return nil
	end

	if item.kind == "image" then
		local fingerprint = trim(tostring(item.fingerprint or ""))

		if fingerprint == "" then
			return nil
		end

		return "image:" .. fingerprint
	end

	local content = item.content

	if type(content) ~= "string" then
		return nil
	end

	return "text:" .. content
end

local function history_counts()
	local text_count = 0
	local image_count = 0

	for _, item in ipairs(state.history) do
		if item.kind == "image" then
			image_count = image_count + 1
		else
			text_count = text_count + 1
		end
	end

	return text_count, image_count
end

local function persist_history()
	if #state.history == 0 then
		hs.settings.clear(history_settings_key)
		return
	end

	hs.settings.set(history_settings_key, state.history)
end

local function persist_menu_history_size()
	if state.menu_history_size == default_menu_history_size then
		hs.settings.clear(menu_history_size_settings_key)
		return
	end

	hs.settings.set(menu_history_size_settings_key, state.menu_history_size)
end

local function persist_hotkey_state()
	if same_list(state.hotkey_modifiers, default_hotkey_modifiers) and state.hotkey_key == default_hotkey_key then
		hs.settings.clear(hotkey_modifiers_settings_key)
		hs.settings.clear(hotkey_key_settings_key)
		return
	end

	hs.settings.set(hotkey_modifiers_settings_key, copy_list(state.hotkey_modifiers))
	hs.settings.set(hotkey_key_settings_key, state.hotkey_key or "")
end

local function cleanup_removed_image_files(previous_history, next_history)
	local referenced_paths = {}

	for _, item in ipairs(next_history or {}) do
		if item.kind == "image" and type(item.image_path) == "string" then
			referenced_paths[item.image_path] = true
		end
	end

	for _, item in ipairs(previous_history or {}) do
		if item.kind == "image" and type(item.image_path) == "string" then
			if referenced_paths[item.image_path] ~= true then
				safe_remove_file(item.image_path)
			end
		end
	end
end

local refresh_menubar
local refresh_chooser_choices

local function set_menu_history_size(value, options)
	options = options or {}

	local normalized = normalize_menu_history_size(value, nil)

	if normalized == nil then
		return false
	end

	if state.menu_history_size == normalized then
		persist_menu_history_size()
		return true
	end

	state.menu_history_size = normalized
	persist_menu_history_size()

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	if options.show_alert ~= false then
		hs.alert.show(string.format("菜单显示数量已更新为 %d", normalized))
	end

	return true
end

local function replace_history(next_history)
	local previous_history = state.history

	state.history = next_history or {}
	persist_history()
	cleanup_removed_image_files(previous_history, state.history)

	if refresh_menubar ~= nil then
		refresh_menubar()
	end
end

local function build_menubar_icon()
	if state.menubar_icon ~= nil then
		return state.menubar_icon
	end

	local canvas = hs.canvas.new({ x = 0, y = 0, w = 18, h = 18 })

	if canvas == nil then
		return nil
	end

	local icon_color = { red = 0, green = 0, blue = 0, alpha = 1 }

	canvas:appendElements({
		type = "rectangle",
		action = "stroke",
		strokeColor = icon_color,
		strokeWidth = 1.35,
		roundedRectRadii = { xRadius = 2.2, yRadius = 2.2 },
		frame = { x = 4.2, y = 4.9, w = 9.6, h = 9.8 },
	}, {
		type = "segments",
		action = "stroke",
		closed = false,
		strokeWidth = 1.35,
		strokeCapStyle = "round",
		strokeColor = icon_color,
		coordinates = {
			{ x = 7.0, y = 5.0 },
			{ x = 7.0, y = 4.2 },
			{ x = 11.0, y = 4.2 },
			{ x = 11.0, y = 5.0 },
		},
	}, {
		type = "rectangle",
		action = "fill",
		fillColor = icon_color,
		roundedRectRadii = { xRadius = 1.6, yRadius = 1.6 },
		frame = { x = 6.3, y = 2.3, w = 5.4, h = 2.7 },
	})

	local icon = canvas:imageFromCanvas()

	canvas:delete()

	if icon == nil then
		return nil
	end

	icon:size({ w = menubar_icon_size, h = menubar_icon_size }, true)
	icon:template(true)
	state.menubar_icon = icon

	return state.menubar_icon
end

local function tooltip_text(hotkey_label)
	local text_count, image_count = history_counts()

	return string.format(
		"剪贴板中心\n历史条数: %d (文本 %d / 图片 %d)\n快捷键: %s",
		#state.history,
		text_count,
		image_count,
		hotkey_label
	)
end

local function display_hotkey_label()
	if state.hotkey_key == nil then
		return "已禁用"
	end

	return format_hotkey(state.hotkey_modifiers, state.hotkey_key)
end

local function build_text_history_item(text, timestamp)
	local sanitized = sanitize_text(text)

	if sanitized == nil then
		return nil
	end

	return {
		id = next_history_id(),
		kind = "text",
		content = sanitized,
		stored_at = timestamp or os.time(),
	}
end

local function image_hash(image)
	if image == nil then
		return nil
	end

	local ok, encoded = pcall(function()
		return image:encodeAsURLString(true, "PNG")
	end)

	if ok ~= true or type(encoded) ~= "string" or encoded == "" then
		log.w("failed to encode clipboard image for hashing")
		return nil
	end

	return hs.hash.SHA256(encoded)
end

local function save_image_to_cache(image, fingerprint)
	if ensure_directory(image_cache_dir) ~= true then
		return nil
	end

	local path = string.format("%s/%s.png", image_cache_dir, fingerprint)
	local ok = image:saveToFile(path, true, "PNG")

	if ok ~= true then
		log.e("failed to cache clipboard image: " .. path)
		return nil
	end

	return path
end

local function build_image_history_item(image, timestamp)
	if default_capture_images ~= true or image == nil then
		return nil
	end

	local fingerprint = image_hash(image)

	if fingerprint == nil then
		return nil
	end

	local path = save_image_to_cache(image, fingerprint)

	if path == nil then
		return nil
	end

	local size = image:size() or {}

	return {
		id = next_history_id(),
		kind = "image",
		fingerprint = fingerprint,
		image_path = path,
		width = math.max(0, math.floor((tonumber(size.w) or 0) + 0.5)),
		height = math.max(0, math.floor((tonumber(size.h) or 0) + 0.5)),
		stored_at = timestamp or os.time(),
	}
end

local function normalize_history_item(item)
	local stored_at = os.time()

	if type(item) == "string" then
		return build_text_history_item(item, stored_at)
	end

	if type(item) ~= "table" then
		return nil
	end

	local item_id = trim(tostring(item.id or ""))

	if item_id == "" then
		item_id = next_history_id()
	end

	if type(item.stored_at) == "number" then
		stored_at = item.stored_at
	end

	if item.kind == "image" then
		local image_path = trim(tostring(item.image_path or ""))
		local fingerprint = trim(tostring(item.fingerprint or ""))

		if image_path == "" or fingerprint == "" or file_exists(image_path) ~= true then
			return nil
		end

		return {
			id = item_id,
			kind = "image",
			image_path = image_path,
			fingerprint = fingerprint,
			width = math.max(0, math.floor(tonumber(item.width) or 0)),
			height = math.max(0, math.floor(tonumber(item.height) or 0)),
			stored_at = stored_at,
		}
	end

	local normalized = build_text_history_item(item.content, stored_at)

	if normalized ~= nil then
		normalized.id = item_id
	end

	return normalized
end

local function add_history_item(item, reason)
	if type(item) ~= "table" then
		return false
	end

	local signature = item_signature(item)

	if signature == nil then
		return false
	end

	local history_limit = normalize_number(clipboard.history_size, default_history_size, 1)
	local deduplicate = clipboard.deduplicate ~= false
	local history = {}
	local found = false

	for _, existing in ipairs(state.history) do
		local existing_signature = item_signature(existing)

		if deduplicate == true and existing_signature == signature then
			found = true
		else
			table.insert(history, existing)
		end
	end

	table.insert(history, 1, item)

	while #history > history_limit do
		table.remove(history)
	end

	replace_history(history)

	log.d(
		string.format(
			"clipboard history updated (%s): total=%d, kind=%s, deduplicated=%s",
			reason or "unknown",
			#state.history,
			tostring(item.kind),
			tostring(found)
		)
	)

	return true
end

local function clear_history()
	replace_history({})
	hs.alert.show("已清空剪贴板历史")
end

local function load_history()
	local saved = hs.settings.get(history_settings_key)
	local loaded = {}

	if type(saved) == "table" then
		local history_limit = normalize_number(clipboard.history_size, default_history_size, 1)

		for _, item in ipairs(saved) do
			local normalized = normalize_history_item(item)

			if normalized ~= nil then
				table.insert(loaded, normalized)
			end

			if #loaded >= history_limit then
				break
			end
		end
	end

	state.history = loaded
end

local function choice_to_history_item(choice)
	if type(choice) ~= "table" then
		return nil
	end

	if choice.kind == "image" then
		local image_path = trim(tostring(choice.image_path or ""))
		local fingerprint = trim(tostring(choice.fingerprint or ""))

		if image_path == "" or fingerprint == "" then
			return nil
		end

		return {
			id = next_history_id(),
			kind = "image",
			image_path = image_path,
			fingerprint = fingerprint,
			width = math.max(0, math.floor(tonumber(choice.width) or 0)),
			height = math.max(0, math.floor(tonumber(choice.height) or 0)),
			stored_at = os.time(),
		}
	end

	return build_text_history_item(choice.content, os.time())
end

local function load_image(path)
	if file_exists(path) ~= true then
		return nil
	end

	return hs.image.imageFromPath(path)
end

local function resized_thumbnail(item, size)
	if item.kind ~= "image" then
		return nil
	end

	local image = load_image(item.image_path)

	if image == nil then
		return nil
	end

	return image:setSize({ h = size, w = size }, false)
end

local function chooser_thumbnail(item)
	return resized_thumbnail(item, chooser_inline_thumbnail_size)
end

local function menu_thumbnail(item)
	return resized_thumbnail(item, default_menu_thumbnail_size)
end

local function ensure_preview_canvas(frame)
	if state.preview_canvas == nil then
		state.preview_canvas = hs.canvas.new(frame)

		pcall(function()
			state.preview_canvas:level(hs.canvas.windowLevels.modalPanel)
		end)
		pcall(function()
			state.preview_canvas:clickActivating(false)
		end)
	end

	state.preview_canvas:frame(frame)

	return state.preview_canvas
end

local function hide_image_preview()
	state.preview_signature = nil

	if state.preview_canvas ~= nil then
		state.preview_canvas:hide(0.1)
	end
end

local function build_text_preview_elements(frame, preview)
	local colors = preview_colors()
	local outer_radius = 16
	local inner_radius = 12
	local horizontal_padding = 18
	local top_padding = 16
	local title_height = 24
	local detail_height = preview.detail ~= "" and 18 or 0
	local body_top = top_padding + title_height + detail_height + 12
	local body_frame = {
		x = horizontal_padding,
		y = body_top,
		w = frame.w - (horizontal_padding * 2),
		h = frame.h - body_top - horizontal_padding,
	}
	local text_style = {
		color = colors.body,
		paragraphStyle = {
			lineBreak = "wordWrap",
			lineSpacing = preview.body_font ~= nil and 3 or 4,
		},
	}

	if preview.body_font ~= nil then
		text_style.font = {
			name = preview.body_font,
			size = 12.5,
		}
	else
		text_style.font = {
			size = 14,
		}
	end

	local styled_body = hs.styledtext.new(preview.body, text_style)

	return {
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.background,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			withShadow = true,
			shadow = {
				blurRadius = 18,
				color = colors.shadow,
				offset = { h = 0, w = 0 },
			},
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			frame = { x = 0.5, y = 0.5, w = frame.w - 1, h = frame.h - 1 },
		},
		{
			type = "text",
			text = preview.title,
			textSize = 17,
			textColor = colors.title,
			frame = {
				x = horizontal_padding,
				y = top_padding,
				w = frame.w - (horizontal_padding * 2),
				h = title_height,
			},
		},
		{
			type = "text",
			text = preview.detail,
			textSize = 12,
			textColor = colors.detail,
			frame = {
				x = horizontal_padding,
				y = top_padding + title_height,
				w = frame.w - (horizontal_padding * 2),
				h = detail_height,
			},
		},
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.image_background,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = body_frame,
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = body_frame,
		},
		{
			type = "text",
			text = styled_body,
			frame = {
				x = body_frame.x + 12,
				y = body_frame.y + 10,
				w = body_frame.w - 24,
				h = body_frame.h - 20,
			},
		},
	}
end

local function build_image_preview_elements(frame, image, detail)
	local colors = preview_colors()
	local outer_radius = 16
	local inner_radius = 12
	local horizontal_padding = 18
	local top_padding = 16
	local title_height = 24
	local detail_height = 18
	local image_top = top_padding + title_height + detail_height + 12
	local image_frame = {
		x = horizontal_padding,
		y = image_top,
		w = frame.w - (horizontal_padding * 2),
		h = frame.h - image_top - horizontal_padding,
	}

	return {
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.background,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			withShadow = true,
			shadow = {
				blurRadius = 18,
				color = colors.shadow,
				offset = { h = 0, w = 0 },
			},
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			frame = { x = 0.5, y = 0.5, w = frame.w - 1, h = frame.h - 1 },
		},
		{
			type = "text",
			text = "图片预览",
			textSize = 17,
			textColor = colors.title,
			frame = {
				x = horizontal_padding,
				y = top_padding,
				w = frame.w - (horizontal_padding * 2),
				h = title_height,
			},
		},
		{
			type = "text",
			text = detail,
			textSize = 12,
			textColor = colors.detail,
			frame = {
				x = horizontal_padding,
				y = top_padding + title_height,
				w = frame.w - (horizontal_padding * 2),
				h = detail_height,
			},
		},
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.image_background,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = image_frame,
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = image_frame,
		},
		{
			type = "image",
			image = image,
			imageScaling = "scaleProportionally",
			frame = {
				x = image_frame.x + 1,
				y = image_frame.y + 1,
				w = image_frame.w - 2,
				h = image_frame.h - 2,
			},
		},
	}
end

local function build_choice_preview(choice)
	if type(choice) ~= "table" then
		return nil
	end

	if choice.kind == "image" then
		local item = choice_to_history_item(choice)

		if item == nil then
			return nil
		end

		local image = load_image(item.image_path)

		if image == nil then
			return nil
		end

		return {
			kind = "image",
			signature = item_signature(item),
			item = item,
			image = image,
			detail = trim(
				tostring(choice.preview_detail or string.format("%s · %s", image_dimensions(item), format_timestamp(item.stored_at)))
			),
		}
	end

	local text_preview = build_text_preview_model(choice)

	if text_preview == nil then
		return nil
	end

	return {
		kind = "text",
		signature = string.format("preview:%s:%s", tostring(choice.source or ""), tostring(choice.content or "")),
		text_preview = text_preview,
	}
end

local function hide_preview()
	hide_image_preview()
end

local function update_preview()
	if default_preview_enabled ~= true or state.chooser == nil then
		return
	end

	local choice = state.chooser:selectedRowContents()

	if type(choice) ~= "table" then
		hide_preview()
		return
	end

	local preview = build_choice_preview(choice)

	if preview == nil or preview.signature == nil then
		hide_preview()
		return
	end

	local screen_frame = state.chooser_screen_frame or resolve_target_screen_frame()
	local layout = chooser_layout(screen_frame)

	if layout == nil then
		hide_preview()
		return
	end

	local canvas = ensure_preview_canvas(layout.preview_frame)

	if state.preview_signature ~= preview.signature or canvas:isShowing() ~= true then
		if preview.kind == "image" then
			canvas:replaceElements(table.unpack(build_image_preview_elements(layout.preview_frame, preview.image, preview.detail)))
		else
			canvas:replaceElements(table.unpack(build_text_preview_elements(layout.preview_frame, preview.text_preview)))
		end

		canvas:show(0.08)
	end

	state.preview_signature = preview.signature
end

local function stop_preview_timer()
	if state.preview_timer ~= nil then
		state.preview_timer:stop()
		state.preview_timer = nil
	end
end

local function start_preview_timer()
	if default_preview_enabled ~= true then
		return
	end

	stop_preview_timer()

	state.preview_timer = hs.timer.doEvery(default_preview_poll_interval, update_preview)
	update_preview()
end

local function set_clipboard_item(item)
	local signature = item_signature(item)

	if signature == nil then
		return false
	end

	state.suppressed_signature = signature
	state.suppressed_at = os.time()

	if item.kind == "image" then
		local image = load_image(item.image_path)

		if image == nil then
			state.suppressed_signature = nil
			state.suppressed_at = nil
			hs.alert.show("图片缓存已失效，无法恢复")
			return false
		end

		local ok = hs.pasteboard.writeObjects(image)

		if ok ~= true then
			state.suppressed_signature = nil
			state.suppressed_at = nil
			hs.alert.show("写入图片剪贴板失败")
			return false
		end

		return true
	end

	local ok = hs.pasteboard.setContents(item.content)

	if ok ~= true then
		state.suppressed_signature = nil
		state.suppressed_at = nil
		hs.alert.show("写入剪贴板失败")
		return false
	end

	return true
end

local function activate_choice(choice)
	local item = choice_to_history_item(choice)

	if item == nil then
		return
	end

	if set_clipboard_item(item) ~= true then
		return
	end

	add_history_item(item, choice.source or "chooser select")

	if item.kind == "image" then
		hs.alert.show("已恢复图片到剪贴板")
	else
		hs.alert.show("已恢复历史剪贴板内容")
	end
end

local function history_choice(item, index)
	if item.kind == "image" then
		local detail = string.format("历史 #%d · %s · 图片", index, format_timestamp(item.stored_at))

		return {
			text = "图片 " .. image_dimensions(item),
			subText = detail,
			preview_title = "图片预览",
			preview_detail = string.format("历史 #%d · %s · %s", index, format_timestamp(item.stored_at), image_dimensions(item)),
			image = chooser_thumbnail(item),
			source = "history",
			history_id = item.id,
			kind = "image",
			image_path = item.image_path,
			fingerprint = item.fingerprint,
			width = item.width,
			height = item.height,
			stored_at = item.stored_at,
			search_text = normalize_search_text(table.concat({
				"图片 " .. image_dimensions(item),
				detail,
				string.format("历史 #%d %s %s", index, format_timestamp(item.stored_at), image_dimensions(item)),
			}, "\n")),
		}
	end

	local detail = string.format("历史 #%d · %s · 文本 · %s", index, format_timestamp(item.stored_at), describe_text(item.content))

	return {
		text = compact_preview(item.content, history_preview_length),
		subText = detail,
		preview_title = compact_preview(item.content, 48),
		preview_detail = detail,
		source = "history",
		history_id = item.id,
		kind = "text",
		content = item.content,
		search_text = normalize_search_text(table.concat({
			item.content,
			detail,
		}, "\n")),
	}
end

local function build_chooser_choices(query)
	local choices = {}
	local normalized_query = normalize_search_text(query)

	for index, item in ipairs(state.history) do
		local choice = history_choice(item, index)

		if normalized_query == "" or choice.search_text:find(normalized_query, 1, true) ~= nil then
			table.insert(choices, choice)
		end
	end

	return choices
end

refresh_chooser_choices = function(preserve_query, selected_row)
	if state.chooser == nil then
		return
	end

	local chooser_visible = state.chooser:isVisible() == true
	local query = nil

	if preserve_query == true then
		query = state.chooser:query()
	end

	local choices = build_chooser_choices(query)

	state.chooser:choices(choices)

	if preserve_query ~= true then
		state.chooser:query(nil)
	end

	if chooser_visible ~= true then
		pcall(function()
			state.chooser:selectedRow(0)
		end)
		hide_preview()
		return
	end

	if #choices > 0 then
		local target_row = 1

		if type(selected_row) == "number" and selected_row > 0 then
			target_row = math.min(selected_row, #choices)
		end

		pcall(function()
			state.chooser:selectedRow(target_row)
		end)
		update_preview()
		return
	end

	pcall(function()
		state.chooser:selectedRow(0)
	end)
	hide_preview()
end

local function delete_history_item_by_id(history_id)
	local normalized_id = trim(tostring(history_id or ""))

	if normalized_id == "" then
		return false, nil
	end

	local next_history = {}
	local removed_item = nil

	for _, item in ipairs(state.history) do
		if removed_item == nil and item.id == normalized_id then
			removed_item = item
		else
			table.insert(next_history, item)
		end
	end

	if removed_item == nil then
		return false, nil
	end

	replace_history(next_history)

	return true, removed_item
end

local function delete_history_choice(choice, options)
	options = options or {}

	if type(choice) ~= "table" or choice.source ~= "history" then
		hs.alert.show("只有历史记录支持删除")
		return false
	end

	local selected_row = options.selected_row

	if state.chooser ~= nil and (type(selected_row) ~= "number" or selected_row < 1) then
		selected_row = state.chooser:selectedRow() or 0
	end

	local ok = delete_history_item_by_id(choice.history_id)

	if ok ~= true then
		hs.alert.show("删除历史记录失败")
		return false
	end

	refresh_chooser_choices(true, selected_row)
	hs.alert.show("已删除这条历史")

	return true
end

local function popup_context_menu(menu, point)
	if type(menu) ~= "table" or #menu == 0 then
		return
	end

	local popup = hs.menubar.new(false)

	if popup == nil then
		return
	end

	popup:setMenu(menu)
	popup:popupMenu(point or hs.mouse.absolutePosition())
	popup:delete()
end

local function show_chooser_context_menu(row)
	if state.chooser == nil or type(row) ~= "number" or row < 1 then
		return
	end

	pcall(function()
		state.chooser:selectedRow(row)
	end)

	local choice = state.chooser:selectedRowContents(row)

	if type(choice) ~= "table" or next(choice) == nil then
		return
	end

	if choice.source == "history" and trim(tostring(choice.history_id or "")) ~= "" then
		popup_context_menu({
			{
				title = "删除这条历史",
				fn = function()
					delete_history_choice(choice, { selected_row = row })
				end,
			},
		})

		return
	end

	popup_context_menu({
		{ title = "该项不支持删除", disabled = true },
	})
end

local function history_menu_title(item)
	if item.kind == "image" then
		return "[图片] " .. image_dimensions(item)
	end

	return compact_preview(item.content or "", menu_preview_length)
end

local function history_menu_tooltip(item)
	if item.kind == "image" then
		return truncate_text(
			string.format("%s · %s", describe_history_item(item), tostring(item.image_path or "")),
			tooltip_preview_length
		)
	end

	return truncate_text(item.content or "", tooltip_preview_length)
end

local function history_menu_choice(item)
	if item.kind == "image" then
		return {
			source = "history",
			history_id = item.id,
			kind = "image",
			image_path = item.image_path,
			fingerprint = item.fingerprint,
			width = item.width,
			height = item.height,
		}
	end

	return {
		source = "history",
		history_id = item.id,
		kind = "text",
		content = item.content,
	}
end

local function build_menu_history_size_menu()
	local current = state.menu_history_size or default_menu_history_size
	local values = {}
	local seen = {}

	local function add_value(value)
		local normalized = normalize_menu_history_size(value, nil)

		if normalized == nil or seen[normalized] == true then
			return
		end

		seen[normalized] = true
		table.insert(values, normalized)
	end

	for _, value in ipairs({ 1, 3, 5, 8, 12, 16, 20 }) do
		add_value(value)
	end

	add_value(default_menu_history_size)
	add_value(current)

	table.sort(values)

	local menu = {
		{ title = string.format("当前: %d", current), disabled = true },
	}

	for _, value in ipairs(values) do
		table.insert(menu, {
			title = string.format("%d 条", value),
			checked = current == value,
			fn = function()
				set_menu_history_size(value)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义...",
		fn = function()
			local raw_value = prompt_text(
				"最近历史显示数量",
				"请输入菜单栏主菜单中直接显示的最近历史条数，最小为 1。",
				tostring(current)
			)

			if raw_value == nil then
				return
			end

			local normalized = normalize_menu_history_size(raw_value, nil)

			if normalized == nil then
				hs.alert.show("请输入有效数字")
				return
			end

			set_menu_history_size(normalized)
		end,
	})

	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = string.format("恢复默认 (%d)", default_menu_history_size),
		disabled = current == default_menu_history_size,
		fn = function()
			set_menu_history_size(default_menu_history_size)
		end,
	})

	return menu
end

local function append_history_menu_items(menu)
	local count = math.min(#state.history, state.menu_history_size or default_menu_history_size)

	table.insert(menu, {
		title = string.format("最近历史 (%d/%d)", count, #state.history),
		disabled = true,
	})

	if count == 0 then
		table.insert(menu, { title = "暂无历史", disabled = true })
		return
	end

	table.insert(menu, { title = "点击恢复，前 9 条可直接按数字，按住 ⌘ 点击可删除", disabled = true })

	for index = 1, count do
		local item = state.history[index]
		local choice = history_menu_choice(item)

		table.insert(menu, {
			title = history_menu_title(item),
			tooltip = history_menu_tooltip(item),
			image = menu_thumbnail(item),
			shortcut = index <= menu_history_shortcut_limit and tostring(index) or nil,
			fn = function(modifiers)
				if type(modifiers) == "table" and modifiers.cmd == true then
					delete_history_choice(choice)
					return
				end

				activate_choice(choice)
			end,
		})
	end
end

local show_chooser

local function create_hotkey_binding(modifiers, key)
	if key == nil then
		return true, nil
	end

	local binding = hotkey_helper.bind(copy_list(modifiers), key, clipboard.message or "Clipboard Center", function()
		show_chooser()
	end, nil, nil, { logger = log })

	if binding == nil then
		return false, "bind failed"
	end

	return true, binding
end

local function replace_hotkey_binding(binding)
	if state.hotkey ~= nil then
		state.hotkey:delete()
	end

	state.hotkey = binding
end

local function apply_hotkey_binding(reason)
	local ok, binding_or_error = create_hotkey_binding(state.hotkey_modifiers, state.hotkey_key)

	if ok ~= true then
		log.e(string.format("failed to bind clipboard hotkey (%s): %s", reason or "unknown", tostring(binding_or_error)))
		return false
	end

	replace_hotkey_binding(binding_or_error)
	refresh_menubar()

	return true
end

local function set_hotkey(modifiers, key, reason)
	if same_list(state.hotkey_modifiers, modifiers) and state.hotkey_key == key then
		return true
	end

	local previous_modifiers = copy_list(state.hotkey_modifiers)
	local previous_key = state.hotkey_key
	local previous_binding = state.hotkey

	state.hotkey_modifiers = copy_list(modifiers)
	state.hotkey_key = key
	state.hotkey = nil

	if previous_binding ~= nil then
		previous_binding:delete()
	end

	if apply_hotkey_binding(reason) ~= true then
		state.hotkey_modifiers = previous_modifiers
		state.hotkey_key = previous_key
		state.hotkey = nil
		apply_hotkey_binding("restore previous clipboard hotkey")
		hs.alert.show("剪贴板快捷键设置失败")
		return false
	end

	persist_hotkey_state()

	if state.hotkey_key == nil then
		hs.alert.show("已禁用剪贴板快捷键")
	else
		hs.alert.show("剪贴板快捷键已更新: " .. display_hotkey_label())
	end

	return true
end

local function prompt_hotkey_configuration()
	local current_modifiers, current_key = format_hotkey_for_prompt(state.hotkey_modifiers, state.hotkey_key)
	local modifier_text = prompt_text(
		"设置剪贴板快捷键",
		"请输入修饰键, 多个值用 + 分隔。\n可用: ctrl option command shift fn\n留空表示无修饰键。",
		current_modifiers
	)

	if modifier_text == nil then
		return
	end

	local key_text = prompt_text(
		"设置剪贴板快捷键",
		"请输入主键, 例如 c、space、return、f18。\n留空表示禁用快捷键。",
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

	set_hotkey(normalized_modifiers, normalized_key, "menubar update clipboard hotkey")
end

local function restore_default_hotkey()
	set_hotkey(default_hotkey_modifiers, default_hotkey_key, "restore default clipboard hotkey")
end

show_chooser = function()
	if started ~= true then
		if _M.start() ~= true then
			return
		end
	end

	if state.chooser == nil then
		return
	end

	state.chooser_screen_frame = resolve_target_screen_frame()

	state.chooser:choices(build_chooser_choices())
	state.chooser:query(nil)

	local layout = chooser_layout(state.chooser_screen_frame)

	if layout ~= nil then
		state.chooser:show(layout.chooser_point)
	else
		state.chooser:show()
	end
end

refresh_menubar = function()
	if state.show_menubar ~= true then
		if state.menubar ~= nil then
			state.menubar:delete()
			state.menubar = nil
		end
		return
	end

	if state.menubar == nil then
		state.menubar = hs.menubar.new()

		if state.menubar == nil then
			log.e("failed to create clipboard menubar item")
			return
		end
	end

	local display_modifiers = state.hotkey_modifiers
	local display_key = state.hotkey_key
	local text_count, image_count = history_counts()
	local hotkey_label = display_hotkey_label()

	local menubar_icon = build_menubar_icon()

	if menubar_icon ~= nil then
		state.menubar:setIcon(menubar_icon, true)
		state.menubar:setTitle(nil)
	else
		state.menubar:setIcon(nil)
		state.menubar:setTitle("📋")
	end

	state.menubar:setTooltip(tooltip_text(hotkey_label))
	state.menubar:setMenu(function()
		local menu = {
			{ title = "剪贴板中心", disabled = true },
			{
				title = string.format("历史: %d (文本 %d / 图片 %d)", #state.history, text_count, image_count),
				disabled = true,
			},
			{ title = "快捷键: " .. hotkey_label, disabled = true },
			{ title = "-" },
			{
				title = "打开 Chooser",
				fn = show_chooser,
			},
			{
				title = "设置快捷键",
				fn = prompt_hotkey_configuration,
			},
			{
				title = "恢复默认快捷键",
				disabled = same_list(display_modifiers, default_hotkey_modifiers) and display_key == default_hotkey_key,
				fn = restore_default_hotkey,
			},
			{
				title = "恢复最近一条历史",
				disabled = #state.history == 0,
				fn = function()
					if state.history[1] ~= nil then
						activate_choice(history_menu_choice(state.history[1]))
					end
				end,
			},
			{
				title = "清空历史",
				disabled = #state.history == 0,
				fn = clear_history,
			},
			{
				title = string.format("最近历史显示数量: %d", state.menu_history_size or default_menu_history_size),
				menu = build_menu_history_size_menu(),
			},
			{ title = "-" },
		}

		append_history_menu_items(menu)

		return menu
	end)
end

local function current_clipboard_item()
	local timestamp = os.time()

	if default_capture_images == true then
		local image = hs.pasteboard.readImage()

		if image ~= nil then
			local image_item = build_image_history_item(image, timestamp)

			if image_item ~= nil then
				return image_item
			end
		end
	end

	return build_text_history_item(hs.pasteboard.getContents(), timestamp)
end

local function capture_is_suspended()
	if state.capture_suspended_until == nil then
		return false
	end

	if current_absolute_time() <= state.capture_suspended_until then
		return true
	end

	state.capture_suspended_until = nil

	return false
end

local function suspend_capture(seconds)
	local duration = tonumber(seconds) or 0

	if duration <= 0 then
		duration = 1
	end

	state.capture_suspended_until = current_absolute_time() + math.floor(duration * 1000000000)
end

local function handle_pasteboard_change(_)
	if capture_is_suspended() == true then
		return
	end

	local item = current_clipboard_item()

	if item == nil then
		return
	end

	local signature = item_signature(item)

	if state.suppressed_signature ~= nil and signature == state.suppressed_signature then
		local suppressed_at = state.suppressed_at or 0

		if os.time() - suppressed_at <= duplicate_suppression_seconds then
			state.suppressed_signature = nil
			state.suppressed_at = nil
			return
		end
	end

	state.suppressed_signature = nil
	state.suppressed_at = nil

	add_history_item(item, "pasteboard watcher")
end

local function setup_chooser()
	state.chooser = hs.chooser.new(function(choice)
		if choice ~= nil then
			activate_choice(choice)
		end
	end)

	state.chooser:searchSubText(true)
	state.chooser:rows(normalize_number(clipboard.chooser_rows, 12, 6))
	state.chooser:width(normalize_number(clipboard.chooser_width, 40, 20))
	state.chooser:placeholderText("搜索历史拷贝，右键历史拷贝项可删除")
	state.chooser:showCallback(function()
		local selected_row = state.chooser:selectedRow() or 0

		if selected_row < 1 then
			pcall(function()
				state.chooser:selectedRow(1)
			end)
		end

		start_preview_timer()
	end)
	state.chooser:hideCallback(function()
		stop_preview_timer()
		hide_preview()
	end)
	state.chooser:queryChangedCallback(function()
		local selected_row = state.chooser:selectedRow() or 0

		refresh_chooser_choices(true, selected_row)
	end)
	state.chooser:rightClickCallback(function(row)
		show_chooser_context_menu(row)
	end)
end

local function sync_current_clipboard()
	local item = current_clipboard_item()

	if item ~= nil then
		add_history_item(item, "startup sync")
	end
end

local function delete_hotkey()
	if state.hotkey ~= nil then
		state.hotkey:delete()
		state.hotkey = nil
	end
end

local function destroy_menubar()
	if state.menubar ~= nil then
		state.menubar:delete()
		state.menubar = nil
	end
end

local function destroy_preview_canvas()
	if state.preview_canvas ~= nil then
		state.preview_canvas:hide(0)
		state.preview_canvas:delete()
		state.preview_canvas = nil
	end

	state.preview_signature = nil
end

local function destroy_chooser()
	if state.chooser == nil then
		return
	end

	pcall(function()
		state.chooser:hide()
	end)
	pcall(function()
		state.chooser:delete()
	end)

	state.chooser = nil
	state.chooser_screen_frame = nil
end

local function stop_pasteboard_watcher()
	if state.watcher == nil then
		return
	end

	pcall(function()
		state.watcher:stop()
	end)
end

local function start_pasteboard_watcher()
	if state.watcher == nil then
		state.watcher = hs.pasteboard.watcher.new(handle_pasteboard_change)
	end

	if state.watcher == nil then
		log.e("failed to create pasteboard watcher")
		return false
	end

	local running_ok, watcher_running = pcall(function()
		if type(state.watcher.running) == "function" then
			return state.watcher:running()
		end

		return false
	end)

	if running_ok == true and watcher_running == true then
		return true
	end

	local ok, started_watcher = pcall(function()
		if type(state.watcher.start) ~= "function" then
			return true
		end

		return state.watcher:start()
	end)

	if ok ~= true or started_watcher == false then
		log.e("failed to start pasteboard watcher")
		return false
	end

	return true
end

do
	local persisted_menu_history_size = hs.settings.get(menu_history_size_settings_key)

	if persisted_menu_history_size ~= nil then
		local normalized = normalize_menu_history_size(persisted_menu_history_size, nil)

		if normalized == nil then
			log.w("ignore invalid persisted menu history size: " .. tostring(persisted_menu_history_size))
			hs.settings.clear(menu_history_size_settings_key)
		else
			state.menu_history_size = normalized
			persist_menu_history_size()
		end
	end
end

function _M.start()
	if clipboard.enabled == false then
		log.i("clipboard center disabled by config")
		return true
	end

	if started == true then
		return true
	end

	image_cache_dir = resolve_cache_dir()

	if history_loaded ~= true then
		load_history()
		history_loaded = true
	end

	if state.chooser == nil then
		setup_chooser()
	end

	if state.hotkey == nil then
		if apply_hotkey_binding("startup") ~= true then
			destroy_chooser()
			return false
		end
	end

	refresh_menubar()

	if start_pasteboard_watcher() ~= true then
		destroy_menubar()
		delete_hotkey()
		destroy_chooser()
		return false
	end

	if startup_synchronized ~= true then
		sync_current_clipboard()
		startup_synchronized = true
	end

	started = true

	return true
end

function _M.stop()
	stop_preview_timer()
	hide_preview()
	destroy_preview_canvas()
	stop_pasteboard_watcher()
	destroy_menubar()
	delete_hotkey()
	destroy_chooser()
	state.suppressed_signature = nil
	state.suppressed_at = nil
	state.capture_suspended_until = nil
	history_loaded = false
	startup_synchronized = false
	started = false

	return true
end

_M.show_chooser = show_chooser
_M.clear_history = clear_history
_M.suspend_capture = suspend_capture

return _M
