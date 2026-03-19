local _M = {}

_M.name = "break_reminder"
_M.description = "每工作一段时间后强制休息"

local base_config = require("keybindings_config").break_reminder or {}

local log = hs.logger.new("break")
local settings_key = "break_reminder.runtime_overrides"
local default_menubar_title = "☕"
local default_overlay_opacity = {
	soft = 0.32,
	hard = 0.96,
}
local menubar_icon_size = 22
local menubar_canvas_size = 36
local valid_modes = {
	soft = true,
	hard = true,
}
local valid_start_next_cycle_modes = {
	auto = true,
	on_input = true,
}
local blocked_event_type_names = {
	"keyDown",
	"keyUp",
	"flagsChanged",
	"mouseMoved",
	"leftMouseDown",
	"leftMouseUp",
	"leftMouseDragged",
	"rightMouseDown",
	"rightMouseUp",
	"rightMouseDragged",
	"otherMouseDown",
	"otherMouseUp",
	"otherMouseDragged",
	"scrollWheel",
	"gesture",
	"tabletPointer",
	"tabletProximity",
}
local resume_input_event_type_names = {
	"keyDown",
	"mouseMoved",
	"leftMouseDown",
	"leftMouseDragged",
	"rightMouseDown",
	"rightMouseDragged",
	"otherMouseDown",
	"otherMouseDragged",
	"scrollWheel",
	"gesture",
	"tabletPointer",
}

local function resolve_integer_seconds(value, default_value, minimum_seconds)
	local seconds = tonumber(value)

	if seconds == nil then
		seconds = default_value
	end

	return math.max(minimum_seconds, math.floor(seconds))
end

local function resolve_number(value, default_value, minimum_value)
	local number = tonumber(value)

	if number == nil then
		number = default_value
	end

	return math.max(minimum_value, number)
end

local function clamp_number(value, minimum_value, maximum_value)
	return math.min(maximum_value, math.max(minimum_value, value))
end

local function shallow_copy(table_value)
	local copy = {}

	for key, value in pairs(table_value or {}) do
		copy[key] = value
	end

	return copy
end

local function table_is_empty(table_value)
	return next(table_value or {}) == nil
end

local function normalize_mode(value)
	local mode = tostring(value or "hard"):lower()

	if valid_modes[mode] ~= true then
		log.w(string.format("invalid break mode: %s, fallback to hard", mode))
		mode = "hard"
	end

	return mode
end

local function normalize_start_next_cycle_mode(value)
	local mode = tostring(value or "auto"):lower()

	if valid_start_next_cycle_modes[mode] ~= true then
		log.w(string.format("invalid start_next_cycle mode: %s, fallback to auto", mode))
		mode = "auto"
	end

	return mode
end

local function merged_config(runtime_overrides)
	local config = shallow_copy(base_config)

	for key, value in pairs(runtime_overrides or {}) do
		config[key] = value
	end

	return config
end

local function normalize_config(config)
	local mode = normalize_mode(config.mode)
	local work_seconds = math.max(60, math.floor((tonumber(config.work_minutes) or 30) * 60))

	return {
		enabled = config.enabled ~= false,
		show_menubar = config.show_menubar ~= false,
		show_progress_in_menubar = config.show_progress_in_menubar ~= false,
		menubar_title = tostring(config.menubar_title or default_menubar_title),
		start_next_cycle = normalize_start_next_cycle_mode(config.start_next_cycle),
		mode = mode,
		minimal_display = config.minimal_display == true,
		work_seconds = work_seconds,
		rest_seconds = resolve_integer_seconds(config.rest_seconds, 120, 1),
		friendly_reminder_seconds = resolve_integer_seconds(config.friendly_reminder_seconds, 0, 0),
		friendly_reminder_duration_seconds = resolve_number(config.friendly_reminder_duration_seconds, 1.5, 0),
		friendly_reminder_message = tostring(config.friendly_reminder_message or "还有 {{remaining}} 开始休息"),
		overlay_opacity = clamp_number(
			resolve_number(config.overlay_opacity, default_overlay_opacity[mode], 0),
			0,
			1
		),
	}
end

local function format_seconds(total_seconds)
	local minutes = math.floor(total_seconds / 60)
	local seconds = total_seconds % 60

	return string.format("%02d:%02d", minutes, seconds)
end

local function format_duration(total_seconds)
	total_seconds = math.max(0, math.floor(total_seconds))

	local minutes = math.floor(total_seconds / 60)
	local seconds = total_seconds % 60

	if minutes > 0 and seconds > 0 then
		return string.format("%d 分钟 %d 秒", minutes, seconds)
	end

	if minutes > 0 then
		return string.format("%d 分钟", minutes)
	end

	return string.format("%d 秒", seconds)
end

local function format_compact_duration(total_seconds)
	total_seconds = math.max(0, math.floor(total_seconds))

	local minutes = math.floor(total_seconds / 60)
	local seconds = total_seconds % 60

	if minutes > 0 and seconds > 0 then
		return string.format("%d分%d秒", minutes, seconds)
	end

	if minutes > 0 then
		return string.format("%d分", minutes)
	end

	return string.format("%d秒", seconds)
end

local function format_minutes(total_seconds)
	local minutes = total_seconds / 60

	if math.abs(minutes - math.floor(minutes)) < 0.001 then
		return string.format("%d 分钟", minutes)
	end

	return string.format("%.1f 分钟", minutes)
end

local function format_decimal(value)
	return string.format("%.2f", value)
end

local function serialize_number(value)
	if math.abs(value - math.floor(value)) < 0.000001 then
		return string.format("%d", value)
	end

	local formatted = string.format("%.4f", value)

	formatted = formatted:gsub("0+$", "")
	formatted = formatted:gsub("%.$", "")

	return formatted
end

local function serialize_lua_value(value)
	local value_type = type(value)

	if value_type == "boolean" then
		return tostring(value)
	end

	if value_type == "number" then
		return serialize_number(value)
	end

	if value_type == "string" then
		return string.format("%q", value)
	end

	error(string.format("unsupported lua value type: %s", value_type))
end

local function render_template(template, variables)
	return (template:gsub("{{%s*([%w_]+)%s*}}", function(key)
		local value = variables[key]

		if value == nil then
			return "{{" .. key .. "}}"
		end

		return tostring(value)
	end))
end

local function mode_label(mode)
	if mode == "soft" then
		return "柔性提醒"
	end

	return "硬性提醒"
end

local function load_runtime_overrides()
	local saved = hs.settings.get(settings_key)

	if type(saved) == "table" then
		return saved
	end

	return {}
end

local runtime_overrides = load_runtime_overrides()
local state = normalize_config(merged_config(runtime_overrides))

