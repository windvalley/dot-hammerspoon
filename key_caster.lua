local _M = {}

_M.name = "key_caster"
_M.description = "录屏/演示场景下的按键可视化，并提供轻量运行时控制"

local key_caster = require("keybindings_config").key_caster or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local shallow_copy = utils_lib.shallow_copy
local copy_list = utils_lib.copy_list
local trim = utils_lib.trim
local prompt_text = utils_lib.prompt_text
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers
local format_hotkey = hotkey_helper.format_hotkey

local log = hs.logger.new("keycast")

local default_position = {
	anchor = "bottom_center",
	offset_x = 0,
	offset_y = 140,
}
local default_font = {
	name = "Menlo Bold",
	size = 44,
}
local default_text_color = {
	hex = "#F8FAFC",
	alpha = 1,
}
local default_background_color = {
	hex = "#111827",
	alpha = 0.78,
}
local default_display_mode = "single"
local default_toggle_hotkey = {
	prefix = { "Command", "Ctrl" },
	key = "K",
	message = "Toggle Key Caster",
}
local default_sequence_window_seconds = 0.4
local settings_key = "key_caster.runtime_overrides"
local menubar_autosave_name = "dot-hammerspoon.key_caster"
local valid_anchors = {
	top_left = true,
	top_center = true,
	top_right = true,
	center = true,
	bottom_left = true,
	bottom_center = true,
	bottom_right = true,
}
local valid_menubar_modes = {
	auto = true,
	always = true,
	never = true,
}
local valid_display_modes = {
	single = true,
	sequence = true,
}
local anchor_labels = {
	top_left = "顶部左侧",
	top_center = "顶部居中",
	top_right = "顶部右侧",
	center = "屏幕中央",
	bottom_left = "底部左侧",
	bottom_center = "底部居中",
	bottom_right = "底部右侧",
}
local modifier_order = {
	ctrl = 1,
	alt = 2,
	cmd = 3,
	shift = 4,
	fn = 5,
}
local modifier_symbols = {
	ctrl = "⌃",
	alt = "⌥",
	cmd = "⌘",
	shift = "⇧",
	fn = "fn",
}
local modifier_key_aliases = {
	command = "cmd",
	cmd = "cmd",
	rightcommand = "cmd",
	rightcmd = "cmd",
	option = "alt",
	alt = "alt",
	rightoption = "alt",
	rightalt = "alt",
	control = "ctrl",
	ctrl = "ctrl",
	rightcontrol = "ctrl",
	rightctrl = "ctrl",
	shift = "shift",
	rightshift = "shift",
	fn = "fn",
}
local special_key_labels = {
	space = "Space",
	tab = "Tab",
	["return"] = "Return",
	enter = "Enter",
	padenter = "Enter",
	delete = "Delete",
	forwarddelete = "Forward Delete",
	escape = "Esc",
	help = "Help",
	home = "Home",
	endd = "End",
	pageup = "Page Up",
	pagedown = "Page Down",
	up = "Up",
	down = "Down",
	left = "Left",
	right = "Right",
}

local started = false
local measurement_canvas = nil
local display_canvas = nil
local hide_timer = nil
local event_tap = nil
local menubar_item = nil
local hotkey_binding = nil
local break_reminder_refresh_timer = nil
local sequence_text = nil
local sequence_last_event_at = nil
local current_overlay_text = nil
local state = nil
local tooltip_text
local build_menu
local menubar_should_be_visible
local refresh_menubar
local set_menubar_mode
local set_display_mode

local function resolve_number(value, default_value, minimum_value)
	local number = tonumber(value)

	if number == nil then
		number = default_value
	end

	return math.max(minimum_value, number)
end

local function normalize_anchor(anchor)
	local normalized = tostring(anchor or default_position.anchor):lower()

	if valid_anchors[normalized] ~= true then
		log.w("invalid key caster anchor: " .. normalized .. ", fallback to bottom_center")
		return default_position.anchor
	end

	return normalized
end

local function normalize_color(color_config, fallback)
	local color = shallow_copy(fallback)

	if type(color_config) ~= "table" then
		return color
	end

	for key, value in pairs(color_config) do
		color[key] = value
	end

	return color
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

local function normalize_menubar_mode(value)
	if value == nil then
		return "auto"
	end

	if value == true then
		return "always"
	end

	if value == false then
		return "never"
	end

	local normalized = string.lower(trim(tostring(value)))

	if normalized == "true" or normalized == "yes" or normalized == "on" then
		return "always"
	end

	if normalized == "false" or normalized == "no" or normalized == "off" then
		return "never"
	end

	if valid_menubar_modes[normalized] == true then
		return normalized
	end

	log.w("invalid key caster show_menubar value: " .. tostring(value) .. ", fallback to auto")

	return "auto"
end

local function normalize_display_mode(value)
	if value == nil then
		return default_display_mode
	end

	local normalized = string.lower(trim(tostring(value)))

	if valid_display_modes[normalized] == true then
		return normalized
	end

	log.w("invalid key caster display_mode value: " .. tostring(value) .. ", fallback to single")

	return default_display_mode
end

