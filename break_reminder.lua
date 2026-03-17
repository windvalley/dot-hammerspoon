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

local work_minutes = tonumber(config.work_minutes) or 30
local rest_minutes = tonumber(config.rest_minutes) or 2
local work_seconds = math.max(60, math.floor(work_minutes * 60))
local rest_seconds = math.max(10, math.floor(rest_minutes * 60))
local mode = tostring(config.mode or "hard"):lower()

if valid_modes[mode] ~= true then
	log.w(string.format("invalid break mode: %s, fallback to hard", mode))
	mode = "hard"
end

local background_color = { red = 0.04, green = 0.05, blue = 0.08 }
local title_color = { hex = "#F4F1DE" }
local countdown_color = { hex = "#E9C46A" }
local description_color = { hex = "#D8DEE9" }
local hint_color = { hex = "#9AA5B1" }
local font_name = "Monaco"

local work_timer = nil
local break_timer = nil
local break_ends_at = nil
local overlays = {}
local frontmost_app = nil
local blocked_event_types = {}
local schedule_next_break = nil

for _, name in ipairs(blocked_event_type_names) do
	local event_type = hs.eventtap.event.types[name]

	if event_type ~= nil then
		table.insert(blocked_event_types, event_type)
	end
end

local function format_number(value)
	if value == math.floor(value) then
		return string.format("%d", value)
	end

	return string.format("%.1f", value)
end

local function format_seconds(total_seconds)
	local minutes = math.floor(total_seconds / 60)
	local seconds = total_seconds % 60

	return string.format("%02d:%02d", minutes, seconds)
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

	local title = style_text("休息时间", 40, title_color)
	local countdown = style_text(format_seconds(remaining_seconds), 72, countdown_color)
	local description = style_text(
		string.format(
			"你已经连续工作 %s 分钟\n请离开屏幕休息 %s 分钟",
			format_number(work_minutes),
			format_number(rest_minutes)
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
	destroy_overlays()
	break_ends_at = nil
	frontmost_app = nil
	log.i("break finished")
	schedule_next_break()
end

local function start_break()
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