local background_color = { red = 0.04, green = 0.05, blue = 0.08 }
local title_color = { hex = "#F4F1DE" }
local countdown_color = { hex = "#E9C46A" }
local description_color = { hex = "#D8DEE9" }
local hint_color = { hex = "#9AA5B1" }
local reminder_background_color = { red = 0.10, green = 0.11, blue = 0.15, alpha = 0.96 }
local reminder_border_color = { red = 0.82, green = 0.68, blue = 0.34, alpha = 1 }
local reminder_text_color = { hex = "#F4F1DE" }
local reminder_close_color = { hex = "#E9C46A" }
local menubar_disabled_color = { white = 0, alpha = 0.34 }
local menubar_paused_color = { white = 0, alpha = 0.52 }
local menubar_active_color = { white = 0, alpha = 1 }
local menubar_waiting_color = { white = 0, alpha = 0.72 }
local menubar_track_color = { white = 0, alpha = 0.18 }
local font_name = "Monaco"
local icon_font_name = "Apple Color Emoji"

local work_timer = nil
local break_timer = nil
local friendly_reminder_timer = nil
local friendly_reminder_popup_timer = nil
local menubar_status_timer = nil
local inactive_resume_timer = nil
local break_ends_at = nil
local next_break_at = nil
local work_cycle_started_at = nil
local session_is_inactive = false
local waiting_for_resume_input = false
local overlays = {}
local frontmost_app = nil
local blocked_event_types = {}
local resume_input_event_types = {}
local friendly_reminder_canvas = nil
local menubar_item = nil

local refresh_menubar = function()
end
local update_menubar_status = function()
end
local try_resume_after_inactive_session = nil
local start_inactive_resume_timer = nil
local stop_inactive_resume_timer = nil
local schedule_next_break = nil
local finish_break = nil
local start_break = nil
local restart_work_cycle = nil
local apply_current_configuration = nil
local update_runtime_overrides = nil
local clear_runtime_overrides = nil
local export_current_config_to_file = nil
local destroy_friendly_reminder_popup = nil

for _, name in ipairs(blocked_event_type_names) do
	local event_type = hs.eventtap.event.types[name]

	if event_type ~= nil then
		table.insert(blocked_event_types, event_type)
	end
end

for _, name in ipairs(resume_input_event_type_names) do
	local event_type = hs.eventtap.event.types[name]

	if event_type ~= nil then
		table.insert(resume_input_event_types, event_type)
	end
end

local function style_text(text, size, color)
	return hs.styledtext.new(
		text,
		{
			font = {
				name = font_name,
				size = size,
			},
			color = color,
		}
	)
end

local function style_icon_text(text, size)
	return hs.styledtext.new(
		text,
		{
			font = {
				name = icon_font_name,
				size = size,
			},
		}
	)
end

local function append_centered_text(canvas, id, styled_text, y)
	local size = canvas:minimumTextSize(styled_text)
	local frame = canvas:frame()

	canvas:appendElements(
		{
			id = id,
			type = "text",
			text = styled_text,
			frame = {
				x = math.floor((frame.w - size.w) / 2),
				y = y,
				w = size.w,
				h = size.h,
			},
		}
	)
end

local function is_soft_mode()
	return state.mode == "soft"
end

local function is_hard_mode()
	return state.mode == "hard"
end

local function start_next_cycle_label(mode)
	if mode == "on_input" then
		return "首次输入后开始"
	end

	return "休息结束立即开始"
end

local function short_start_next_cycle_label(mode)
	if mode == "on_input" then
		return "输入后开始"
	end

	return "立即开始"
end

local function short_mode_label(mode)
	if mode == "soft" then
		return "柔性"
	end

	return "硬性"
end

local function overlay_background()
	return {
		red = background_color.red,
		green = background_color.green,
		blue = background_color.blue,
		alpha = state.overlay_opacity,
	}
end

local function overlay_hint()
	if is_soft_mode() then
		return "当前为柔性提醒，可继续操作"
	end

	return "当前为硬性强制，键盘和鼠标已锁定"
end

local function stop_work_timer()
	if work_timer == nil then
		return
	end

	work_timer:stop()
	work_timer = nil
end

local function stop_break_timer()
	if break_timer == nil then
		return
	end

	break_timer:stop()
	break_timer = nil
end

local function stop_friendly_reminder_timer()
	if friendly_reminder_timer == nil then
		return
	end

	friendly_reminder_timer:stop()
	friendly_reminder_timer = nil
end

local function stop_input_blocker()
	if _M.input_blocker == nil then
		return
	end

	_M.input_blocker:stop()
end

local function stop_resume_input_watcher()
	if _M.resume_input_watcher == nil then
		return
	end

	_M.resume_input_watcher:stop()
end

local function start_resume_input_watcher()
	if #resume_input_event_types == 0 then
		log.w("resume input event types are empty, skip waiting for input")
		return false
	end

	if _M.resume_input_watcher == nil then
		_M.resume_input_watcher = hs.eventtap.new(
			resume_input_event_types,
			function()
				if waiting_for_resume_input ~= true then
					return false
				end

				waiting_for_resume_input = false
				stop_resume_input_watcher()

				if state.enabled ~= true or session_is_inactive == true or break_ends_at ~= nil then
					update_menubar_status()
					return false
				end

				log.i("work timer restarted on first input after break")
				schedule_next_break("first input after break")

				return false
			end
		)
	end

	_M.resume_input_watcher:start()

	return true
end

local function start_input_blocker()
	if not is_hard_mode() then
		return
	end

	if #blocked_event_types == 0 then
		log.w("blocked event types are empty, skip input blocker")
		return
	end

	if _M.input_blocker == nil then
		_M.input_blocker = hs.eventtap.new(
			blocked_event_types,
			function()
				return true
			end
		)
	end

	_M.input_blocker:start()
end

destroy_friendly_reminder_popup = function()
	if friendly_reminder_popup_timer ~= nil then
		friendly_reminder_popup_timer:stop()
		friendly_reminder_popup_timer = nil
	end

	if friendly_reminder_canvas ~= nil then
		friendly_reminder_canvas:hide(0)
		friendly_reminder_canvas:delete()
		friendly_reminder_canvas = nil
	end
end

local function destroy_overlays()
	for _, canvas in pairs(overlays) do
		canvas:hide(0)
		canvas:delete()
	end

	overlays = {}
end

local function clear_active_runtime(clear_break_cycle)
	stop_work_timer()
	stop_break_timer()
	stop_friendly_reminder_timer()
	stop_input_blocker()
	stop_resume_input_watcher()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	frontmost_app = nil
	waiting_for_resume_input = false

	if clear_break_cycle ~= false then
		break_ends_at = nil
		next_break_at = nil
		work_cycle_started_at = nil
	end
end

local function restore_frontmost_app()
	if not is_soft_mode() or frontmost_app == nil then
		return
	end

	hs.timer.doAfter(
		0,
		function()
			if break_ends_at == nil or frontmost_app == nil then
				return
			end

			pcall(
				function()
					frontmost_app:activate()
				end
			)
		end
	)
end