local function normalize_config(config)
	local position = type(config.position) == "table" and config.position or {}
	local font = type(config.font) == "table" and config.font or {}
	local toggle_hotkey = type(config.toggle_hotkey) == "table" and config.toggle_hotkey or {}
	local hotkey_modifiers, invalid_modifier =
		normalize_hotkey_modifiers(toggle_hotkey.prefix or default_toggle_hotkey.prefix)

	if hotkey_modifiers == nil then
		log.w("invalid key caster hotkey modifier: " .. tostring(invalid_modifier) .. ", fallback to default")
		hotkey_modifiers = normalize_hotkey_modifiers(default_toggle_hotkey.prefix) or {}
	end

	return {
		enabled = config.enabled == true,
		menubar_mode = normalize_menubar_mode(config.show_menubar),
		position = {
			anchor = normalize_anchor(position.anchor),
			offset_x = math.floor(tonumber(position.offset_x) or default_position.offset_x),
			offset_y = math.floor(tonumber(position.offset_y) or default_position.offset_y),
		},
		font = {
			name = tostring(font.name or default_font.name),
			size = resolve_number(font.size, default_font.size, 12),
		},
		text_color = normalize_color(config.text_color, default_text_color),
		background_color = normalize_color(config.background_color, default_background_color),
		duration_seconds = resolve_number(config.duration_seconds, 1.2, 0.1),
		display_mode = normalize_display_mode(config.display_mode),
		sequence_window_seconds = resolve_number(
			config.sequence_window_seconds,
			default_sequence_window_seconds,
			0.05
		),
		padding_x = resolve_number(config.padding_x, 24, 0),
		padding_y = resolve_number(config.padding_y, 12, 0),
		corner_radius = resolve_number(config.corner_radius, 14, 0),
		min_width = resolve_number(config.min_width, 108, 0),
		hotkey_modifiers = copy_list(hotkey_modifiers),
		hotkey_key = normalize_hotkey_key(toggle_hotkey.key == nil and default_toggle_hotkey.key or toggle_hotkey.key),
		hotkey_message = tostring(toggle_hotkey.message or default_toggle_hotkey.message),
	}
end

local configured_defaults = normalize_config(key_caster)
local runtime_overrides = {}

local function table_is_empty(table_value)
	return next(table_value or {}) == nil
end

local function merged_config(overrides)
	local config = shallow_copy(key_caster)

	for key, value in pairs(overrides or {}) do
		if type(value) == "table" and type(config[key]) == "table" then
			local nested = shallow_copy(config[key])

			for nested_key, nested_value in pairs(value) do
				nested[nested_key] = nested_value
			end

			config[key] = nested
		else
			config[key] = value
		end
	end

	return config
end

local function sanitize_runtime_overrides(overrides)
	local sanitized = {}

	if type(overrides) ~= "table" then
		return sanitized
	end

	if type(overrides.show_menubar) == "boolean" or type(overrides.show_menubar) == "string" then
		sanitized.show_menubar = overrides.show_menubar
	end

	if type(overrides.display_mode) == "string" then
		sanitized.display_mode = overrides.display_mode
	end

	if tonumber(overrides.duration_seconds) ~= nil then
		sanitized.duration_seconds = tonumber(overrides.duration_seconds)
	end

	if type(overrides.position) == "table" then
		local position = {}

		if overrides.position.anchor ~= nil then
			position.anchor = tostring(overrides.position.anchor)
		end

		if tonumber(overrides.position.offset_x) ~= nil then
			position.offset_x = math.floor(tonumber(overrides.position.offset_x))
		end

		if tonumber(overrides.position.offset_y) ~= nil then
			position.offset_y = math.floor(tonumber(overrides.position.offset_y))
		end

		if table_is_empty(position) ~= true then
			sanitized.position = position
		end
	end

	if type(overrides.font) == "table" then
		local font = {}

		if tonumber(overrides.font.size) ~= nil then
			font.size = math.floor(tonumber(overrides.font.size))
		end

		if table_is_empty(font) ~= true then
			sanitized.font = font
		end
	end

	return sanitized
end

local function persist_runtime_overrides()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" then
		return
	end

	if table_is_empty(runtime_overrides) then
		if type(hs.settings.clear) == "function" then
			hs.settings.clear(settings_key)
		end

		return
	end

	if type(hs.settings.set) == "function" then
		hs.settings.set(settings_key, runtime_overrides)
	end
end

local function load_runtime_overrides()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return {}
	end

	local saved = hs.settings.get(settings_key)

	if type(saved) ~= "table" then
		return {}
	end

	local sanitized = sanitize_runtime_overrides(saved)

	if type(hs.settings.clear) == "function" and table_is_empty(sanitized) == true then
		hs.settings.clear(settings_key)
	elseif type(hs.settings.set) == "function" then
		hs.settings.set(settings_key, sanitized)
	end

	return sanitized
end

local function sync_runtime_overrides_with_state()
	if state == nil then
		return
	end

	if state.menubar_mode == configured_defaults.menubar_mode then
		runtime_overrides.show_menubar = nil
	else
		runtime_overrides.show_menubar = state.menubar_mode
	end

	if state.display_mode == configured_defaults.display_mode then
		runtime_overrides.display_mode = nil
	else
		runtime_overrides.display_mode = state.display_mode
	end

	if math.abs(state.duration_seconds - configured_defaults.duration_seconds) < 0.001 then
		runtime_overrides.duration_seconds = nil
	else
		runtime_overrides.duration_seconds = state.duration_seconds
	end

	local position_overrides = {}

	if state.position.anchor ~= configured_defaults.position.anchor then
		position_overrides.anchor = state.position.anchor
	end

	if state.position.offset_x ~= configured_defaults.position.offset_x then
		position_overrides.offset_x = state.position.offset_x
	end

	if state.position.offset_y ~= configured_defaults.position.offset_y then
		position_overrides.offset_y = state.position.offset_y
	end

	runtime_overrides.position = table_is_empty(position_overrides) == true and nil or position_overrides

	local font_overrides = {}

	if math.floor(state.font.size) ~= math.floor(configured_defaults.font.size) then
		font_overrides.size = math.floor(state.font.size)
	end

	runtime_overrides.font = table_is_empty(font_overrides) == true and nil or font_overrides

	persist_runtime_overrides()
