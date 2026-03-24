local _M = {}

_M.name = "keep_awake"
_M.description = "防止电脑空闲休眠, 并提供菜单栏图标"

local keep_awake = require("keybindings_config").system.keep_awake or {}
local hotkey_helper = require("hotkey_helper")
local trim = require("utils_lib").trim

local log = hs.logger.new("awake")

local enabled_settings_key = "keep_awake.enabled"
local display_settings_key = "keep_awake.keep_display_awake"
local hotkey_modifiers_settings_key = "keep_awake.hotkey.modifiers"
local hotkey_key_settings_key = "keep_awake.hotkey.key"
local default_enabled = keep_awake.enabled == true
local default_keep_display_awake = keep_awake.keep_display_awake == true
local default_hotkey_modifiers = keep_awake.prefix or {}
local default_hotkey_key = keep_awake.key
local hotkey_message = keep_awake.message or "Toggle Prevent Sleep"

local menubar_item = nil
local menubar_icon_size = 18
local menubar_canvas_size = 36
local build_menu = nil
local hotkey_binding = nil
local started = false

local modifier_aliases = {
	ctrl = "ctrl",
	control = "ctrl",
	["⌃"] = "ctrl",
	alt = "alt",
	option = "alt",
	opt = "alt",
	["⌥"] = "alt",
	cmd = "cmd",
	command = "cmd",
	["⌘"] = "cmd",
	shift = "shift",
	["⇧"] = "shift",
	fn = "fn",
	["function"] = "fn",
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

local modifier_prompt_names = {
	ctrl = "ctrl",
	alt = "option",
	cmd = "command",
	shift = "shift",
	fn = "fn",
}

local state = {
	enabled = default_enabled,
	show_menubar = keep_awake.show_menubar ~= false,
	keep_display_awake = default_keep_display_awake,
	hotkey_modifiers = {},
	hotkey_key = nil,
}

local persisted_keep_display_awake = hs.settings.get(display_settings_key)
local persisted_hotkey_modifiers = hs.settings.get(hotkey_modifiers_settings_key)
local persisted_hotkey_key = hs.settings.get(hotkey_key_settings_key)

local function copy_list(values)
	local copied = {}

	if type(values) ~= "table" then
		return copied
	end

	for _, value in ipairs(values) do
		table.insert(copied, value)
	end

	return copied
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

local function normalize_hotkey_modifiers(raw_modifiers)
	local normalized = {}
	local seen = {}
	local values = {}

	if raw_modifiers == nil then
		return normalized
	end

	if type(raw_modifiers) == "table" then
		values = raw_modifiers
	else
		local text = tostring(raw_modifiers)
		text = text:gsub("，", ",")
		text = text:gsub("＋", "+")

		for token in string.gmatch(text, "[^,%+%s]+") do
			table.insert(values, token)
		end
	end

	for _, raw_value in ipairs(values) do
		local token = string.lower(trim(tostring(raw_value)))

		if token ~= "" then
			local modifier = modifier_aliases[token]

			if modifier == nil then
				return nil, raw_value
			end

			if seen[modifier] ~= true then
				seen[modifier] = true
				table.insert(normalized, modifier)
			end
		end
	end

	table.sort(
		normalized,
		function(left, right)
			return modifier_order[left] < modifier_order[right]
		end
	)

	return normalized
end

local function format_hotkey(modifiers, key)
	if key == nil then
		return "未设置"
	end

	local parts = {}

	for _, modifier in ipairs(modifiers or {}) do
		table.insert(parts, modifier_symbols[modifier] or modifier)
	end

	table.insert(parts, string.upper(key))

	return table.concat(parts, " ")
end

local function hotkey_hint_color()
	if hs.host.interfaceStyle() == "Dark" then
		return { white = 1, alpha = 0.48 }
	end

	return { white = 0, alpha = 0.42 }
end

local function format_menu_title_with_hotkey(title)
	if state.hotkey_key == nil then
		return title
	end

	local suffix = string.format("  %s", format_hotkey(state.hotkey_modifiers, state.hotkey_key))
	local styled_title = hs.styledtext.new(title .. suffix)

	return styled_title:setStyle({ color = hotkey_hint_color() }, (#title + 1), (#title + #suffix))
end

local function format_hotkey_for_prompt(modifiers, key)
	local modifier_names = {}

	for _, modifier in ipairs(modifiers or {}) do
		table.insert(modifier_names, modifier_prompt_names[modifier] or modifier)
	end

	return table.concat(modifier_names, "+"), key or ""
end

local function prompt_text(message, informative_text, default_value)
	local button, value = hs.dialog.textPrompt(
		message,
		informative_text,
		default_value or "",
		"保存",
		"取消",
		false
	)

	if button ~= "保存" then
		return nil
	end

	return value
end

default_hotkey_modifiers = normalize_hotkey_modifiers(default_hotkey_modifiers) or {}
default_hotkey_key = normalize_hotkey_key(default_hotkey_key)
state.hotkey_modifiers = copy_list(default_hotkey_modifiers)
state.hotkey_key = default_hotkey_key

if type(persisted_keep_display_awake) == "boolean" then
	state.keep_display_awake = persisted_keep_display_awake
end

if persisted_hotkey_modifiers ~= nil or persisted_hotkey_key ~= nil then
	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(persisted_hotkey_modifiers)
	local normalized_key = normalize_hotkey_key(persisted_hotkey_key)

	if normalized_modifiers == nil then
		log.w("ignore invalid persisted keep awake hotkey modifier: " .. tostring(invalid_modifier))
		hs.settings.clear(hotkey_modifiers_settings_key)
		hs.settings.clear(hotkey_key_settings_key)
	else
		state.hotkey_modifiers = normalized_modifiers
		state.hotkey_key = normalized_key
	end
end

local function persist_enabled_state()
	-- 防休眠开关在重载后回到配置文件默认值，不沿用运行时状态。
	hs.settings.clear(enabled_settings_key)
end

local function persist_keep_display_awake_state()
	if state.keep_display_awake == default_keep_display_awake then
		hs.settings.clear(display_settings_key)
		return
	end

	hs.settings.set(display_settings_key, state.keep_display_awake)
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

local function status_title()
	if state.enabled ~= true then
		return "已关闭"
	end

	return "已开启"
end

local function mode_label()
	if state.keep_display_awake == true then
		return "系统与屏幕常亮"
	end

	return "仅阻止系统休眠"
end

local function status_detail()
	if state.enabled ~= true then
		return "未阻止空闲休眠, macOS 会按电源设置正常熄屏或休眠"
	end

	if state.keep_display_awake == true then
		return "已阻止系统和屏幕因空闲而休眠"
	end

	return "已阻止系统因空闲而休眠, 屏幕仍可熄灭"
end

local function icon_color(alpha)
	return {
		white = 0,
		alpha = alpha,
	}
end

local function circle_path_coordinates(start_radians, end_radians, center_x, center_y, radius)
	local radians_span = end_radians - start_radians
	local steps = math.max(12, math.ceil(math.abs(radians_span) * 12))
	local coordinates = {}

	for index = 0, steps do
		local ratio = index / steps
		local angle = start_radians + (radians_span * ratio)

		table.insert(
			coordinates,
			{
				x = center_x + (math.cos(angle) * radius),
				y = center_y + (math.sin(angle) * radius),
			}
		)
	end

	return coordinates
end

local function build_menubar_icon()
	local canvas = hs.canvas.new({
		x = 0,
		y = 0,
		w = menubar_canvas_size,
		h = menubar_canvas_size,
	})
	local center_x = menubar_canvas_size / 2
	local center_y = menubar_canvas_size / 2
	local power_icon_alpha = state.enabled == true and 1 or 0.34
	local power_color = icon_color(power_icon_alpha)
	local outer_ring_alpha = 0.18

	if state.enabled == true then
		outer_ring_alpha = state.keep_display_awake == true and 1 or 0.72
	end

	local outer_ring_color = icon_color(outer_ring_alpha)
	local outer_ring_stroke_width = state.keep_display_awake == true and 3.0 or 1.7

	canvas:appendElements(
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 2.1,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = power_color,
			coordinates = circle_path_coordinates(math.rad(40), math.rad(320), center_x, center_y, 9.4),
		},
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 2.1,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = power_color,
			coordinates = {
				{ x = center_x, y = 8.1 },
				{ x = center_x, y = 17.2 },
			},
		}
	)

	canvas:appendElements(
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = outer_ring_stroke_width,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = outer_ring_color,
			coordinates = circle_path_coordinates(0, math.rad(359), center_x, center_y, 13.6),
		}
	)

	local icon = canvas:imageFromCanvas()

	canvas:delete()

	if icon == nil then
		return nil
	end

	icon:size({ w = menubar_icon_size, h = menubar_icon_size }, true)

	return icon