local function create_overlay(screen, remaining_seconds)
	local frame = screen:fullFrame()
	local canvas = hs.canvas.new(frame)

	canvas:behaviorAsLabels({
		"canJoinAllSpaces",
		"fullScreenAuxiliary",
		"stationary",
		"ignoresCycle",
	})
	canvas:clickActivating(false)
	canvas:level(hs.canvas.windowLevels.screenSaver)
	canvas:appendElements(
		{
			id = "background",
			type = "rectangle",
			action = "fill",
			fillColor = overlay_background(),
			frame = {
				x = 0,
				y = 0,
				w = frame.w,
				h = frame.h,
			},
		}
	)

	if state.minimal_display then
		local icon = style_icon_text("☕️", math.floor(math.min(frame.w, frame.h) * 0.22))
		local icon_height = canvas:minimumTextSize(icon).h

		append_centered_text(canvas, "icon", icon, math.floor((frame.h - icon_height) / 2))
		canvas:show(0)
		return canvas
	end

	local title = style_text("休息时间", 40, title_color)
	local countdown = style_text(format_seconds(remaining_seconds), 72, countdown_color)
	local description = style_text(
		string.format(
			"你已经连续工作 %s\n请离开屏幕休息 %s",
			format_duration(state.work_seconds),
			format_duration(state.rest_seconds)
		),
		24,
		description_color
	)
	local hint = style_text(overlay_hint(), 18, hint_color)

	append_centered_text(canvas, "title", title, math.floor(frame.h * 0.24))
	append_centered_text(canvas, "countdown", countdown, math.floor(frame.h * 0.40))
	append_centered_text(canvas, "description", description, math.floor(frame.h * 0.58))
	append_centered_text(canvas, "hint", hint, math.floor(frame.h * 0.74))

	canvas:show(0)

	return canvas
end

local function render_overlays(remaining_seconds)
	destroy_overlays()

	for _, screen in ipairs(hs.screen.allScreens()) do
		table.insert(overlays, create_overlay(screen, remaining_seconds))
	end

	restore_frontmost_app()
end

local function update_overlays(remaining_seconds)
	if next(overlays) == nil then
		render_overlays(remaining_seconds)
		return
	end

	if state.minimal_display then
		return
	end

	local countdown = style_text(format_seconds(remaining_seconds), 72, countdown_color)

	for _, canvas in pairs(overlays) do
		canvas["countdown"].text = countdown
	end
end

local function can_resume_after_inactive_session()
	local session_properties = hs.caffeinate.sessionProperties()

	if session_properties == nil then
		return true
	end

	local is_locked = session_properties.CGSSessionScreenIsLocked

	if is_locked == true or is_locked == 1 then
		return false
	end

	local is_on_console = session_properties.kCGSSessionOnConsoleKey

	if is_on_console == false or is_on_console == 0 then
		return false
	end

	return true
end

stop_inactive_resume_timer = function()
	if inactive_resume_timer == nil then
		return
	end

	inactive_resume_timer:stop()
	inactive_resume_timer = nil
end

start_inactive_resume_timer = function()
	if inactive_resume_timer ~= nil then
		return
	end

	inactive_resume_timer = hs.timer.doEvery(
		1,
		function()
			if try_resume_after_inactive_session ~= nil then
				try_resume_after_inactive_session("inactive resume retry timer")
			end

			if session_is_inactive ~= true then
				stop_inactive_resume_timer()
			end
		end
	)
end

local function current_status()
	if state.enabled ~= true then
		return "已关闭", "提醒未启用"
	end

	if session_is_inactive == true then
		return "会话未激活", "锁屏或睡眠期间不会累计工作时长"
	end

	if waiting_for_resume_input == true then
		return "等待输入", "休息已结束，首次键盘或鼠标输入后开始下一轮工作计时"
	end

	if break_ends_at ~= nil then
		local remaining_seconds = math.max(0, break_ends_at - os.time())

		return "休息中", string.format("距离结束还有 %s", format_seconds(remaining_seconds))
	end

	if next_break_at ~= nil then
		local remaining_seconds = math.max(0, next_break_at - os.time())

		return "工作中", string.format("距离下一次休息还有 %s", format_duration(remaining_seconds))
	end

	return "待机中", "等待开始新的工作计时"
end

local function menubar_visual_state()
	if state.enabled ~= true then
		return {
			progress = nil,
			progress_color = menubar_disabled_color,
			icon_color = menubar_disabled_color,
		}
	end

	if session_is_inactive == true then
		return {
			progress = nil,
			progress_color = menubar_paused_color,
			icon_color = menubar_paused_color,
		}
	end

	if waiting_for_resume_input == true then
		return {
			progress = nil,
			progress_color = menubar_waiting_color,
			icon_color = menubar_waiting_color,
		}
	end

	if break_ends_at ~= nil then
		local remaining_seconds = math.max(0, break_ends_at - os.time())
		local progress = 0

		if state.rest_seconds > 0 then
			progress = clamp_number(remaining_seconds / state.rest_seconds, 0, 1)
		end

		return {
			progress = state.show_progress_in_menubar and progress or nil,
			progress_color = menubar_active_color,
			icon_color = menubar_active_color,
		}
	end

	if next_break_at ~= nil and work_cycle_started_at ~= nil and state.work_seconds > 0 then
		local elapsed_seconds = clamp_number(os.time() - work_cycle_started_at, 0, state.work_seconds)
		local progress = clamp_number(elapsed_seconds / state.work_seconds, 0, 1)

		return {
			progress = state.show_progress_in_menubar and progress or nil,
			progress_color = menubar_active_color,
			icon_color = menubar_active_color,
		}
	end

	return {
		progress = nil,
		progress_color = menubar_active_color,
		icon_color = menubar_active_color,
	}
end