end

runtime_overrides = load_runtime_overrides()

local function stop_hide_timer()
	if hide_timer == nil then
		return
	end

	hide_timer:stop()
	hide_timer = nil
end

local function reset_sequence_buffer()
	sequence_text = nil
	sequence_last_event_at = nil
end

local function destroy_display_canvas()
	if display_canvas == nil then
		return
	end

	display_canvas:delete()
	display_canvas = nil
end

local function destroy_measurement_canvas()
	if measurement_canvas == nil then
		return
	end

	measurement_canvas:delete()
	measurement_canvas = nil
end

local function stop_break_reminder_refresh_timer()
	if break_reminder_refresh_timer == nil then
		return
	end

	break_reminder_refresh_timer:stop()
	break_reminder_refresh_timer = nil
end

local function run_break_reminder_menubar_refresh()
	local break_reminder = package.loaded.break_reminder

	if type(break_reminder) ~= "table" or type(break_reminder.refresh_menubar) ~= "function" then
		return
	end

	local ok, err = pcall(function()
		break_reminder.refresh_menubar(true)
	end)

	if ok ~= true then
		log.w("failed to refresh break reminder menubar: " .. tostring(err))
	end
end

local function schedule_break_reminder_menubar_refresh()
	run_break_reminder_menubar_refresh()
	stop_break_reminder_refresh_timer()

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		return
	end

	break_reminder_refresh_timer = hs.timer.doAfter(0, function()
		break_reminder_refresh_timer = nil
		run_break_reminder_menubar_refresh()
	end)
end

local function destroy_menubar()
	if menubar_item == nil then
		return
	end

	menubar_item:delete()
	menubar_item = nil
	schedule_break_reminder_menubar_refresh()
end

local function apply_menubar_content()
	if menubar_item == nil then
		return
	end

	if type(menubar_item.autosaveName) == "function" then
		pcall(function()
			menubar_item:autosaveName(menubar_autosave_name)
		end)
	end

	menubar_item:setMenu(build_menu)
	if type(menubar_item.setIcon) == "function" then
		menubar_item:setIcon(nil)
	end
	menubar_item:setTitle("KC")

	menubar_item:setTooltip(tooltip_text())
end

local function ensure_visible_menubar()
	if menubar_item ~= nil then
		return true
	end

	menubar_item = hs.menubar.new(true, menubar_autosave_name)

	if menubar_item == nil then
		log.e("failed to create visible key caster menubar item")
		return false
	end

	schedule_break_reminder_menubar_refresh()

	return true
end

local function delete_hotkey_binding()
	if hotkey_binding == nil then
		return
	end

	hotkey_binding:delete()
	hotkey_binding = nil
end

local function build_text_style()
	if type(hs.styledtext) ~= "table" or type(hs.styledtext.new) ~= "function" then
		return nil
	end

	return {
		font = {
			name = state.font.name,
			size = state.font.size,
		},
		color = state.text_color,
	}
end

local function build_styled_text(text)
	local style = build_text_style()

	if style == nil then
		return text
	end

	return hs.styledtext.new(text, style)
end

local function current_monotonic_seconds()
	if type(hs.timer) == "table" and type(hs.timer.absoluteTime) == "function" then
		return hs.timer.absoluteTime() / 1000000000
	end

	return os.clock()
end

local function anchor_label(anchor)
	return anchor_labels[anchor] or tostring(anchor or "")
end

local function format_duration_label(seconds)
	if math.abs(seconds - math.floor(seconds)) < 0.001 then
		return string.format("%d 秒", math.floor(seconds))
	end

	return string.format("%.1f 秒", seconds)
end

local function position_summary_label()
	return string.format(
		"%s | X %+d | Y %+d",
		anchor_label(state.position.anchor),
		state.position.offset_x,
		state.position.offset_y
	)
end

local function font_size_summary_label()
	return string.format("%d pt", math.floor(state.font.size))
end

local function prompt_number(message, informative_text, default_value, minimum_value, maximum_value, options)
	options = options or {}

	if type(prompt_text) ~= "function" then
		hs.alert.show("当前环境不支持输入自定义数值")
		return nil
	end

	local raw_value = prompt_text(message, informative_text, tostring(default_value or ""))

	if raw_value == nil then
		return nil
	end

	local number = tonumber(trim(raw_value))

	if number == nil then
		hs.alert.show("请输入有效数字")
		return nil
	end

	if minimum_value ~= nil and number < minimum_value then
		hs.alert.show(string.format("请输入不小于 %s 的数值", tostring(minimum_value)))
		return nil
	end

	if maximum_value ~= nil and number > maximum_value then
		hs.alert.show(string.format("请输入不大于 %s 的数值", tostring(maximum_value)))
		return nil
	end

	if options.integer == true then
		if math.abs(number - math.floor(number)) > 0.000001 then
			hs.alert.show("请输入整数")
			return nil
		end

		number = math.floor(number)
	end

	return number
end