end

local function refresh_menubar()
	if state.show_menubar ~= true then
		if menubar_item ~= nil then
			menubar_item:delete()
			menubar_item = nil
		end
		return
	end

	if menubar_item == nil then
		menubar_item = hs.menubar.new()

		if menubar_item == nil then
			log.e("failed to create keep awake menubar item")
			return
		end
	end

	menubar_item:setMenu(build_menu)

	local icon = build_menubar_icon()

	if icon ~= nil then
		menubar_item:setIcon(icon, true)
		menubar_item:setTitle(nil)
	else
		menubar_item:setIcon(nil)
		menubar_item:setTitle(state.enabled == true and "AWAKE" or "SLEEP")
	end

	menubar_item:setTooltip(
		string.format(
			"防休眠\n状态: %s\n模式: %s\n%s\n快捷键: %s",
			status_title(),
			mode_label(),
			status_detail(),
			format_hotkey(state.hotkey_modifiers, state.hotkey_key)
		)
	)
end

local function apply_state(reason)
	hs.caffeinate.set("displayIdle", state.enabled == true and state.keep_display_awake == true)
	hs.caffeinate.set("systemIdle", state.enabled == true)

	log.i(
		string.format(
			"apply keep awake (%s): enabled=%s, keep_display_awake=%s",
			reason or "unknown",
			tostring(state.enabled),
			tostring(state.keep_display_awake)
		)
	)

	refresh_menubar()