local function circle_path_coordinates(progress, center_x, center_y, radius)
	if progress == nil or progress <= 0 then
		return nil
	end

	local steps = math.max(8, math.ceil(56 * progress))
	local coordinates = {}
	local start_radians = -math.pi / 2
	local end_radians = start_radians + (math.pi * 2 * progress)

	for index = 0, steps do
		local ratio = index / steps
		local angle = start_radians + ((end_radians - start_radians) * ratio)

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
	local visual_state = menubar_visual_state()
	local canvas = hs.canvas.new({
		x = 0,
		y = 0,
		w = menubar_canvas_size,
		h = menubar_canvas_size,
	})
	local center_x = menubar_canvas_size / 2
	local center_y = menubar_canvas_size / 2
	local ring_radius = 15.0
	local ring_width = 1.9
	local show_progress_ring = state.show_progress_in_menubar == true
	local cup_color = visual_state.icon_color
	local icon_scale = show_progress_ring and 1.08 or 1.24
	local icon_offset_x = show_progress_ring and 0 or 0.2
	local icon_offset_y = show_progress_ring and 0.15 or 0.35

	local function transform_coordinates(coordinates)
		local transformed = {}

		for _, point in ipairs(coordinates) do
			table.insert(
				transformed,
				{
					x = center_x + ((point.x - center_x) * icon_scale) + icon_offset_x,
					y = center_y + ((point.y - center_y) * icon_scale) + icon_offset_y,
				}
			)
		end

		return transformed
	end

	local elements = {}

	if show_progress_ring == true then
		table.insert(
			elements,
			{
				type = "circle",
				action = "stroke",
				center = { x = center_x, y = center_y },
				radius = ring_radius,
				strokeWidth = ring_width,
				strokeColor = menubar_track_color,
			}
		)
	end

	table.insert(
		elements,
			{
				type = "segments",
				action = "stroke",
				closed = false,
				strokeWidth = show_progress_ring and 1.85 or 1.95,
				strokeCapStyle = "round",
				strokeJoinStyle = "round",
				strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 11.6, y = 16.6 },
				{ x = 11.6, y = 23.3 },
				{ x = 13.1, y = 25.1 },
				{ x = 20.8, y = 25.1 },
				{ x = 22.3, y = 23.3 },
				{ x = 22.3, y = 16.6 },
			}),
		}
	)
	table.insert(
		elements,
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = show_progress_ring and 1.75 or 1.85,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 12.5, y = 16.3 },
				{ x = 21.4, y = 16.3 },
			}),
		}
	)
	table.insert(
		elements,
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = show_progress_ring and 1.85 or 1.95,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 22.2, y = 17.9 },
				{ x = 24.9, y = 18.1 },
				{ x = 25.5, y = 20.7 },
				{ x = 24.9, y = 23.2 },
				{ x = 22.1, y = 23.4 },
			}),
		}
	)
	table.insert(
		elements,
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = show_progress_ring and 1.45 or 1.55,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 14.2, y = 12.8 },
				{ x = 13.3, y = 11.2 },
				{ x = 14.4, y = 9.8 },
				{ x = 13.8, y = 8.5 },
			}),
		}
	)
	table.insert(
		elements,
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = show_progress_ring and 1.45 or 1.55,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 18.9, y = 12.5 },
				{ x = 18.0, y = 10.9 },
				{ x = 19.0, y = 9.5 },
				{ x = 18.5, y = 8.2 },
			}),
		}
	)
	table.insert(
		elements,
		{
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = show_progress_ring and 1.6 or 1.75,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = cup_color,
			coordinates = transform_coordinates({
				{ x = 10.4, y = 27.9 },
				{ x = 24.3, y = 27.9 },
			}),
		}
	)

	canvas:appendElements(table.unpack(elements))

	if show_progress_ring == true and visual_state.progress ~= nil and visual_state.progress > 0 then
		canvas:appendElements(
			{
				type = "segments",
				action = "stroke",
				closed = false,
				strokeWidth = ring_width,
				strokeCapStyle = "round",
				strokeColor = visual_state.progress_color,
				coordinates = circle_path_coordinates(visual_state.progress, center_x, center_y, ring_radius),
			}
		)
	end

	local icon = canvas:imageFromCanvas()

	canvas:delete()

	if icon == nil then
		return nil
	end

	icon:size({ w = menubar_icon_size, h = menubar_icon_size }, true)

	return icon
end

update_menubar_status = function()
	if menubar_item == nil then
		return
	end

	local status_title, status_detail = current_status()
	local icon = build_menubar_icon()

	menubar_item:setTitle(nil)

	if icon ~= nil then
		menubar_item:setIcon(icon, true)
	else
		menubar_item:setIcon(nil)
		menubar_item:setTitle(state.menubar_title)
	end

	menubar_item:setTooltip(
		string.format(
			"Break Reminder\n状态: %s\n%s\n模式: %s | 工作: %s | 休息: %s | 下一轮: %s",
			status_title,
			status_detail,
			mode_label(state.mode),
			format_minutes(state.work_seconds),
			format_duration(state.rest_seconds),
			start_next_cycle_label(state.start_next_cycle)
		)
	)
end

local function start_menubar_status_timer()
	if menubar_item == nil or menubar_status_timer ~= nil then
		return
	end

	menubar_status_timer = hs.timer.doEvery(
		1,
		function()
			update_menubar_status()
		end
	)
end

local function stop_menubar_status_timer()
	if menubar_status_timer == nil then
		return
	end

	menubar_status_timer:stop()
	menubar_status_timer = nil
end

local function persist_runtime_overrides()
	if table_is_empty(runtime_overrides) then
		hs.settings.clear(settings_key)
		return
	end

	hs.settings.set(settings_key, runtime_overrides)
end

local function changes_require_schedule_restart(changes)
	for key, _ in pairs(changes or {}) do
		if key == "enabled" or key == "work_minutes" or key == "friendly_reminder_seconds" then
			return true
		end
	end

	return false
end

local function show_friendly_reminder()
	if state.enabled ~= true then
		return
	end

	if state.friendly_reminder_seconds <= 0 or state.friendly_reminder_seconds >= state.work_seconds then
		return
	end

	local message = render_template(
		state.friendly_reminder_message,
		{
			remaining = format_duration(state.friendly_reminder_seconds),
			remaining_seconds = state.friendly_reminder_seconds,
			remaining_mmss = format_seconds(state.friendly_reminder_seconds),
			rest = format_duration(state.rest_seconds),
			rest_seconds = state.rest_seconds,
			rest_mmss = format_seconds(state.rest_seconds),
		}
	)

	log.i(string.format("friendly reminder shown, remaining_seconds=%d", state.friendly_reminder_seconds))

	local target_screen = nil
	local focused_window = hs.window.focusedWindow()

	if focused_window ~= nil then
		target_screen = focused_window:screen()
	end

	if target_screen == nil then
		target_screen = hs.screen.mainScreen()
	end

	local screen_frame = target_screen:frame()
	local margin = 24
	local close_button_size = 18
	local body_style = style_text(message, 16, reminder_text_color)
	local measurement_canvas = hs.canvas.new({ x = 0, y = 0, w = 10, h = 10 })
	local text_size = measurement_canvas:minimumTextSize(body_style)

	measurement_canvas:delete()

	local popup_width = math.min(math.max(text_size.w + 64, 280), 420)
	local popup_height = math.max(text_size.h + 34, 88)
	local popup_x = screen_frame.x + screen_frame.w - popup_width - margin
	local popup_y = screen_frame.y + margin

	destroy_friendly_reminder_popup()

	friendly_reminder_canvas = hs.canvas.new({
		x = popup_x,
		y = popup_y,
		w = popup_width,
		h = popup_height,
	})

	friendly_reminder_canvas:behaviorAsLabels({
		"canJoinAllSpaces",
		"fullScreenAuxiliary",
		"stationary",
		"ignoresCycle",
	})
	friendly_reminder_canvas:clickActivating(false)
	friendly_reminder_canvas:level(hs.canvas.windowLevels.screenSaver)
	friendly_reminder_canvas:appendElements(
		{
			id = "background",
			type = "rectangle",
			action = "strokeAndFill",
			roundedRectRadii = { xRadius = 12, yRadius = 12 },
			fillColor = reminder_background_color,
			strokeColor = reminder_border_color,
			strokeWidth = 1.2,
			frame = {
				x = 0,
				y = 0,
				w = popup_width,
				h = popup_height,
			},
		},
		{
			id = "message",
			type = "text",
			text = body_style,
			frame = {
				x = 20,
				y = 18,
				w = popup_width - 56,
				h = popup_height - 30,
			},
		},
		{
			id = "close_button",
			type = "text",
			text = style_text("×", 18, reminder_close_color),
			frame = {
				x = popup_width - close_button_size - 14,
				y = 10,
				w = close_button_size,
				h = close_button_size,
			},
			trackMouseUp = true,
			trackMouseByBounds = true,
		}
	)
	friendly_reminder_canvas:mouseCallback(function(_, callback_message, element_id)
		if callback_message == "mouseUp" and element_id == "close_button" then
			destroy_friendly_reminder_popup()
		end
	end)
	friendly_reminder_canvas:show(0)

	if state.friendly_reminder_duration_seconds > 0 then
		friendly_reminder_popup_timer = hs.timer.doAfter(
			state.friendly_reminder_duration_seconds,
			function()
				destroy_friendly_reminder_popup()
			end
		)
	end