local function measure_text(text)
	local styled_text = build_styled_text(text)

	if measurement_canvas ~= nil and type(measurement_canvas.minimumTextSize) == "function" then
		local size = measurement_canvas:minimumTextSize(styled_text)

		if type(size) == "table" and tonumber(size.w) ~= nil and tonumber(size.h) ~= nil then
			return math.ceil(size.w), math.ceil(size.h), styled_text
		end
	end

	local fallback_width = math.ceil(#tostring(text or "") * state.font.size * 0.65)
	local fallback_height = math.ceil(state.font.size * 1.35)

	return fallback_width, fallback_height, styled_text
end

local function resolve_target_screen_frame()
	if type(hs.window) == "table" and type(hs.window.focusedWindow) == "function" then
		local focused_window = hs.window.focusedWindow()

		if focused_window ~= nil and type(focused_window.screen) == "function" then
			local screen = focused_window:screen()

			if screen ~= nil and type(screen.frame) == "function" then
				return screen:frame()
			end
		end
	end

	if type(hs.screen) == "table" and type(hs.screen.mainScreen) == "function" then
		local screen = hs.screen.mainScreen()

		if screen ~= nil and type(screen.frame) == "function" then
			return screen:frame()
		end
	end

	return nil
end

local function resolve_canvas_frame(width, height)
	local screen = resolve_target_screen_frame()

	if screen == nil then
		return nil
	end

	local anchor = state.position.anchor
	local x = screen.x + state.position.offset_x
	local y = screen.y + state.position.offset_y

	if anchor == "top_center" then
		x = screen.x + ((screen.w - width) / 2) + state.position.offset_x
	elseif anchor == "top_right" then
		x = screen.x + screen.w - width - state.position.offset_x
	elseif anchor == "center" then
		x = screen.x + ((screen.w - width) / 2) + state.position.offset_x
		y = screen.y + ((screen.h - height) / 2) + state.position.offset_y
	elseif anchor == "bottom_left" then
		y = screen.y + screen.h - height - state.position.offset_y
	elseif anchor == "bottom_center" then
		x = screen.x + ((screen.w - width) / 2) + state.position.offset_x
		y = screen.y + screen.h - height - state.position.offset_y
	elseif anchor == "bottom_right" then
		x = screen.x + screen.w - width - state.position.offset_x
		y = screen.y + screen.h - height - state.position.offset_y
	end

	return {
		x = math.floor(x),
		y = math.floor(y),
		w = math.ceil(width),
		h = math.ceil(height),
	}
end

local function sorted_pressed_modifiers(flags)
	local modifiers = {}

	for name in pairs(modifier_symbols) do
		if type(flags) == "table" and flags[name] == true then
			table.insert(modifiers, name)
		end
	end

	table.sort(modifiers, function(left, right)
		return modifier_order[left] < modifier_order[right]
	end)

	return modifiers
end

local function normalize_key_name(key_name)
	if key_name == nil then
		return nil
	end

	local normalized = tostring(key_name):lower()

	if normalized == "" then
		return nil
	end

	if normalized == "end" then
		normalized = "endd"
	end

	return normalized
end

local function format_key_label(key_name)
	local normalized = normalize_key_name(key_name)

	if normalized == nil then
		return nil
	end

	if special_key_labels[normalized] ~= nil then
		return special_key_labels[normalized]
	end

	if #normalized == 1 then
		return string.upper(normalized)
	end

	if normalized:match("^f%d+$") ~= nil then
		return string.upper(normalized)
	end

	return normalized:gsub("^%l", string.upper)
end

local function format_key_combo(flags, key_name)
	local parts = {}

	for _, modifier in ipairs(sorted_pressed_modifiers(flags)) do
		table.insert(parts, modifier_symbols[modifier])
	end

	local key_label = format_key_label(key_name)

	if key_label ~= nil then
		table.insert(parts, key_label)
	end

	if #parts == 0 then
		return nil
	end

	return table.concat(parts, " ")
end

local function key_name_from_event(event)
	if event == nil or type(event.getKeyCode) ~= "function" then
		return nil
	end

	local key_code = event:getKeyCode()

	if type(hs.keycodes) ~= "table" or type(hs.keycodes.map) ~= "table" then
		return tostring(key_code)
	end

	return hs.keycodes.map[key_code] or tostring(key_code)
end

local function modifier_display_text(event)
	local key_name = normalize_key_name(key_name_from_event(event))
	local canonical_modifier = modifier_key_aliases[key_name or ""]
	local flags = type(event.getFlags) == "function" and event:getFlags() or {}

	if canonical_modifier == nil or flags[canonical_modifier] ~= true then
		return nil
	end

	return format_key_combo(flags, nil)
end

local function plain_letter_text(flags, key_name)
	local normalized = normalize_key_name(key_name)

	if normalized == nil or normalized:match("^%a$") == nil then
		return nil
	end

	flags = type(flags) == "table" and flags or {}

	if flags.cmd == true or flags.ctrl == true or flags.alt == true or flags.fn == true then
		return nil
	end

	return format_key_label(normalized)
end

local function next_keydown_overlay_text(event)
	local flags = type(event.getFlags) == "function" and event:getFlags() or {}
	local key_name = key_name_from_event(event)
	local letter_text = nil

	if state.display_mode == "sequence" then
		letter_text = plain_letter_text(flags, key_name)
	end

	if letter_text == nil then
		reset_sequence_buffer()
		return format_key_combo(flags, key_name)
	end

	local now = current_monotonic_seconds()

	if
		sequence_text ~= nil
		and sequence_last_event_at ~= nil
		and (now - sequence_last_event_at) <= state.sequence_window_seconds
	then
		sequence_text = sequence_text .. letter_text
	else
		sequence_text = letter_text
	end

	sequence_last_event_at = now

	return sequence_text
end

local function render_overlay_text(text)
	if text == nil then
		return
	end

	current_overlay_text = text

	local text_width, text_height, styled_text = measure_text(text)
	local width = math.max(state.min_width, text_width + (state.padding_x * 2))
	local height = text_height + (state.padding_y * 2)
	local frame = resolve_canvas_frame(width, height)

	if frame == nil then
		return
	end

	stop_hide_timer()
	destroy_display_canvas()

	display_canvas = hs.canvas.new(frame)

	if display_canvas == nil then
		return
	end

	if type(hs.canvas) == "table" and type(hs.canvas.windowLevels) == "table" and hs.canvas.windowLevels.overlay ~= nil then
		display_canvas:level(hs.canvas.windowLevels.overlay)
	end

	display_canvas:appendElements({
		type = "rectangle",
		action = "fill",
		frame = {
			x = 0,
			y = 0,
			w = width,
			h = height,
		},
		roundedRectRadii = {
			xRadius = state.corner_radius,
			yRadius = state.corner_radius,
		},
		fillColor = state.background_color,
	}, {
		type = "text",
		text = styled_text,
		frame = {
			x = state.padding_x,
			y = state.padding_y,
			w = width - (state.padding_x * 2),
			h = height - (state.padding_y * 2),
		},
	})

	if type(display_canvas.show) == "function" then
		display_canvas:show()
	end

	hide_timer = hs.timer.doAfter(state.duration_seconds, function()
		hide_timer = nil
		destroy_display_canvas()
		current_overlay_text = nil
	end)
end

local function refresh_current_overlay()
	if current_overlay_text == nil then
		return
	end

	render_overlay_text(current_overlay_text)
end

local function restore_persisted_menu_configuration()
	local enabled = state ~= nil and state.enabled == true

	runtime_overrides = {}
	persist_runtime_overrides()
	state = normalize_config(merged_config(runtime_overrides))
	state.enabled = enabled
	reset_sequence_buffer()
	refresh_menubar()
	refresh_current_overlay()
end

local function confirm_restore_defaults()
	if table_is_empty(runtime_overrides) == true then
		return false
	end

	local button = "恢复默认"

	if type(hs.dialog) == "table" and type(hs.dialog.blockAlert) == "function" then
		button = hs.dialog.blockAlert(
			"恢复默认",
			"这会清除当前通过菜单栏保存的 Key Caster 配置，并恢复为 keybindings_config.lua 中定义的默认值。是否继续？",
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

local function set_position_anchor(anchor, reason, options)
	options = options or {}
	anchor = normalize_anchor(anchor)

	if state.position.anchor == anchor then
		return
	end

	state.position.anchor = anchor
	log.i(string.format("key caster position anchor updated (%s): %s", reason or "unknown", anchor))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()
	refresh_current_overlay()

	if options.silent ~= true then
		hs.alert.show("按键显示位置已切换为" .. anchor_label(anchor))
	end
end

local function set_position_offset(axis, value, reason, options)
	options = options or {}
	value = math.floor(tonumber(value) or 0)

	if axis == "x" then
		if state.position.offset_x == value then
			return
		end

		state.position.offset_x = value
	else
		if state.position.offset_y == value then
			return
		end

		state.position.offset_y = value
	end

	log.i(
		string.format(
			"key caster position offset updated (%s): %s=%d",
			reason or "unknown",
			tostring(axis),
			value
		)
	)
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()
	refresh_current_overlay()

	if options.silent ~= true then
		hs.alert.show((axis == "x" and "水平偏移" or "垂直偏移") .. "已更新为 " .. tostring(value))
	end
end

local function reset_position(reason, options)
	options = options or {}

	state.position.anchor = configured_defaults.position.anchor
	state.position.offset_x = configured_defaults.position.offset_x
	state.position.offset_y = configured_defaults.position.offset_y
	log.i(string.format("key caster position reset (%s)", reason or "unknown"))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()
	refresh_current_overlay()

	if options.silent ~= true then
		hs.alert.show("按键显示位置已恢复默认")
	end
end

local function set_font_size(size, reason, options)
	options = options or {}
	size = math.max(12, math.floor(tonumber(size) or state.font.size))

	if state.font.size == size then
		return
	end

	state.font.size = size
	log.i(string.format("key caster font size updated (%s): %d", reason or "unknown", size))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()
	refresh_current_overlay()

	if options.silent ~= true then
		hs.alert.show("按键显示字号已更新为 " .. tostring(size))
	end
end

local function reset_font_size(reason, options)
	options = options or {}
	set_font_size(configured_defaults.font.size, reason or "reset font size", options)
end

local function set_duration_seconds(seconds, reason, options)
	options = options or {}
	seconds = math.max(0.1, tonumber(seconds) or state.duration_seconds)

	if math.abs(state.duration_seconds - seconds) < 0.000001 then
		return
	end

	state.duration_seconds = seconds
	log.i(string.format("key caster duration updated (%s): %.3f", reason or "unknown", seconds))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()
	refresh_current_overlay()

	if options.silent ~= true then
		hs.alert.show("按键显示停留时间已更新为 " .. format_duration_label(seconds))
	end
end

local function reset_duration_seconds(reason, options)
	options = options or {}
	set_duration_seconds(configured_defaults.duration_seconds, reason or "reset duration", options)
end

local function menubar_mode_label(mode)
	if mode == "always" then
		return "始终显示"
	elseif mode == "never" then
		return "始终隐藏"
	end

	return "自动显示"
end

local function display_mode_label(mode)
	if mode == "sequence" then
		return "连续拼接"
	end

	return "单键覆盖"
end

local function status_label()
	return state.enabled == true and "已开启" or "已关闭"
end

local function display_hotkey_label()
	if state.hotkey_key == nil then
		return "未设置"
	end

	return format_hotkey(state.hotkey_modifiers, state.hotkey_key)
end

menubar_should_be_visible = function()
	if state == nil then
		return false
	end

	if state.menubar_mode == "always" then
		return true
	end

	if state.menubar_mode == "auto" then
		return state.enabled == true
	end

	return false
end

tooltip_text = function()
	return string.format(
		"按键显示\n状态: %s\n热键: %s\n菜单栏: %s\n显示模式: %s\n位置: %s\n字号: %s | 停留: %s",
		status_label(),
		display_hotkey_label(),
		menubar_mode_label(state.menubar_mode),
		display_mode_label(state.display_mode),
		position_summary_label(),
		font_size_summary_label(),
		format_duration_label(state.duration_seconds)
	)
end

local function build_menubar_mode_menu()
	return {
		{
			title = "自动显示",
			checked = state.menubar_mode == "auto",
			fn = function()
				set_menubar_mode("auto", "menubar update menubar mode", { persist = true })
			end,
		},
		{
			title = "始终显示",
			checked = state.menubar_mode == "always",
			fn = function()
				set_menubar_mode("always", "menubar update menubar mode", { persist = true })
			end,
		},
		{
			title = "始终隐藏",
			checked = state.menubar_mode == "never",
			fn = function()
				set_menubar_mode("never", "menubar update menubar mode", { persist = true })
			end,
		},
	}
end

local function build_display_mode_menu()
	return {
		{
			title = "单键覆盖",
			checked = state.display_mode == "single",
			fn = function()
				set_display_mode("single", "menubar update display mode", { persist = true })
			end,
		},
		{
			title = "连续拼接",
			checked = state.display_mode == "sequence",
			fn = function()
				set_display_mode("sequence", "menubar update display mode", { persist = true })
			end,
		},
	}
end

local function build_position_menu()
	local menu = {
		{
			title = "当前: " .. position_summary_label(),
			disabled = true,
		},
	}
	local ordered_anchors = {
		"top_left",
		"top_center",
		"top_right",
		"center",
		"bottom_left",
		"bottom_center",
		"bottom_right",
	}

	for _, anchor in ipairs(ordered_anchors) do
		table.insert(menu, {
			title = anchor_label(anchor),
			checked = state.position.anchor == anchor,
			fn = function()
				set_position_anchor(anchor, "menubar update anchor", { persist = true })
			end,
		})
	end

	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = string.format("水平偏移: %d", state.position.offset_x),
		disabled = true,
	})
	table.insert(menu, {
		title = "自定义水平偏移...",
		fn = function()
			local value = prompt_number(
				"按键显示水平偏移",
				"请输入水平偏移，正数向右，负数向左。",
				state.position.offset_x,
				nil,
				nil,
				{ integer = true }
			)

			if value == nil then
				return
			end

			set_position_offset("x", value, "menubar update offset x", { persist = true })
		end,
	})
	table.insert(menu, {
		title = string.format("垂直偏移: %d", state.position.offset_y),
		disabled = true,
	})
	table.insert(menu, {
		title = "自定义垂直偏移...",
		fn = function()
			local value = prompt_number(
				"按键显示垂直偏移",
				"请输入垂直偏移，正数通常向下，负数向上。",
				state.position.offset_y,
				nil,
				nil,
				{ integer = true }
			)

			if value == nil then
				return
			end

			set_position_offset("y", value, "menubar update offset y", { persist = true })
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复默认位置",
		disabled = state.position.anchor == configured_defaults.position.anchor
			and state.position.offset_x == configured_defaults.position.offset_x
			and state.position.offset_y == configured_defaults.position.offset_y,
		fn = function()
			reset_position("menubar reset position", { persist = true })
		end,
	})

	return menu