end

local function show_status_alert()
	local message = "防休眠已关闭"

	if state.enabled == true and state.keep_display_awake == true then
		message = "防休眠已开启, 屏幕保持常亮"
	elseif state.enabled == true then
		message = "防休眠已开启, 屏幕可休眠"
	end

	hs.alert.show(message)
end

local function set_enabled(enabled, reason)
	if state.enabled == enabled then
		return
	end

	state.enabled = enabled
	persist_enabled_state()
	apply_state(reason)
	show_status_alert()
end

local function set_keep_display_awake(keep_display_awake, reason)
	if state.keep_display_awake == keep_display_awake then
		return
	end

	state.keep_display_awake = keep_display_awake
	persist_keep_display_awake_state()
	apply_state(reason)

	if state.keep_display_awake == true then
		hs.alert.show("已切换为系统与屏幕常亮")
	else
		hs.alert.show("已切换为仅阻止系统休眠")
	end
end

local function set_show_menubar(show_menubar, reason)
	if state.show_menubar == show_menubar then
		return
	end

	state.show_menubar = show_menubar
	log.i(
		string.format(
			"keep awake menubar visibility updated (%s): show_menubar=%s",
			reason or "unknown",
			tostring(state.show_menubar)
		)
	)
	refresh_menubar()

	if state.show_menubar == true then
		hs.alert.show("已显示防休眠菜单栏图标")
	else
		hs.alert.show("已隐藏防休眠菜单栏图标，重载后会回到配置默认值")
	end
end