end

finish_break = function()
	stop_break_timer()
	stop_input_blocker()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	break_ends_at = nil
	frontmost_app = nil
	log.i("break finished")

	if state.enabled == true and session_is_inactive ~= true then
		if state.start_next_cycle == "on_input" then
			waiting_for_resume_input = true

			if start_resume_input_watcher() ~= true then
				waiting_for_resume_input = false
				schedule_next_break("break finished fallback to auto")
				return
			end

			update_menubar_status()
		else
			schedule_next_break("break finished")
		end
	else
		next_break_at = nil
		work_cycle_started_at = nil
		update_menubar_status()
	end
end

start_break = function(reason)
	if state.enabled ~= true then
		return
	end

	stop_work_timer()
	stop_resume_input_watcher()
	stop_friendly_reminder_timer()
	destroy_friendly_reminder_popup()
	waiting_for_resume_input = false
	next_break_at = nil
	work_cycle_started_at = nil
	break_ends_at = os.time() + state.rest_seconds
	frontmost_app = nil

	if is_soft_mode() then
		frontmost_app = hs.application.frontmostApplication()
	end

	log.i(string.format("break started, mode=%s, reason=%s", state.mode, tostring(reason)))
	render_overlays(state.rest_seconds)
	start_input_blocker()
	update_menubar_status()

	stop_break_timer()
	break_timer = hs.timer.doEvery(
		1,
		function()
			local remaining_seconds = break_ends_at - os.time()

			if remaining_seconds <= 0 then
				finish_break()
				return
			end

			update_overlays(remaining_seconds)
			update_menubar_status()
		end
	)
end

schedule_next_break = function(reason)
	if state.enabled ~= true or session_is_inactive == true then
		return
	end

	stop_work_timer()
	stop_break_timer()
	stop_input_blocker()
	stop_resume_input_watcher()
	stop_friendly_reminder_timer()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	break_ends_at = nil
	frontmost_app = nil
	waiting_for_resume_input = false
	work_cycle_started_at = os.time()
	next_break_at = work_cycle_started_at + state.work_seconds

	if state.friendly_reminder_seconds > 0 and state.friendly_reminder_seconds < state.work_seconds then
		friendly_reminder_timer = hs.timer.doAfter(
			state.work_seconds - state.friendly_reminder_seconds,
			function()
				friendly_reminder_timer = nil

				if break_ends_at ~= nil or state.enabled ~= true then
					return
				end

				show_friendly_reminder()
			end
		)
	elseif state.friendly_reminder_seconds >= state.work_seconds then
		log.w("friendly reminder is not scheduled because it is greater than or equal to work duration")
	end

	work_timer = hs.timer.doAfter(
		state.work_seconds,
		function()
			work_timer = nil
			next_break_at = nil
			start_break(reason or "work timer reached")
		end
	)

	log.i(string.format("break scheduled in %d seconds, reason=%s", state.work_seconds, tostring(reason)))
	update_menubar_status()
end

try_resume_after_inactive_session = function(reason)
	if session_is_inactive ~= true then
		stop_inactive_resume_timer()
		return false
	end

	if can_resume_after_inactive_session() ~= true then
		return false
	end

	session_is_inactive = false
	stop_inactive_resume_timer()
	log.i(string.format("break timer restarted after wake/unlock, reason=%s", tostring(reason)))

	if state.enabled == true then
		schedule_next_break(reason or "resume after inactive session")
	else
		update_menubar_status()
	end

	return true
end

restart_work_cycle = function(reason)
	if state.enabled ~= true then
		clear_active_runtime(true)
		update_menubar_status()
		return
	end

	if session_is_inactive == true then
		clear_active_runtime(true)
		update_menubar_status()
		return
	end

	schedule_next_break(reason or "manual reset")
end

local function reset_cycle_for_inactive_session(reason)
	clear_active_runtime(true)
	session_is_inactive = true
	start_inactive_resume_timer()
	log.i(string.format("break timer reset because session became inactive: %s", reason))
	update_menubar_status()
end

apply_current_configuration = function(reason, schedule_should_restart)
	state = normalize_config(merged_config(runtime_overrides))
	refresh_menubar()

	if state.enabled ~= true then
		clear_active_runtime(true)
		update_menubar_status()
		return
	end

	if session_is_inactive == true then
		clear_active_runtime(true)
		update_menubar_status()
		return
	end

	if break_ends_at ~= nil then
		local remaining_seconds = break_ends_at - os.time()

		if remaining_seconds <= 0 then
			finish_break()
			return
		end

		if is_hard_mode() then
			start_input_blocker()
		else
			stop_input_blocker()
		end

		render_overlays(remaining_seconds)
		update_menubar_status()
		log.i(string.format("break configuration reapplied during active break, reason=%s", tostring(reason)))
		return
	end

	if waiting_for_resume_input == true then
		if state.start_next_cycle == "auto" then
			waiting_for_resume_input = false
			stop_resume_input_watcher()
			schedule_next_break(reason or "configuration updated from waiting")
		else
			if start_resume_input_watcher() ~= true then
				waiting_for_resume_input = false
				schedule_next_break(reason or "configuration updated fallback to auto")
			else
				update_menubar_status()
			end
		end

		return
	end

	if schedule_should_restart == true or next_break_at == nil then
		schedule_next_break(reason or "configuration updated")
	else
		update_menubar_status()
	end
end

update_runtime_overrides = function(changes, reason)
	local schedule_should_restart = changes_require_schedule_restart(changes)

	for key, value in pairs(changes or {}) do
		if base_config[key] == value then
			runtime_overrides[key] = nil
		else
			runtime_overrides[key] = value
		end
	end

	persist_runtime_overrides()
	apply_current_configuration(reason, schedule_should_restart)
end

clear_runtime_overrides = function(reason)
	runtime_overrides = {}
	persist_runtime_overrides()
	apply_current_configuration(reason or "runtime overrides cleared", true)
end

local function show_message(message)
	hs.alert.show(message)
end

local function read_file(path)
	local file, open_error = io.open(path, "r")

	if file == nil then
		return nil, open_error
	end

	local content = file:read("*a")

	file:close()

	return content
end