end

local function build_font_size_menu()
	local current_size = math.floor(state.font.size)
	local menu = {
		{
			title = "当前: " .. font_size_summary_label(),
			disabled = true,
		},
	}

	for _, size in ipairs({ 28, 36, 44, 52, 60 }) do
		table.insert(menu, {
			title = string.format("%d pt", size),
			checked = current_size == size,
			fn = function()
				set_font_size(size, "menubar preset font size", { persist = true })
			end,
		})
	end

	table.insert(menu, {
		title = "自定义字号...",
		fn = function()
			local size = prompt_number("按键显示字号", "请输入字号，最小为 12。", current_size, 12, nil, {
				integer = true,
			})

			if size == nil then
				return
			end

			set_font_size(size, "menubar custom font size", { persist = true })
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = string.format("恢复默认 (%d pt)", math.floor(configured_defaults.font.size)),
		disabled = current_size == math.floor(configured_defaults.font.size),
		fn = function()
			reset_font_size("menubar reset font size", { persist = true })
		end,
	})

	return menu
end

local function build_duration_menu()
	local menu = {
		{
			title = "当前: " .. format_duration_label(state.duration_seconds),
			disabled = true,
		},
	}

	for _, seconds in ipairs({ 0.8, 1.2, 1.5, 2.0, 3.0 }) do
		table.insert(menu, {
			title = format_duration_label(seconds),
			checked = math.abs(state.duration_seconds - seconds) < 0.001,
			fn = function()
				set_duration_seconds(seconds, "menubar preset duration", { persist = true })
			end,
		})
	end

	table.insert(menu, {
		title = "自定义停留时间...",
		fn = function()
			local seconds = prompt_number(
				"按键显示停留时间",
				"请输入停留秒数，最小为 0.1，可输入小数。",
				state.duration_seconds,
				0.1,
				nil
			)

			if seconds == nil then
				return
			end

			set_duration_seconds(seconds, "menubar custom duration", { persist = true })
		end,
	})
	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = "恢复默认 (" .. format_duration_label(configured_defaults.duration_seconds) .. ")",
		disabled = math.abs(state.duration_seconds - configured_defaults.duration_seconds) < 0.001,
		fn = function()
			reset_duration_seconds("menubar reset duration", { persist = true })
		end,
	})

	return menu
