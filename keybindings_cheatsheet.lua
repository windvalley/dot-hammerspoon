local _M = {}

_M.name = "keybindings_cheatsheet"
_M.description = "展示快捷键备忘列表"

local keybindings_cheatsheet = require("keybindings_config").keybindings_cheatsheet
local input_methods = require("keybindings_config").manual_input_methods
local system = require("keybindings_config").system
local clipboard = require("keybindings_config").clipboard or {}
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

	canvas:frame({
		x = screen.x + (screen.w - canvas_width) / 2,
		y = screen.y + (screen.h - canvas_height) / 2,
		w = canvas_width,
		h = canvas_height,
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
	append_config_items(systemManagement, {
		system.lock_screen,
		system.screen_saver,
		system.restart,
		system.shutdown,
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

	local WebsiteOpen = {}
	table.insert(WebsiteOpen, { msg = "[Website Open]" })
	append_config_items(WebsiteOpen, websites)

	local applicationLaunch = {}
	table.insert(applicationLaunch, { msg = "[App Launch Or Hide]" })
	append_config_items(applicationLaunch, apps)

	local windowPosition = {}
	table.insert(windowPosition, { msg = "[Window Position]" })
	append_config_items(windowPosition, {
		window_position.center,
		window_position.left,
		window_position.right,
		window_position.up,
		window_position.down,
		window_position.top_left,
		window_position.top_right,
		window_position.bottom_left,
		window_position.bottom_right,
		window_position.left_1_3,
		window_position.right_1_3,
		window_position.left_2_3,
		window_position.right_2_3,
	})

	local windowMovement = {}
	table.insert(windowMovement, { msg = "[Window Movement]" })
	append_config_items(windowMovement, {
		window_movement.to_up,
		window_movement.to_down,
		window_movement.to_left,
		window_movement.to_right,
	})

	local windowResize = {}
	table.insert(windowResize, { msg = "[Window Resize]" })
	append_config_items(windowResize, {
		window_resize.max,
		window_resize.stretch,
		window_resize.shrink,
		window_resize.stretch_up,
		window_resize.stretch_down,
		window_resize.stretch_left,
		window_resize.stretch_right,
	})

	local windowMonitor = {}
	table.insert(windowMonitor, { msg = "[Window Monitor]" })
	append_config_items(windowMonitor, {
		window_monitor.to_above_screen,
		window_monitor.to_below_screen,
		window_monitor.to_left_screen,
		window_monitor.to_right_screen,
		window_monitor.to_next_screen,
	})

	local windowBatch = {}
	table.insert(windowBatch, { msg = "[Window Batch]" })
	append_config_items(windowBatch, {
		window_batch.minimize_all_windows,
		window_batch.un_minimize_all_windows,
		window_batch.close_all_windows,
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

local function drawText(renderText)
	local w = 0
	local h = 0
	local totalLines = #renderText

	-- 每一列需要显示的文本
	local column = ""

	for k, v in ipairs(renderText) do
		local line = v.line
		if math.fmod(k, max_line_number) == 0 then
			column = column .. line .. "  "
		else
			column = column .. line .. "  \n"
		end

		-- k mod max_line_number
		if math.fmod(k, max_line_number) == 0 then
			local itemText = styleText(column)
			local size = canvas:minimumTextSize(itemText)

			w = w + size.w
			if k == max_line_number then
				h = size.h
			end

			canvas:appendElements({
				type = "text",
				text = itemText,
				frame = {
					x = (k / max_line_number - 1) * size.w + seperator_spacing,
					y = 0,
					w = size.w + seperator_spacing,
					h = size.h,
				},
			})

			canvas:appendElements({
				type = "segments",
				closed = false,
				strokeColor = { hex = stroke_color },
				action = "stroke",
				strokeWidth = stroke_width,
				coordinates = {
					{ x = (k / max_line_number) * size.w - seperator_spacing, y = 0 },
					{ x = (k / max_line_number) * size.w - seperator_spacing, y = h },
				},
			})

			column = ""
		end
	end

	if column ~= "" then
		local itemText = styleText(column)
		local size = canvas:minimumTextSize(itemText)

		w = w + size.w

		canvas:appendElements({
			type = "text",
			text = itemText,
			frame = {
				x = math.ceil(totalLines / max_line_number - 1) * size.w + seperator_spacing,
				y = 0,
				w = size.w + seperator_spacing,
				h = size.h,
			},
		})
	end

	canvas_width = w
	canvas_height = h
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

	rebuildCanvas()
	hotkey_binding =
		bind(keybindings_cheatsheet.prefix, keybindings_cheatsheet.key, keybindings_cheatsheet.message, toggleKeybindingsCheatsheet)
	started = true

	return true
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