local function write_file(path, content)
	local file, open_error = io.open(path, "w")

	if file == nil then
		return nil, open_error
	end

	local _, write_error = file:write(content)

	file:close()

	if write_error ~= nil then
		return nil, write_error
	end

	return true
end

local function keybindings_config_path()
	local path = package.searchpath("keybindings_config", package.path)

	if path ~= nil then
		return path
	end

	if hs.configdir ~= nil then
		return hs.configdir .. "/keybindings_config.lua"
	end

	return nil
end

local function exportable_config()
	return {
		enabled = state.enabled,
		show_menubar = state.show_menubar,
		show_progress_in_menubar = state.show_progress_in_menubar,
		start_next_cycle = state.start_next_cycle,
		mode = state.mode,
		overlay_opacity = state.overlay_opacity,
		minimal_display = state.minimal_display,
		friendly_reminder_message = state.friendly_reminder_message,
		friendly_reminder_duration_seconds = state.friendly_reminder_duration_seconds,
		friendly_reminder_seconds = state.friendly_reminder_seconds,
		work_minutes = state.work_seconds / 60,
		rest_seconds = state.rest_seconds,
	}
end

local function render_break_reminder_config_block(config)
	return table.concat(
		{
			"_M.break_reminder = {",
			"\tenabled = " .. serialize_lua_value(config.enabled) .. ",",
			"\t-- 是否显示菜单栏图标, 可通过菜单直接调整提醒配置",
			"\tshow_menubar = " .. serialize_lua_value(config.show_menubar) .. ",",
			"\t-- 是否在菜单栏图标中直接显示进度",
			"\tshow_progress_in_menubar = " .. serialize_lua_value(config.show_progress_in_menubar) .. ",",
			"\t-- 休息结束后如何开始下一轮工作计时: \"auto\" 或 \"on_input\"",
			"\tstart_next_cycle = " .. serialize_lua_value(config.start_next_cycle) .. ",",
			"\t-- 可选: \"soft\" 或 \"hard\"",
			"\t-- soft: 显示半透明遮罩但不抢占鼠标和键盘",
			"\t-- hard: 显示遮罩并明确拦截鼠标和键盘",
			"\tmode = " .. serialize_lua_value(config.mode) .. ",",
			"\t-- 遮罩透明度, 范围 0~1",
			"\t-- 默认值: soft=0.32, hard=0.96",
			"\toverlay_opacity = " .. serialize_lua_value(config.overlay_opacity) .. ",",
			"\t-- true 时仅显示简洁图标，不显示倒计时和说明文字",
			"\tminimal_display = " .. serialize_lua_value(config.minimal_display) .. ",",
			"\t-- 友好提示文案模板",
			"\t-- 可用占位符: {{remaining}} {{remaining_seconds}} {{remaining_mmss}} {{rest}} {{rest_seconds}} {{rest_mmss}}",
			"\tfriendly_reminder_message = " .. serialize_lua_value(config.friendly_reminder_message) .. ",",
			"\t-- 友好提示默认停留秒数, 0 表示不自动关闭, 只允许手动点 x 关闭",
			"\tfriendly_reminder_duration_seconds = " .. serialize_lua_value(config.friendly_reminder_duration_seconds) .. ",",
			"\t-- 距离休息还有多少秒时做一次友好提示, 0 为禁用",
			"\tfriendly_reminder_seconds = " .. serialize_lua_value(config.friendly_reminder_seconds) .. ",",
			"\t-- 单位: 分钟",
			"\twork_minutes = " .. serialize_lua_value(config.work_minutes) .. ",",
			"\t-- 单位: 秒",
			"\trest_seconds = " .. serialize_lua_value(config.rest_seconds) .. ",",
			"}",
		},
		"\n"
	)
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

local function prompt_number(message, informative_text, default_value, minimum_value, maximum_value)
	local raw_value = prompt_text(message, informative_text, tostring(default_value or ""))

	if raw_value == nil then
		return nil
	end

	local number = tonumber(raw_value)

	if number == nil then
		show_message("请输入有效数字")
		return nil
	end

	if minimum_value ~= nil and number < minimum_value then
		show_message(string.format("请输入不小于 %s 的数值", tostring(minimum_value)))
		return nil
	end

	if maximum_value ~= nil and number > maximum_value then
		show_message(string.format("请输入不大于 %s 的数值", tostring(maximum_value)))
		return nil
	end

	return number
end

export_current_config_to_file = function()
	local config_path = keybindings_config_path()

	if config_path == nil then
		show_message("未找到 keybindings_config.lua")
		return
	end

	local content, read_error = read_file(config_path)

	if content == nil then
		show_message(string.format("读取配置文件失败: %s", tostring(read_error)))
		return
	end

	local replacement = render_break_reminder_config_block(exportable_config())
	local updated_content, replaced_count = content:gsub(
		"_M%.break_reminder%s*=%s*%b{}",
		function()
			return replacement
		end,
		1
	)

	if replaced_count ~= 1 then
		show_message("导出失败: 未找到 _M.break_reminder 配置块")
		return
	end

	local _, write_error = write_file(config_path, updated_content)

	if write_error ~= nil then
		show_message(string.format("写入配置文件失败: %s", tostring(write_error)))
		return
	end

	runtime_overrides = {}
	hs.settings.clear(settings_key)
	show_message("已导出到 keybindings_config.lua，正在重载配置")
	hs.timer.doAfter(
		0.3,
		function()
			hs.reload()
		end
	)
end

local function menu_item_set_work_minutes(minutes)
	update_runtime_overrides(
		{
			work_minutes = minutes,
		},
		string.format("工作时长已更新为 %s", format_minutes(math.floor(minutes * 60)))
	)
end

local function menu_item_set_rest_seconds(seconds)
	update_runtime_overrides(
		{
			rest_seconds = seconds,
		},
		string.format("休息时长已更新为 %s", format_duration(seconds))
	)
end

local function menu_item_set_friendly_reminder_seconds(seconds)
	update_runtime_overrides(
		{
			friendly_reminder_seconds = seconds,
		},
		seconds <= 0 and "已关闭友好提醒" or string.format("友好提醒已调整为提前 %s", format_duration(seconds))
	)
end

local function menu_item_set_friendly_reminder_duration(seconds)
	update_runtime_overrides(
		{
			friendly_reminder_duration_seconds = seconds,
		},
		seconds <= 0 and "友好提醒已改为手动关闭" or string.format("友好提醒停留时长已更新为 %s", format_duration(seconds))
	)
end

local function menu_item_set_overlay_opacity(opacity)
	update_runtime_overrides(
		{
			overlay_opacity = opacity,
		},
		string.format("遮罩透明度已更新为 %s", format_decimal(opacity))
	)
end

local function menu_item_set_minimal_display(minimal_display)
	if state.minimal_display == minimal_display then
		return
	end

	update_runtime_overrides(
		{
			minimal_display = minimal_display,
		},
		minimal_display and "已切换为仅显示咖啡图标" or "已切换为显示丰富信息"
	)
end

