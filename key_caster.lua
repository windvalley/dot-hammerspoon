local _M = {}

_M.name = "key_caster"
_M.description = "录屏/演示场景下的按键可视化，并提供轻量运行时控制"

local key_caster = require("keybindings_config").key_caster or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local shallow_copy = utils_lib.shallow_copy
local copy_list = utils_lib.copy_list
local trim = utils_lib.trim
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
local default_toggle_hotkey = {
	prefix = { "Ctrl", "Option", "Shift" },
	key = "K",
	message = "Toggle Key Caster",
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
local valid_menubar_modes = {
	auto = true,
	always = true,
	never = true,
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
		padding_x = resolve_number(config.padding_x, 24, 0),
		padding_y = resolve_number(config.padding_y, 12, 0),
		corner_radius = resolve_number(config.corner_radius, 14, 0),
		min_width = resolve_number(config.min_width, 108, 0),
		hotkey_modifiers = copy_list(hotkey_modifiers),
		hotkey_key = normalize_hotkey_key(toggle_hotkey.key == nil and default_toggle_hotkey.key or toggle_hotkey.key),
		hotkey_message = tostring(toggle_hotkey.message or default_toggle_hotkey.message),
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

local function destroy_menubar()
	if menubar_item == nil then
		return
	end

	menubar_item:delete()
	menubar_item = nil
end

local function set_menubar_visibility(visible)
	if menubar_item == nil then
		return
	end

	local is_in_menu_bar = nil

	if type(menubar_item.isInMenuBar) == "function" then
		is_in_menu_bar = menubar_item:isInMenuBar()
	end

	if visible == true then
		if is_in_menu_bar ~= true and type(menubar_item.returnToMenuBar) == "function" then
			menubar_item:returnToMenuBar()
		end
	elseif is_in_menu_bar ~= false and type(menubar_item.removeFromMenuBar) == "function" then
		menubar_item:removeFromMenuBar()
	end
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

local function menubar_mode_label(mode)
	if mode == "always" then
		return "始终显示"
	elseif mode == "never" then
		return "始终隐藏"
	end

	return "自动显示"
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

local function menubar_should_be_visible()
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

local function tooltip_text()
	return string.format(
		"按键显示\n状态: %s\n热键: %s\n菜单栏: %s",
		status_label(),
		display_hotkey_label(),
		menubar_mode_label(state.menubar_mode)
	)
end

local function build_menubar_mode_menu()
	return {
		{
			title = "自动显示",
			checked = state.menubar_mode == "auto",
			fn = function()
				_M.auto_menubar()
			end,
		},
		{
			title = "始终显示",
			checked = state.menubar_mode == "always",
			fn = function()
				_M.show_menubar()
			end,
		},
		{
			title = "始终隐藏",
			checked = state.menubar_mode == "never",
			fn = function()
				_M.hide_menubar()
			end,
		},
	}
end

local function build_menu()
	return {
		{ title = "按键显示", disabled = true },
		{ title = "状态: " .. status_label(), disabled = true },
		{ title = "热键: " .. display_hotkey_label(), disabled = true },
		{ title = "菜单栏: " .. menubar_mode_label(state.menubar_mode), disabled = true },
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
	}
end

local function refresh_menubar()
	if type(hs.menubar) ~= "table" or type(hs.menubar.new) ~= "function" then
		log.e("hs.menubar is unavailable")
		return
	end

	if menubar_item == nil then
		menubar_item = hs.menubar.new(false)

		if menubar_item == nil then
			log.e("failed to create key caster menubar item")
			return
		end
	end

	menubar_item:setMenu(build_menu)
	menubar_item:setTitle(state.enabled == true and "KC" or "Kc")
	menubar_item:setTooltip(tooltip_text())
	set_menubar_visibility(menubar_should_be_visible())
end

local function deactivate_capture()
	stop_hide_timer()

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
			local flags = type(event.getFlags) == "function" and event:getFlags() or {}
			local key_name = key_name_from_event(event)
			local text = format_key_combo(flags, key_name)

			if text ~= nil then
				local text_width, text_height, styled_text = measure_text(text)
				local width = math.max(state.min_width, text_width + (state.padding_x * 2))
				local height = text_height + (state.padding_y * 2)
				local frame = resolve_canvas_frame(width, height)

				if frame ~= nil then
					stop_hide_timer()
					destroy_display_canvas()

					display_canvas = hs.canvas.new(frame)

					if display_canvas ~= nil then
						if
							type(hs.canvas) == "table"
							and type(hs.canvas.windowLevels) == "table"
							and hs.canvas.windowLevels.overlay ~= nil
						then
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
				end
			end
		elseif event_type == hs.eventtap.event.types.flagsChanged then
			local text = modifier_display_text(event)

			if text ~= nil then
				local text_width, text_height, styled_text = measure_text(text)
				local width = math.max(state.min_width, text_width + (state.padding_x * 2))
				local height = text_height + (state.padding_y * 2)
				local frame = resolve_canvas_frame(width, height)

				if frame ~= nil then
					stop_hide_timer()
					destroy_display_canvas()

					display_canvas = hs.canvas.new(frame)

					if display_canvas ~= nil then
						if
							type(hs.canvas) == "table"
							and type(hs.canvas.windowLevels) == "table"
							and hs.canvas.windowLevels.overlay ~= nil
						then
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
				end
			end
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

	local binding, binding_or_error = hotkey_helper.bind(
		modifiers,
		key,
		message,
		function()
			_M.toggle()
		end,
		nil,
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

local function set_menubar_mode(mode, reason, options)
	mode = normalize_menubar_mode(mode)
	options = options or {}

	if state.menubar_mode == mode then
		return
	end

	state.menubar_mode = mode
	log.i(string.format("key caster menubar mode updated (%s): %s", reason or "unknown", state.menubar_mode))
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

function _M.start()
	if started == true then
		return true
	end

	state = normalize_config(key_caster)
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
