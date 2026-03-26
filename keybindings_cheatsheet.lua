local _M = {}

_M.name = "keybindings_cheatsheet"
_M.description = "展示快捷键备忘列表"

local keybindings_cheatsheet = require("keybindings_config").keybindings_cheatsheet
local input_methods = require("keybindings_config").manual_input_methods
local system = require("keybindings_config").system
local clipboard = require("keybindings_config").clipboard or {}
local key_caster = require("keybindings_config").key_caster or {}
local websites = require("keybindings_config").websites
local apps = require("keybindings_config").apps

local window_position = require("keybindings_config").window_position
local window_movement = require("keybindings_config").window_movement
local window_resize = require("keybindings_config").window_resize
local window_monitor = require("keybindings_config").window_monitor
local window_batch = require("keybindings_config").window_batch
local hotkey_helper = require("hotkey_helper")

local utf8len = require("utils_lib").utf8len
local utf8sub = require("utils_lib").utf8sub
local trim = require("utils_lib").trim
local format_hotkey = hotkey_helper.format_hotkey
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers

-- 背景不透明度
local background_opacity = 0.8
-- 每行最大的长度
local max_line_length = 35
-- 每列的行数
local max_line_number = 20
-- 行距
local line_spacing = 5
-- 文本距离分割线的距离
local seperator_spacing = 6
-- 字体名称
local font_name = "Monaco"
-- 字体大小
local font_size = 15
-- 字体颜色
local font_color = "#c6c6c6"
-- 分割线颜色
local stroke_color = "#585858"
-- 分割线的宽度
local stroke_width = 1
-- 画布距离屏幕边缘的最小留白
local canvas_margin = 24

local log = hs.logger.new("cheatsheet")
local started = false
local hotkey_binding = nil

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
	return hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })
end

local canvas_width = 0
local canvas_height = 0

local canvas = nil

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

local function copy_list(items)
	local copied = {}

	for _, item in ipairs(items or {}) do
		table.insert(copied, item)
	end

	return copied
end

local function resolve_runtime_hotkey(default_modifiers, default_key, modifiers_settings_key, key_settings_key)
	local modifiers = copy_list(default_modifiers or {})
	local key = normalize_hotkey_key(default_key)

	if type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return modifiers, key
	end

	local persisted_modifiers = hs.settings.get(modifiers_settings_key)
	local persisted_key = hs.settings.get(key_settings_key)

	if persisted_modifiers == nil and persisted_key == nil then
		return modifiers, key
	end

	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(persisted_modifiers)

	if normalized_modifiers == nil then
		log.w("ignore invalid persisted cheatsheet hotkey modifier: " .. tostring(invalid_modifier))
		return modifiers, key
	end

	return normalized_modifiers, normalize_hotkey_key(persisted_key)
end

local function hotkey_line(modifiers, key, message)
	local normalized_key = normalize_hotkey_key(key)

	if normalized_key == nil then
		return nil
	end

	return string.format("%s: %s", format_hotkey(modifiers or {}, normalized_key), tostring(message or ""))
end

local function append_section_line(section, modifiers, key, message)
	local line = hotkey_line(modifiers, key, message)

	if line == nil then
		return
	end

	table.insert(section, { msg = line })
end

local function append_config_items(section, items)
	for _, item in ipairs(items or {}) do
		append_section_line(section, item.prefix, item.key, item.message)
	end
end

local function append_named_config_items(section, config_group, keys)
	for _, key in ipairs(keys or {}) do
		local item = config_group and config_group[key] or nil

		if item ~= nil then
			append_section_line(section, item.prefix, item.key, item.message)
		end
	end
end

local function createCanvas()
	local nextCanvas = hs.canvas.new({ x = 0, y = 0, w = 0, h = 0 })

	nextCanvas:appendElements({
		id = "pannel",
		action = "fill",
		fillColor = { alpha = background_opacity, red = 0, green = 0, blue = 0 },
		type = "rectangle",
	})

	return nextCanvas
end

local function styleText(text)
	return hs.styledtext.new(text, {
		font = {
			name = font_name,
			size = font_size,
		},
		color = { hex = font_color },
		paragraphStyle = {
			lineSpacing = line_spacing,
		},
	})
end

local function resolveTargetScreenFrame()
	local targetScreen = nil
	local focusedWindow = hs.window.focusedWindow()

	if focusedWindow ~= nil then
		targetScreen = focusedWindow:screen()
	end

	if targetScreen == nil then
		targetScreen = hs.screen.mainScreen()
	end

	if targetScreen == nil then
		return nil
	end

	return targetScreen:frame()
end