local function build_work_duration_menu()
	local current_minutes = state.work_seconds / 60
	local menu = {
		{ title = string.format("当前: %s", format_minutes(state.work_seconds)), disabled = true },
	}
	local presets = { 25, 28, 30, 45, 50 }

	for _, minutes in ipairs(presets) do
		table.insert(
			menu,
			{
				title = string.format("%s", format_minutes(minutes * 60)),
				checked = math.abs(current_minutes - minutes) < 0.001,
				fn = function()
					menu_item_set_work_minutes(minutes)
				end,
			}
		)
	end

	table.insert(
		menu,
		{
			title = "自定义...",
			fn = function()
				local minutes = prompt_number(
					"工作时长",
					"请输入工作时长，单位为分钟，可输入小数，例如 28.5",
					format_decimal(current_minutes),
					1,
					nil
				)

				if minutes == nil then
					return
				end

				menu_item_set_work_minutes(minutes)
			end,
		}
	)

	return menu
end

local function build_rest_duration_menu()
	local menu = {
		{ title = string.format("当前: %s", format_duration(state.rest_seconds)), disabled = true },
	}
	local presets = { 60, 120, 300, 600 }

	for _, seconds in ipairs(presets) do
		table.insert(
			menu,
			{
				title = format_duration(seconds),
				checked = state.rest_seconds == seconds,
				fn = function()
					menu_item_set_rest_seconds(seconds)
				end,
			}
		)
	end

	table.insert(
		menu,
		{
			title = "自定义...",
			fn = function()
				local seconds = prompt_number(
					"休息时长",
					"请输入休息时长，单位为秒",
					state.rest_seconds,
					1,
					nil
				)

				if seconds == nil then
					return
				end

				menu_item_set_rest_seconds(math.floor(seconds))
			end,
		}
	)

	return menu
end

local function build_overlay_menu()
	local menu = {
		{
			title = state.minimal_display and "当前样式: 仅显示咖啡图标" or "当前样式: 丰富信息",
			disabled = true,
		},
		{
			title = "显示丰富信息",
			checked = not state.minimal_display,
			fn = function()
				menu_item_set_minimal_display(false)
			end,
		},
		{
			title = "仅显示咖啡图标",
			checked = state.minimal_display,
			fn = function()
				menu_item_set_minimal_display(true)
			end,
		},
		{ title = "-" },
		{
			title = string.format("当前透明度: %s", format_decimal(state.overlay_opacity)),
			disabled = true,
		},
	}
	local presets = { 0.20, 0.32, 0.50, 0.80, 0.96 }

	for _, opacity in ipairs(presets) do
		table.insert(
			menu,
			{
				title = format_decimal(opacity),
				checked = math.abs(state.overlay_opacity - opacity) < 0.001,
				fn = function()
					menu_item_set_overlay_opacity(opacity)
				end,
			}
		)
	end

	table.insert(
		menu,
		{
			title = "自定义透明度...",
			fn = function()
				local opacity = prompt_number(
					"遮罩透明度",
					"请输入 0 到 1 之间的数值，例如 0.32",
					format_decimal(state.overlay_opacity),
					0,
					1
				)

				if opacity == nil then
					return
				end

				menu_item_set_overlay_opacity(opacity)
			end,
		}
	)

	return menu
end

local function build_friendly_reminder_menu()
	local current_duration = state.friendly_reminder_duration_seconds
	local duration_label = current_duration <= 0 and "手动关闭" or format_duration(current_duration)
	local menu = {
		{
			title = state.friendly_reminder_seconds <= 0
				and "当前提前提醒: 已关闭"
				or string.format("当前提前提醒: %s", format_duration(state.friendly_reminder_seconds)),
			disabled = true,
		},
	}
	local reminder_presets = { 0, 60, 120, 300 }

	for _, seconds in ipairs(reminder_presets) do
		local title = seconds == 0 and "关闭提前提醒" or string.format("提前 %s", format_duration(seconds))

		table.insert(
			menu,
			{
				title = title,
				checked = state.friendly_reminder_seconds == seconds,
				fn = function()
					menu_item_set_friendly_reminder_seconds(seconds)
				end,
			}
		)
	end

	table.insert(
		menu,
		{
			title = "自定义提前提醒...",
			fn = function()
				local seconds = prompt_number(
					"友好提醒",
					"请输入距离休息开始前多少秒显示友好提醒，0 表示关闭",
					state.friendly_reminder_seconds,
					0,
					nil
				)

				if seconds == nil then
					return
				end

				menu_item_set_friendly_reminder_seconds(math.floor(seconds))
			end,
		}
	)

	table.insert(menu, { title = "-" })
	table.insert(
		menu,
		{
			title = string.format("当前停留时长: %s", duration_label),
			disabled = true,
		}
	)

	local duration_presets = { 0, 5, 10, 15 }

	for _, seconds in ipairs(duration_presets) do
		local title = seconds == 0 and "手动关闭" or format_duration(seconds)

		table.insert(
			menu,
			{
				title = title,
				checked = math.abs(current_duration - seconds) < 0.001,
				fn = function()
					menu_item_set_friendly_reminder_duration(seconds)
				end,
			}
		)
	end

	table.insert(
		menu,
		{
			title = "自定义停留时长...",
			fn = function()
				local seconds = prompt_number(
					"友好提醒停留时长",
					"请输入提醒弹窗显示秒数，0 表示不自动关闭",
					current_duration,
					0,
					nil
				)

				if seconds == nil then
					return
				end

				menu_item_set_friendly_reminder_duration(seconds)
			end,
		}
	)

	table.insert(menu, { title = "-" })
	table.insert(
		menu,
		{
			title = "编辑提示文案...",
			fn = function()
				local message = prompt_text(
					"友好提醒文案",
					"可用占位符: {{remaining}} {{remaining_seconds}} {{remaining_mmss}} {{rest}} {{rest_seconds}} {{rest_mmss}}",
					state.friendly_reminder_message
				)

				if message == nil then
					return
				end

				if message == "" then
					show_message("提示文案不能为空")
					return
				end

				update_runtime_overrides(
					{
						friendly_reminder_message = message,
					},
					"友好提醒文案已更新"
				)
			end,
		}
	)

	return menu
end

local function build_mode_menu()
	return {
		{
			title = "柔性提醒",
			checked = state.mode == "soft",
			fn = function()
				update_runtime_overrides(
					{
						mode = "soft",
					},
					"已切换为柔性提醒模式"
				)
			end,
		},
		{
			title = "硬性提醒",
			checked = state.mode == "hard",
			fn = function()
				update_runtime_overrides(
					{
						mode = "hard",
					},
					"已切换为硬性提醒模式"
				)
			end,
		},
	}
end

local function build_start_next_cycle_menu()
	return {
		{
			title = "休息结束立即开始",
			checked = state.start_next_cycle == "auto",
			fn = function()
				update_runtime_overrides(
					{
						start_next_cycle = "auto",
					},
					"已切换为休息结束立即开始下一轮工作计时"
				)
			end,
		},
		{
			title = "首次输入后开始",
			checked = state.start_next_cycle == "on_input",
			fn = function()
				update_runtime_overrides(
					{
						start_next_cycle = "on_input",
					},
					"已切换为休息结束后等待首次输入再开始"
				)
			end,
		},
	}
