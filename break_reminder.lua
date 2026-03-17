local _M = {}

_M.name = "break_reminder"
_M.description = "每工作一段时间后强制休息"

local config = require("keybindings_config").break_reminder or {}

if config.enabled == false then
	return _M
end

local log = hs.logger.new("break")
local valid_modes = {
	soft = true,
	hard = true,
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

local work_seconds = math.max(60, math.floor((tonumber(config.work_minutes) or 30) * 60))
local rest_seconds = resolve_integer_seconds(config.rest_seconds, 120, 1)
local mode = tostring(config.mode or "hard"):lower()
local minimal_display = config.minimal_display == true
local friendly_reminder_seconds = resolve_integer_seconds(config.friendly_reminder_seconds, 0, 0)
local friendly_reminder_duration_seconds = resolve_number(config.friendly_reminder_duration_seconds, 1.5, 0)
local friendly_reminder_message = tostring(config.friendly_reminder_message or "还有 {{remaining}} 开始休息")

if valid_modes[mode] ~= true then
	log.w(string.format("invalid break mode: %s, fallback to hard", mode))
	mode = "hard"
end

local background_color = { red = 0.04, green = 0.05, blue = 0.08 }
local title_color = { hex = "#F4F1DE" }
local countdown_color = { hex = "#E9C46A" }
local description_color = { hex = "#D8DEE9" }
local hint_color = { hex = "#9AA5B1" }
local reminder_background_color = { red = 0.10, green = 0.11, blue = 0.15, alpha = 0.96 }
local reminder_border_color = { red = 0.82, green = 0.68, blue = 0.34, alpha = 1 }
local reminder_text_color = { hex = "#F4F1DE" }
local reminder_close_color = { hex = "#E9C46A" }
local font_name = "Monaco"
local icon_font_name = "Apple Color Emoji"

local work_timer = nil
local break_timer = nil
local friendly_reminder_timer = nil
local friendly_reminder_popup_timer = nil
local break_ends_at = nil
local overlays = {}
local frontmost_app = nil
local blocked_event_types = {}
local schedule_next_break = nil
local friendly_reminder_canvas = nil
local style_text = nil
local destroy_friendly_reminder_popup = nil

for _, name in ipairs(blocked_event_type_names) do
	local event_type = hs.eventtap.event.types[name]

	if event_type ~= nil then
		table.insert(blocked_event_types, event_type)
	end
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

local function render_template(template, variables)
	return (template:gsub("{{%s*([%w_]+)%s*}}", function(key)
		local value = variables[key]

		if value == nil then
			return "{{" .. key .. "}}"
		end

		return tostring(value)
	end))
end

local function show_friendly_reminder()
	if friendly_reminder_seconds <= 0 or friendly_reminder_seconds >= work_seconds then
		return
	end

	local message = render_template(
		friendly_reminder_message,
		{
			remaining = format_duration(friendly_reminder_seconds),
			remaining_seconds = friendly_reminder_seconds,
			remaining_mmss = format_seconds(friendly_reminder_seconds),
			rest = format_duration(rest_seconds),
			rest_seconds = rest_seconds,
			rest_mmss = format_seconds(rest_seconds),
		}
	)

	log.i(string.format("friendly reminder shown, remaining_seconds=%d", friendly_reminder_seconds))

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

	if friendly_reminder_duration_seconds > 0 then
		friendly_reminder_popup_timer = hs.timer.doAfter(
			friendly_reminder_duration_seconds,
			function()
				destroy_friendly_reminder_popup()
			end
		)
	end
end

style_text = function(text, size, color)
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
	return mode == "soft"
end

local function is_hard_mode()
	return mode == "hard"
end

local function overlay_background()
	local alpha = 0.96

	if is_soft_mode() then
		alpha = 0.32
	end

	return {
		red = background_color.red,
		green = background_color.green,
		blue = background_color.blue,
		alpha = alpha,
	}
end

local function overlay_hint()
	if is_soft_mode() then
		return "当前为柔性提醒，可继续操作"
	end

	return "当前为硬性强制，键盘和鼠标已锁定"
end

local function destroy_overlays()
	for _, canvas in pairs(overlays) do
		canvas:hide(0)
		canvas:delete()
	end

	overlays = {}
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

	if minimal_display then
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
			format_duration(work_seconds),
			format_duration(rest_seconds)
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

	if minimal_display then
		return
	end

	local countdown = style_text(format_seconds(remaining_seconds), 72, countdown_color)

	for _, canvas in pairs(overlays) do
		canvas["countdown"].text = countdown
	end
end

local function stop_input_blocker()
	if _M.input_blocker == nil then
		return
	end

	_M.input_blocker:stop()
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

local function stop_work_timer()
	if work_timer == nil then
		return
	end

	work_timer:stop()
	work_timer = nil
end

local function finish_break()
	stop_break_timer()
	stop_input_blocker()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	break_ends_at = nil
	frontmost_app = nil
	log.i("break finished")
	schedule_next_break()
end

local function start_break()
	stop_friendly_reminder_timer()
	destroy_friendly_reminder_popup()
	break_ends_at = os.time() + rest_seconds
	frontmost_app = nil

	if is_soft_mode() then
		frontmost_app = hs.application.frontmostApplication()
	end

	log.i(string.format("break started, mode=%s", mode))
	render_overlays(rest_seconds)
	start_input_blocker()

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
		end
	)
end

schedule_next_break = function()
	stop_work_timer()
	stop_friendly_reminder_timer()
	destroy_friendly_reminder_popup()

	if friendly_reminder_seconds > 0 and friendly_reminder_seconds < work_seconds then
		friendly_reminder_timer = hs.timer.doAfter(
			work_seconds - friendly_reminder_seconds,
			function()
				friendly_reminder_timer = nil

				if break_ends_at ~= nil then
					return
				end

				show_friendly_reminder()
			end
		)
	elseif friendly_reminder_seconds >= work_seconds then
		log.w("friendly reminder is not scheduled because it is greater than or equal to work duration")
	end

	work_timer = hs.timer.doAfter(
		work_seconds,
		function()
			work_timer = nil
			start_break()
		end
	)
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
	end
)

_M.screen_watcher:start()

_M.caffeinate_watcher = hs.caffeinate.watcher.new(
	function(event)
		if event ~= hs.caffeinate.watcher.systemDidWake
			and event ~= hs.caffeinate.watcher.screensDidUnlock then
			return
		end

		if break_ends_at ~= nil then
			local remaining_seconds = break_ends_at - os.time()

			if remaining_seconds <= 0 then
				finish_break()
				return
			end

			render_overlays(remaining_seconds)
			start_input_blocker()
			return
		end

		log.i("break timer reset after wake/unlock")
		schedule_next_break()
	end
)

_M.caffeinate_watcher:start()

schedule_next_break()

return _M