local function positionCanvas()
	if canvas == nil then
		return
	end

	local screen = resolveTargetScreenFrame()

	if screen == nil then
		return
	end

	local max_width = math.max(0, screen.w - (canvas_margin * 2))
	local max_height = math.max(0, screen.h - (canvas_margin * 2))
	local frame_width = math.min(canvas_width, max_width)
	local frame_height = math.min(canvas_height, max_height)
	local x = screen.x + math.max(canvas_margin, math.floor((screen.w - frame_width) / 2))
	local y = screen.y + math.max(canvas_margin, math.floor((screen.h - frame_height) / 2))

	canvas:frame({
		x = x,
		y = y,
		w = frame_width,
		h = frame_height,
	})
end

local function formatText()
	local renderText = {}

	local keybindingsCheatsheet = {}
	table.insert(keybindingsCheatsheet, { msg = "[Cheatsheet]" })
	append_section_line(
		keybindingsCheatsheet,
		keybindings_cheatsheet.prefix,
		keybindings_cheatsheet.key,
		keybindings_cheatsheet.message
	)

	local inputMethods = {}
	table.insert(inputMethods, { msg = "[Input Methods]" })
	append_config_items(inputMethods, input_methods)

	local systemManagement = {}
	table.insert(systemManagement, { msg = "[System Management]" })
	do
		local keep_awake_modifiers, keep_awake_key = resolve_runtime_hotkey(
			system.keep_awake.prefix,
			system.keep_awake.key,
			"keep_awake.hotkey.modifiers",
			"keep_awake.hotkey.key"
		)
		append_section_line(
			systemManagement,
			keep_awake_modifiers,
			keep_awake_key,
			system.keep_awake.message
		)
	end
	append_named_config_items(systemManagement, system, {
		"lock_screen",
		"screen_saver",
		"restart",
		"shutdown",
	})

	local clipboardCenter = {}
	table.insert(clipboardCenter, { msg = "[Clipboard Center]" })
	if clipboard.enabled ~= false then
		local clipboard_modifiers, clipboard_key = resolve_runtime_hotkey(
			clipboard.prefix,
			clipboard.key,
			"clipboard_center.hotkey.modifiers",
			"clipboard_center.hotkey.key"
		)
		append_section_line(clipboardCenter, clipboard_modifiers, clipboard_key, clipboard.message)
	end

	local keyCaster = {}
	table.insert(keyCaster, { msg = "[Key Caster]" })
	do
		local toggle_hotkey = key_caster.toggle_hotkey or {}
		append_section_line(
			keyCaster,
			toggle_hotkey.prefix,
			toggle_hotkey.key,
			toggle_hotkey.message or "Toggle Key Caster"
		)
	end

	local WebsiteOpen = {}
	table.insert(WebsiteOpen, { msg = "[Website Open]" })
	append_config_items(WebsiteOpen, websites)

	local applicationLaunch = {}
	table.insert(applicationLaunch, { msg = "[App Launch Or Hide]" })
	append_config_items(applicationLaunch, apps)

	local windowPosition = {}
	table.insert(windowPosition, { msg = "[Window Position]" })
	append_named_config_items(windowPosition, window_position, {
		"center",
		"left",
		"right",
		"up",
		"down",
		"top_left",
		"top_right",
		"bottom_left",
		"bottom_right",
		"left_1_3",
		"right_1_3",
		"left_2_3",
		"right_2_3",
	})

	local windowMovement = {}
	table.insert(windowMovement, { msg = "[Window Movement]" })
	append_named_config_items(windowMovement, window_movement, {
		"to_up",
		"to_down",
		"to_left",
		"to_right",
	})

	local windowResize = {}
	table.insert(windowResize, { msg = "[Window Resize]" })
	append_named_config_items(windowResize, window_resize, {
		"max",
		"stretch",
		"shrink",
		"stretch_up",
		"stretch_down",
		"stretch_left",
		"stretch_right",
	})

	local windowMonitor = {}
	table.insert(windowMonitor, { msg = "[Window Monitor]" })
	append_named_config_items(windowMonitor, window_monitor, {
		"to_above_screen",
		"to_below_screen",
		"to_left_screen",
		"to_right_screen",
		"to_next_screen",
	})

	local windowBatch = {}
	table.insert(windowBatch, { msg = "[Window Batch]" })
	append_named_config_items(windowBatch, window_batch, {
		"minimize_all_windows",
		"un_minimize_all_windows",
		"close_all_windows",
	})

	local hotkeys = {}

	for _, v in ipairs(keybindingsCheatsheet) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(inputMethods) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(systemManagement) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(clipboardCenter) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(keyCaster) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(WebsiteOpen) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(applicationLaunch) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(windowPosition) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(windowMovement) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(windowResize) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(windowMonitor) do
		table.insert(hotkeys, { msg = v.msg })
	end

	table.insert(hotkeys, { msg = "" })

	for _, v in ipairs(windowBatch) do
		table.insert(hotkeys, { msg = v.msg })
	end

	-- 文本定长
	for _, v in ipairs(hotkeys) do
		local msg = v.msg
		local len = utf8len(msg)

		-- 超过最大长度, 截断多余部分, 截断的部分作为新的一行.
		while len > max_line_length do
			local substr = utf8sub(msg, 1, max_line_length)
			table.insert(renderText, { line = substr })

			msg = utf8sub(msg, max_line_length + 1, len)
			len = utf8len(msg)
		end

		for _ = 1, max_line_length - utf8len(msg), 1 do
			msg = msg .. " "
		end

		table.insert(renderText, { line = msg })
	end

	return renderText