end

local function menu_status_detail()
	if state.enabled ~= true then
		return "提醒未启用"
	end

	if session_is_inactive == true then
		return "锁屏/睡眠中"
	end

	if waiting_for_resume_input == true then
		return "等待首次输入"
	end

	if break_ends_at ~= nil then
		return string.format("休息剩余: %s", format_seconds(math.max(0, break_ends_at - os.time())))
	end

	if next_break_at ~= nil then
		return string.format("下次休息: %s", format_seconds(math.max(0, next_break_at - os.time())))
	end

	return "等待新一轮计时"
end

local function menu_config_summary()
	return string.format(
		"%s | 工%s | 休%s",
		short_mode_label(state.mode),
		format_compact_duration(state.work_seconds),
		format_compact_duration(state.rest_seconds)
	)
end

local function menu_config_source_label()
	if table_is_empty(runtime_overrides) then
		return "配置: 文件"
	end

	return "配置: 文件+菜单"
end

local function build_menu()
	local status_title, status_detail = current_status()

	return {
		{ title = "休息提醒", disabled = true },
		{ title = string.format("状态: %s", status_title), disabled = true },
		{ title = menu_status_detail(), disabled = true },
		{
			title = menu_config_summary(),
			disabled = true,
		},
		{ title = "下一轮: " .. short_start_next_cycle_label(state.start_next_cycle), disabled = true },
		{
			title = menu_config_source_label(),
			disabled = true,
		},
		{ title = "-" },
			{
				title = "启用提醒",
				checked = state.enabled,
			fn = function()
				local enabled = not state.enabled

				update_runtime_overrides(
					{
						enabled = enabled,
					},
					enabled and "已启用休息提醒" or "已关闭休息提醒"
				)
				end,
			},
			{
				title = "显示进度环",
				checked = state.show_progress_in_menubar,
				disabled = state.show_menubar ~= true,
				fn = function()
					update_runtime_overrides(
						{
							show_progress_in_menubar = not state.show_progress_in_menubar,
						},
						state.show_progress_in_menubar and "已关闭图标进度显示" or "已开启图标进度显示"
					)
				end,
			},
			{
				title = "下一轮启动",
				disabled = state.enabled ~= true,
				menu = build_start_next_cycle_menu(),
			},
			{
				title = "提醒模式",
				disabled = state.enabled ~= true,
			menu = build_mode_menu(),
		},
		{
			title = "工作时长",
			disabled = state.enabled ~= true,
			menu = build_work_duration_menu(),
		},
		{
			title = "休息时长",
			disabled = state.enabled ~= true,
			menu = build_rest_duration_menu(),
		},
		{
			title = "遮罩样式",
			disabled = state.enabled ~= true,
			menu = build_overlay_menu(),
		},
		{
			title = "友好提醒",
			disabled = state.enabled ~= true,
			menu = build_friendly_reminder_menu(),
		},
		{ title = "-" },
		{
			title = "立即休息",
			disabled = state.enabled ~= true or break_ends_at ~= nil,
			fn = function()
				start_break("manual start from menubar")
				show_message("已立即开始休息")
			end,
		},
		{
			title = "重置计时",
			disabled = state.enabled ~= true,
			fn = function()
				restart_work_cycle("manual reset from menubar")
				show_message("已重新开始工作计时")
			end,
		},
		{
			title = "恢复文件配置",
			disabled = table_is_empty(runtime_overrides),
			fn = function()
				clear_runtime_overrides("restore base config")
				show_message("已恢复为 keybindings_config.lua 中的配置")
			end,
		},
		{
			title = "导出到文件",
			fn = function()
				export_current_config_to_file()
			end,
		},
	}
end

refresh_menubar = function()
	if state.show_menubar ~= true then
		stop_menubar_status_timer()

		if menubar_item ~= nil then
			menubar_item:delete()
			menubar_item = nil
		end

		return
	end

	if menubar_item == nil then
		menubar_item = hs.menubar.new()

		if menubar_item == nil then
			log.e("failed to create break reminder menubar item")
			return
		end
	end

	menubar_item:setMenu(build_menu)
	update_menubar_status()
	start_menubar_status_timer()
end

_M.screen_watcher = hs.screen.watcher.new(
	function()
		if break_ends_at == nil then
			return
		end

		local remaining_seconds = break_ends_at - os.time()

		if remaining_seconds <= 0 then
			finish_break()
			return
		end

		render_overlays(remaining_seconds)
		update_menubar_status()
	end
)

_M.screen_watcher:start()

_M.caffeinate_watcher = hs.caffeinate.watcher.new(
	function(event)
		if event == hs.caffeinate.watcher.screensDidLock
			or event == hs.caffeinate.watcher.systemWillSleep
			or event == hs.caffeinate.watcher.sessionDidResignActive then
			reset_cycle_for_inactive_session(tostring(event))
			return
		end

		if event ~= hs.caffeinate.watcher.systemDidWake
			and event ~= hs.caffeinate.watcher.screensDidUnlock
			and event ~= hs.caffeinate.watcher.sessionDidBecomeActive then
			return
		end

		if session_is_inactive ~= true then
			return
		end

		if try_resume_after_inactive_session("caffeinate watcher resume event") ~= true then
			log.i("session is still locked/inactive after wake, waiting for a later retry")
			return
		end
	end
)

_M.caffeinate_watcher:start()

_M.start_break_now = function()
	start_break("manual api start")
end

_M.reset_cycle = function()
	restart_work_cycle("manual api reset")
end

_M.clear_runtime_overrides = function()
	clear_runtime_overrides("manual api clear")
end

_M.export_current_config_to_file = function()
	export_current_config_to_file()
end

_M.get_state = function()
	return {
		enabled = state.enabled,
		show_menubar = state.show_menubar,
		show_progress_in_menubar = state.show_progress_in_menubar,
		start_next_cycle = state.start_next_cycle,
		mode = state.mode,
		minimal_display = state.minimal_display,
		work_seconds = state.work_seconds,
		rest_seconds = state.rest_seconds,
		friendly_reminder_seconds = state.friendly_reminder_seconds,
		friendly_reminder_duration_seconds = state.friendly_reminder_duration_seconds,
		friendly_reminder_message = state.friendly_reminder_message,
		overlay_opacity = state.overlay_opacity,
		break_ends_at = break_ends_at,
		next_break_at = next_break_at,
		work_cycle_started_at = work_cycle_started_at,
		session_is_inactive = session_is_inactive,
		waiting_for_resume_input = waiting_for_resume_input,
		runtime_overrides = shallow_copy(runtime_overrides),
	}
end

if can_resume_after_inactive_session() ~= true then
	session_is_inactive = true
	start_inactive_resume_timer()
end

refresh_menubar()

if state.enabled == true and session_is_inactive ~= true then
	schedule_next_break("module init")
else
	update_menubar_status()
end

return _M