local function create_hotkey_binding(modifiers, key)
	if key == nil then
		return true, nil
	end

	local binding, binding_or_error = hotkey_helper.bind(
		modifiers,
		key,
		hotkey_message,
		function()
			set_enabled(not state.enabled, "hotkey toggle")
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
	if hotkey_binding ~= nil then
		hotkey_binding:delete()
	end

	hotkey_binding = binding
end

local function apply_hotkey_binding(reason)
	local ok, binding_or_error = create_hotkey_binding(state.hotkey_modifiers, state.hotkey_key)

	if ok ~= true then
		log.e(
			string.format(
				"failed to bind keep awake hotkey (%s): %s",
				reason or "unknown",
				tostring(binding_or_error)
			)
		)
		return false, binding_or_error
	end

	replace_hotkey_binding(binding_or_error)
	refresh_menubar()

	return true
end

local function set_hotkey(modifiers, key, reason)
	local previous_modifiers = copy_list(state.hotkey_modifiers)
	local previous_key = state.hotkey_key
	local previous_binding = hotkey_binding

	state.hotkey_modifiers = copy_list(modifiers)
	state.hotkey_key = key
	hotkey_binding = nil

	if previous_binding ~= nil then
		previous_binding:delete()
	end

	local ok = apply_hotkey_binding(reason)

	if ok ~= true then
		state.hotkey_modifiers = previous_modifiers
		state.hotkey_key = previous_key
		hotkey_binding = nil
		apply_hotkey_binding("restore previous hotkey")
		hs.alert.show("快捷键设置失败")
		return false
	end

	persist_hotkey_state()

	if state.hotkey_key == nil then
		hs.alert.show("已禁用防休眠快捷键")
	else
		hs.alert.show("快捷键已更新: " .. format_hotkey(state.hotkey_modifiers, state.hotkey_key))
	end

	return true
end

local function prompt_hotkey_configuration()
	local current_modifiers, current_key = format_hotkey_for_prompt(state.hotkey_modifiers, state.hotkey_key)
	local modifier_text = prompt_text(
		"设置防休眠快捷键",
		"请输入修饰键, 多个值用 + 分隔。\n可用: ctrl option command shift fn\n留空表示无修饰键。",
		current_modifiers
	)

	if modifier_text == nil then
		return
	end

	local key_text = prompt_text(
		"设置防休眠快捷键",
		"请输入主键, 例如 a、space、return、f18。\n留空表示禁用快捷键。",
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

	set_hotkey(normalized_modifiers, normalized_key, "menubar update hotkey")
end

build_menu = function()
	return {
		{ title = "防休眠", disabled = true },
		{ title = "状态: " .. status_title(), disabled = true },
		{ title = "已选模式: " .. mode_label(), disabled = true },
		{ title = status_detail(), disabled = true },
		{ title = "-" },
		{
			title = format_menu_title_with_hotkey(state.enabled == true and "关闭防休眠" or "开启防休眠"),
			fn = function()
				set_enabled(not state.enabled, "menubar toggle")
			end,
		},
		{
			title = "模式",
			menu = {
				{
					title = "仅阻止系统休眠",
					checked = state.keep_display_awake ~= true,
					fn = function()
						set_keep_display_awake(false, "menubar mode system only")
					end,
				},
				{
					title = "系统与屏幕常亮",
					checked = state.keep_display_awake == true,
					fn = function()
						set_keep_display_awake(true, "menubar mode display awake")
					end,
				},
			},
		},
		{
			title = "设置快捷键",
			fn = prompt_hotkey_configuration,
		},
		{
			title = "隐藏菜单栏图标",
			fn = function()
				set_show_menubar(false, "menubar hide item")
			end,
		},
	}
end

_M.show_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(true, "manual api show menubar")
end

_M.hide_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(false, "manual api hide menubar")
end

_M.toggle_menubar_visibility = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(not state.show_menubar, "manual api toggle menubar")
end

function _M.start()
	if started == true then
		return true
	end

	refresh_menubar()
	apply_hotkey_binding("startup")
	apply_state("startup")
	started = true

	return true
end

function _M.stop()
	if hotkey_binding ~= nil then
		hotkey_binding:delete()
		hotkey_binding = nil
	end

	if menubar_item ~= nil then
		menubar_item:delete()
		menubar_item = nil
	end

	hs.caffeinate.set("displayIdle", false)
	hs.caffeinate.set("systemIdle", false)
	started = false

	return true
end

return _M
