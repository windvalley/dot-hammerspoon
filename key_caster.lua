local _M = {}

_M.name = "key_caster"
_M.description = "录屏/演示场景下的按键可视化"

local key_caster = require("keybindings_config").key_caster or {}
local shallow_copy = require("utils_lib").shallow_copy

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
local valid_anchors = {
	top_left = true,
	top_center = true,
	top_right = true,
	center = true,
	bottom_left = true,
	bottom_center = true,
	bottom_right = true,
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
local state = nil

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

local function normalize_config(config)
	local position = type(config.position) == "table" and config.position or {}
	local font = type(config.font) == "table" and config.font or {}

	return {
		enabled = config.enabled == true,
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
		padding_x = resolve_number(config.padding_x, 24, 0),
		padding_y = resolve_number(config.padding_y, 12, 0),
		corner_radius = resolve_number(config.corner_radius, 14, 0),
		min_width = resolve_number(config.min_width, 108, 0),
	}
end

local function stop_hide_timer()
	if hide_timer == nil then
		return
	end

	hide_timer:stop()
	hide_timer = nil
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

local function show_text(text)
	if type(text) ~= "string" or text == "" then
		return
	end

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
	end)
end

local function handle_event(event)
	if event == nil or type(event.getType) ~= "function" then
		return false
	end

	local event_type = event:getType()

	if event_type == hs.eventtap.event.types.keyDown then
		local flags = type(event.getFlags) == "function" and event:getFlags() or {}
		local key_name = key_name_from_event(event)
		local text = format_key_combo(flags, key_name)

		if text ~= nil then
			show_text(text)
		end
	elseif event_type == hs.eventtap.event.types.flagsChanged then
		local text = modifier_display_text(event)

		if text ~= nil then
			show_text(text)
		end
	end

	return false
end

function _M.start()
	if started == true then
		return true
	end

	state = normalize_config(key_caster)

	if state.enabled ~= true then
		return true
	end

	if type(hs.canvas) ~= "table" or type(hs.canvas.new) ~= "function" then
		log.e("hs.canvas is unavailable")
		return false
	end

	if type(hs.eventtap) ~= "table" or type(hs.eventtap.new) ~= "function" then
		log.e("hs.eventtap is unavailable")
		return false
	end

	measurement_canvas = hs.canvas.new({ x = 0, y = 0, w = 8, h = 8 })

	local event_types = {
		hs.eventtap.event.types.keyDown,
		hs.eventtap.event.types.flagsChanged,
	}

	event_tap = hs.eventtap.new(event_types, handle_event)

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

	started = true

	return true
end

function _M.stop()
	stop_hide_timer()

	if event_tap ~= nil then
		event_tap:stop()
		event_tap = nil
	end

	destroy_display_canvas()
	destroy_measurement_canvas()

	started = false

	return true
end

return _M