end

local function menu_config_source_label()
	if table_is_empty(runtime_overrides) == true then
		return "配置: 文件"
	end

	return "配置: 文件+菜单"
end

build_menu = function()
	return {
		{ title = "按键显示", disabled = true },
		{ title = "状态: " .. status_label(), disabled = true },
		{ title = "热键: " .. display_hotkey_label(), disabled = true },
		{ title = "菜单栏: " .. menubar_mode_label(state.menubar_mode), disabled = true },
		{ title = "显示模式: " .. display_mode_label(state.display_mode), disabled = true },
		{ title = "位置: " .. position_summary_label(), disabled = true },
		{
			title = "字号: " .. font_size_summary_label() .. " | 停留: " .. format_duration_label(state.duration_seconds),
			disabled = true,
		},
		{ title = menu_config_source_label(), disabled = true },
		{ title = "-" },
		{
			title = "启用按键显示",
			checked = state.enabled,
			fn = function()
				_M.toggle()
			end,
		},
		{
			title = "菜单栏图标",
			menu = build_menubar_mode_menu(),
		},
		{
			title = "显示模式",
			menu = build_display_mode_menu(),
		},
		{
			title = "显示位置",
			menu = build_position_menu(),
		},
		{
			title = "字体大小",
			menu = build_font_size_menu(),
		},
		{
			title = "停留时间",
			menu = build_duration_menu(),
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
		log.e("hs.menubar is unavailable")
		return
	end

	if menubar_should_be_visible() ~= true then
		destroy_menubar()
		return
	end

	if ensure_visible_menubar() ~= true then
		return
	end

	apply_menubar_content()
end

local function deactivate_capture()
	stop_hide_timer()
	reset_sequence_buffer()
	current_overlay_text = nil

	if event_tap ~= nil then
		event_tap:stop()
		event_tap = nil
	end

	destroy_display_canvas()
	destroy_measurement_canvas()
end

local function activate_capture(reason)
	if event_tap ~= nil then
		return true
	end

	if type(hs.canvas) ~= "table" or type(hs.canvas.new) ~= "function" then
		log.e("failed to enable key caster (" .. tostring(reason or "unknown") .. "): hs.canvas is unavailable")
		return false
	end

	if type(hs.eventtap) ~= "table" or type(hs.eventtap.new) ~= "function" then
		log.e("failed to enable key caster (" .. tostring(reason or "unknown") .. "): hs.eventtap is unavailable")
		return false
	end

	if type(hs.eventtap.event) ~= "table" or type(hs.eventtap.event.types) ~= "table" then
		log.e("failed to enable key caster (" .. tostring(reason or "unknown") .. "): hs.eventtap.event.types is unavailable")
		return false
	end

	measurement_canvas = hs.canvas.new({ x = 0, y = 0, w = 8, h = 8 })

	local event_types = {}

	if hs.eventtap.event.types.keyDown ~= nil then
		table.insert(event_types, hs.eventtap.event.types.keyDown)
	end

	if hs.eventtap.event.types.flagsChanged ~= nil then
		table.insert(event_types, hs.eventtap.event.types.flagsChanged)
	end

	if #event_types == 0 then
		log.e("failed to enable key caster (" .. tostring(reason or "unknown") .. "): no event tap types available")
		destroy_measurement_canvas()
		return false
	end

	event_tap = hs.eventtap.new(event_types, function(event)
		if event == nil or type(event.getType) ~= "function" then
			return false
		end

		local event_type = event:getType()

		if event_type == hs.eventtap.event.types.keyDown then
			render_overlay_text(next_keydown_overlay_text(event))
		elseif event_type == hs.eventtap.event.types.flagsChanged then
			reset_sequence_buffer()
			render_overlay_text(modifier_display_text(event))
		end

		return false
	end)

	if event_tap == nil then
		log.e("failed to create key caster event tap")
		destroy_measurement_canvas()
		return false
	end

	local ok, started_tap = pcall(function()
		return event_tap:start()
	end)

	if ok ~= true or started_tap == false then
		log.e("failed to start key caster event tap")
		event_tap = nil
		destroy_measurement_canvas()
		return false
	end

	return true
end

local function set_enabled(enabled, reason)
	if state.enabled == enabled then
		return true
	end

	if enabled == true then
		if activate_capture(reason) ~= true then
			refresh_menubar()
			hs.alert.show("按键显示启用失败，请检查辅助功能权限")
			return false
		end

		state.enabled = true
		refresh_menubar()
		hs.alert.show("按键显示已开启")

		return true
	end

	state.enabled = false
	deactivate_capture()
	refresh_menubar()
	hs.alert.show("按键显示已关闭")

	return true
end

local function create_hotkey_binding(modifiers, key, message)
	if key == nil then
		return true, nil
	end

	-- Toggle on key release so menubar mutations happen after the shortcut press completes.
	local binding, binding_or_error = hotkey_helper.bind(
		modifiers,
		key,
		message,
		nil,
		function()
			_M.toggle()
		end,
		nil,
		{ logger = log }
	)

	if binding == nil then
		return false, binding_or_error
	end

	return true, binding
end

local function replace_hotkey_binding(binding)
	delete_hotkey_binding()
	hotkey_binding = binding
end

local function apply_hotkey_binding(reason)
	local ok, binding_or_error = create_hotkey_binding(state.hotkey_modifiers, state.hotkey_key, state.hotkey_message)

	if ok ~= true then
		log.e(string.format("failed to bind key caster hotkey (%s): %s", reason or "unknown", tostring(binding_or_error)))
		return false, binding_or_error
	end

	replace_hotkey_binding(binding_or_error)
	refresh_menubar()

	return true
end

local function handle_startup_hotkey_binding_failure(binding_error)
	if state.hotkey_key == nil then
		return
	end

	local message = "按键显示快捷键绑定失败"

	if menubar_should_be_visible() ~= true then
		state.menubar_mode = "always"
		refresh_menubar()
		message = message .. "，已临时显示菜单栏图标"
	else
		refresh_menubar()
	end

	if binding_error ~= nil then
		message = message .. "，请检查快捷键设置"
	end

	hs.alert.show(message)
end

set_menubar_mode = function(mode, reason, options)
	mode = normalize_menubar_mode(mode)
	options = options or {}

	if state.menubar_mode == mode then
		return
	end

	state.menubar_mode = mode
	log.i(string.format("key caster menubar mode updated (%s): %s", reason or "unknown", state.menubar_mode))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()

	if options.silent == true then
		return
	end

	if mode == "always" then
		hs.alert.show("已切换为始终显示按键菜单栏图标")
	elseif mode == "never" then
		hs.alert.show("已隐藏按键菜单栏图标，重载后会回到配置默认值")
	else
		hs.alert.show("已切换为自动显示按键菜单栏图标")
	end
end

set_display_mode = function(mode, reason, options)
	mode = normalize_display_mode(mode)
	options = options or {}

	if state.display_mode == mode then
		return
	end

	state.display_mode = mode
	reset_sequence_buffer()
	stop_hide_timer()
	destroy_display_canvas()
	log.i(string.format("key caster display mode updated (%s): %s", reason or "unknown", state.display_mode))
	if options.persist == true then
		sync_runtime_overrides_with_state()
	end
	refresh_menubar()

	if options.silent == true then
		return
	end

	if mode == "sequence" then
		hs.alert.show("已切换为连续拼接模式")
	else
		hs.alert.show("已切换为单键覆盖模式")
	end
end

_M.enable = function()
	if started ~= true then
		_M.start()
	end

	return set_enabled(true, "manual api enable")
end

_M.disable = function()
	if started ~= true then
		_M.start()
	end

	return set_enabled(false, "manual api disable")
end

_M.toggle = function()
	if started ~= true then
		_M.start()
	end

	return set_enabled(not state.enabled, "manual toggle")
end

_M.show_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_menubar_mode("always", "manual api show menubar")
end

_M.hide_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_menubar_mode("never", "manual api hide menubar")
end

_M.auto_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_menubar_mode("auto", "manual api auto menubar")
end

_M.single_display_mode = function()
	if started ~= true then
		_M.start()
	end

	set_display_mode("single", "manual api single display mode")
end

_M.sequence_display_mode = function()
	if started ~= true then
		_M.start()
	end

	set_display_mode("sequence", "manual api sequence display mode")
end

_M.toggle_menubar_visibility = function()
	if started ~= true then
		_M.start()
	end

	if state.menubar_mode == "never" then
		set_menubar_mode("always", "manual api toggle menubar")
	else
		set_menubar_mode("never", "manual api toggle menubar")
	end
end

_M.get_state = function()
	local snapshot = {
		started = started == true,
		enabled = state ~= nil and state.enabled == true or false,
		display_mode = state ~= nil and state.display_mode or nil,
		menubar_mode = state ~= nil and state.menubar_mode or nil,
		hotkey = state ~= nil and display_hotkey_label() or nil,
		position = state ~= nil and shallow_copy(state.position) or nil,
		font_size = state ~= nil and state.font.size or nil,
		duration_seconds = state ~= nil and state.duration_seconds or nil,
		runtime_overrides = sanitize_runtime_overrides(runtime_overrides),
		menubar_exists = menubar_item ~= nil,
		menubar_in_menu_bar = nil,
		menubar_title = nil,
		menubar_frame = nil,
	}

	if menubar_item == nil then
		return snapshot
	end

	if type(menubar_item.isInMenuBar) == "function" then
		local ok, is_in_menu_bar = pcall(function()
			return menubar_item:isInMenuBar()
		end)

		if ok == true then
			snapshot.menubar_in_menu_bar = is_in_menu_bar == true
		end
	end

	if type(menubar_item.title) == "function" then
		local ok, title = pcall(function()
			return menubar_item:title()
		end)

		if ok == true then
			snapshot.menubar_title = title
		end
	end

	if type(menubar_item.frame) == "function" then
		local ok, frame = pcall(function()
			return menubar_item:frame()
		end)

		if ok == true and frame ~= nil then
			snapshot.menubar_frame = {
				x = frame.x,
				y = frame.y,
				w = frame.w,
				h = frame.h,
			}
		end
	end

	return snapshot
end

function _M.start()
	if started == true then
		return true
	end

	state = normalize_config(merged_config(runtime_overrides))
	started = true

	refresh_menubar()

	local hotkey_ok, hotkey_error = apply_hotkey_binding("startup")

	if hotkey_ok ~= true then
		handle_startup_hotkey_binding_failure(hotkey_error)
	end

	if state.enabled ~= true then
		refresh_menubar()
		return true
	end

	if activate_capture("startup") ~= true then
		state.enabled = false
		refresh_menubar()
		hs.alert.show("按键显示启动失败，请检查辅助功能权限")
		return false
	end

	refresh_menubar()

	return true
end

function _M.stop()
	delete_hotkey_binding()
	deactivate_capture()
	destroy_menubar()
	state = nil
	started = false

	return true
end

return _M