end

local function build_columns(renderText, line_limit)
	local columns = {}
	local current_lines = {}

	for index, entry in ipairs(renderText) do
		table.insert(current_lines, entry.line)

		if index % line_limit == 0 then
			table.insert(columns, table.concat(current_lines, "  \n") .. "  ")
			current_lines = {}
		end
	end

	if #current_lines > 0 then
		table.insert(columns, table.concat(current_lines, "  \n") .. "  ")
	end

	return columns
end

local function measure_columns(columns)
	local measured = {}
	local total_width = 0
	local max_height = 0

	for index, column in ipairs(columns) do
		local itemText = styleText(column)
		local size = canvas:minimumTextSize(itemText)

		table.insert(measured, {
			text = itemText,
			size = size,
		})

		total_width = total_width + size.w + (seperator_spacing * 2)
		max_height = math.max(max_height, size.h)

		if index < #columns then
			total_width = total_width + seperator_spacing
		end
	end

	return measured, total_width, max_height
end

local function resolve_columns_for_screen(renderText)
	local screen = resolveTargetScreenFrame()
	local available_width = math.huge
	local best_columns = nil
	local best_measured = nil
	local best_width = nil
	local best_height = nil
	local initial_line_limit = math.max(1, math.min(max_line_number, #renderText))

	if screen ~= nil then
		available_width = math.max(0, screen.w - (canvas_margin * 2))
	end

	for line_limit = initial_line_limit, math.max(initial_line_limit, #renderText) do
		local columns = build_columns(renderText, line_limit)
		local measured, width, height = measure_columns(columns)

		best_columns = columns
		best_measured = measured
		best_width = width
		best_height = height

		if width <= available_width then
			break
		end
	end

	return best_columns or {}, best_measured or {}, best_width or 0, best_height or 0
end

local function drawText(renderText)
	local max_right = 0
	local x_offset = 0
	local columns, measured_columns, measured_width, measured_height = resolve_columns_for_screen(renderText)

	for index, _ in ipairs(columns) do
		local measured = measured_columns[index]
		local text_frame = {
			x = x_offset + seperator_spacing,
			y = 0,
			w = measured.size.w,
			h = measured.size.h,
		}

		canvas:appendElements({
			type = "text",
			text = measured.text,
			frame = text_frame,
		})

		max_right = math.max(max_right, text_frame.x + text_frame.w + seperator_spacing)
		x_offset = text_frame.x + text_frame.w + seperator_spacing

		if index < #columns then
			canvas:appendElements({
				type = "segments",
				closed = false,
				strokeColor = { hex = stroke_color },
				action = "stroke",
				strokeWidth = stroke_width,
				coordinates = {
					{ x = x_offset, y = 0 },
					{ x = x_offset, y = text_frame.h },
				},
			})

			max_right = math.max(max_right, x_offset + seperator_spacing)
			x_offset = x_offset + seperator_spacing
		end
	end

	canvas_width = math.max(max_right, measured_width)
	canvas_height = measured_height
	positionCanvas()
end

local function rebuildCanvas()
	local renderText = formatText()

	if canvas ~= nil then
		canvas:hide(0)
		canvas:delete()
	end

	canvas_width = 0
	canvas_height = 0
	canvas = createCanvas()
	drawText(renderText)
end

local function destroyCanvas()
	if canvas == nil then
		return
	end

	canvas:hide(0)
	canvas:delete()
	canvas = nil
	canvas_width = 0
	canvas_height = 0
end

-- 默认不显示
local show = false
local function toggleKeybindingsCheatsheet()
	if show then
		-- 0.3s 过渡
		if canvas ~= nil then
			canvas:hide(0.3)
		end
	else
		rebuildCanvas()
		positionCanvas()
		canvas:show(0.3)
	end

	show = not show
end

function _M.start()
	if started == true then
		return true
	end

	hotkey_binding =
		bind(keybindings_cheatsheet.prefix, keybindings_cheatsheet.key, keybindings_cheatsheet.message, toggleKeybindingsCheatsheet)
	started = hotkey_binding ~= nil

	return started
end

function _M.stop()
	if hotkey_binding ~= nil then
		hotkey_binding:delete()
		hotkey_binding = nil
	end

	destroyCanvas()
	show = false
	started = false

	return true
end

return _M
