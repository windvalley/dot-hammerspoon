local _M = {}

_M.name = "break_reminder"
_M.description = "每工作一段时间后强制休息"

-------------------------------------------------------------------------------
-- 模块架构说明
--
-- 本模块是项目中最复杂的功能模块，实现了 gamified 休息提醒系统。
-- 内部结构按以下职责区域组织：
--
-- [配置与状态] L1-180
--   base_config / runtime_overrides / state 三层配置合并机制
--   normalize_config() 将用户配置标准化并填充默认值
--   18 个前向声明的 local 函数（因相互调用需要）
--
-- [Gamification 引擎] L180-530
--   gamification_metrics 持久化到 hs.settings
--   积分计算（gamification_points）、称号（gamification_rank_label）
--   连续达标天数追踪（current_streak_days）
--   跳过惩罚机制（current_skip_penalty_seconds）
--   每日专注时长记录（add_today_focus_seconds）
--
-- [UI 渲染] L530-1060
--   样式辅助函数（style_text / style_icon_text / append_centered_text）
--   全屏遮罩 overlay（create_overlay / render_overlays / update_overlays）
--   友好提醒弹窗（show_friendly_reminder / destroy_friendly_reminder_popup）
--
-- [计时器与状态机] L1060-1950
--   work_timer → friendly_reminder_timer → break 触发 → break_timer → finish
--   会话生命周期（active / inactive / waiting_for_resume_input）
--   输入阻断器（input_blocker，hard 模式下拦截键盘鼠标）
--   caffeinate_watcher 处理锁屏/睡眠/唤醒状态转换
--
-- [菜单栏] L1170-1570
--   三种皮肤（coffee / hourglass / bars）的矢量图标绘制
--   tooltip 和状态更新（update_menubar_status）
--   render_signature 防止无变化时重复渲染
--
-- [运行时配置管理] L1570-2040
--   runtime_overrides 持久化到 hs.settings
--   apply_current_configuration() 热更新配置（不中断当前休息）
--
-- [菜单构建] L2040-2900
--   build_menu() 构建完整菜单栏下拉菜单
--   各子菜单（工作时长/休息时长/遮罩/友好提醒/gamification 等）
--   prompt_number() 自定义数值输入
--
-- [公共 API 与生命周期] L2900-3120
--   _M.start() / _M.stop() 模块生命周期
--   _M.start_break_now / skip_break_now / reset_cycle 外部调用接口
--   _M.get_state() 返回完整运行时状态快照
--
-- 关键设计决策：
-- 1. 大量 local 前向声明是因为函数之间有循环调用关系
--    （如 finish_break → schedule_next_break → start_break → finish_break）
-- 2. state 表由 normalize_config(merged_config()) 生成，不可直接修改
-- 3. gamification_metrics 按日期 key 存储，支持跨天自动归档
-------------------------------------------------------------------------------

local base_config = require("keybindings_config").break_reminder or {}
local prompt_text = require("utils_lib").prompt_text

local log = hs.logger.new("break")
local settings_key = "break_reminder.runtime_overrides"
local metrics_settings_key = "break_reminder.gamification_metrics"
local default_menubar_title = "☕"
local menubar_autosave_name = "dot-hammerspoon.break_reminder"
local default_friendly_reminder_duration_seconds = 10
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
local valid_menubar_skins = {
	coffee = true,
	hourglass = true,
	bars = true,
}
local deprecated_runtime_override_keys = {
	show_progress_in_menubar = true,
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

local function normalize_menubar_skin(value)
	local skin = tostring(value or "coffee"):lower()

	if valid_menubar_skins[skin] ~= true then
		log.w(string.format("invalid menubar skin: %s, fallback to coffee", skin))
		skin = "coffee"
	end

	return skin
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
	local focus_goal_minutes = tonumber(config.focus_goal_minutes)

	if focus_goal_minutes == nil then
		focus_goal_minutes = tonumber(config.daily_goal_minutes)
	end

	local focus_goal_seconds = math.max(60, math.floor((focus_goal_minutes or 120) * 60))
	local break_goal_count = math.max(0, math.floor(tonumber(config.break_goal_count) or 4))

	return {
		enabled = config.enabled ~= false,
		show_menubar = config.show_menubar ~= false,
		menubar_title = tostring(config.menubar_title or default_menubar_title),
		menubar_skin = normalize_menubar_skin(config.menubar_skin),
		start_next_cycle = normalize_start_next_cycle_mode(config.start_next_cycle),
		mode = mode,
		minimal_display = config.minimal_display == true,
		work_seconds = work_seconds,
		rest_seconds = resolve_integer_seconds(config.rest_seconds, 120, 1),
		focus_goal_seconds = focus_goal_seconds,
		break_goal_count = break_goal_count,
		strict_mode_after_skips = math.max(0, math.floor(tonumber(config.strict_mode_after_skips) or 2)),
		rest_penalty_seconds_per_skip = resolve_integer_seconds(config.rest_penalty_seconds_per_skip, 30, 0),
		max_rest_penalty_seconds = resolve_integer_seconds(config.max_rest_penalty_seconds, 300, 0),
		friendly_reminder_seconds = resolve_integer_seconds(config.friendly_reminder_seconds, 0, 0),
		friendly_reminder_duration_seconds = resolve_number(
			config.friendly_reminder_duration_seconds,
			default_friendly_reminder_duration_seconds,
			0
		),
		friendly_reminder_message = tostring(config.friendly_reminder_message or "还有 {{remaining}} 开始休息"),
		overlay_opacity = clamp_number(resolve_number(config.overlay_opacity, default_overlay_opacity[mode], 0), 0, 1),
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

local function render_template(template, variables)
	return (
		template:gsub("{{%s*([%w_]+)%s*}}", function(key)
			local value = variables[key]

			if value == nil then
				return "{{" .. key .. "}}"
			end

			return tostring(value)
		end)
	)
end

local function mode_label(mode)
	if mode == "soft" then
		return "柔性提醒"
	end

	return "硬性提醒"
end

local function sanitize_runtime_overrides(overrides)
	local sanitized = {}
	local changed = false

	for key, value in pairs(overrides or {}) do
		if deprecated_runtime_override_keys[key] == true then
			changed = true
		else
			sanitized[key] = value
		end
	end

	return sanitized, changed
end

local function load_runtime_overrides()
	local saved = hs.settings.get(settings_key)

	if type(saved) == "table" then
		local sanitized, changed = sanitize_runtime_overrides(saved)

		if changed == true then
			if table_is_empty(sanitized) then
				hs.settings.clear(settings_key)
			else
				hs.settings.set(settings_key, sanitized)
			end
		end

		return sanitized
	end

	return {}
end

local function current_day_key()
	return os.date("%Y-%m-%d")
end

local function shift_day_key(day_key, offset_days)
	local year, month, day = tostring(day_key or ""):match("^(%d+)%-(%d+)%-(%d+)$")

	if year == nil then
		return nil
	end

	local timestamp = os.time({
		year = tonumber(year),
		month = tonumber(month),
		day = tonumber(day),
		hour = 12,
	})

	if timestamp == nil then
		return nil
	end

	return os.date("%Y-%m-%d", timestamp + ((offset_days or 0) * 24 * 60 * 60))
end

local function normalize_day_key(value)
	local day_key = tostring(value or "")

	if day_key:match("^%d+%-%d+%-%d+$") ~= nil then
		return day_key
	end

	return current_day_key()
end

local function load_gamification_metrics()
	local saved = hs.settings.get(metrics_settings_key)
	local last_goal_day_key = nil

	if type(saved) ~= "table" then
		saved = {}
	end

	if saved.last_goal_day_key ~= nil then
		local candidate = tostring(saved.last_goal_day_key)

		if candidate:match("^%d+%-%d+%-%d+$") ~= nil then
			last_goal_day_key = candidate
		end
	end

	return {
		day_key = normalize_day_key(saved.day_key),
		today_focus_seconds = resolve_integer_seconds(saved.today_focus_seconds, 0, 0),
		today_completed_breaks = resolve_integer_seconds(saved.today_completed_breaks, 0, 0),
		today_skipped_breaks = resolve_integer_seconds(saved.today_skipped_breaks, 0, 0),
		today_goal_reached = saved.today_goal_reached == true,
		streak_days = resolve_integer_seconds(saved.streak_days, 0, 0),
		best_streak_days = resolve_integer_seconds(saved.best_streak_days, 0, 0),
		last_goal_day_key = last_goal_day_key,
	}
end

local gamification_metrics = load_gamification_metrics()

local function persist_gamification_metrics()
	hs.settings.set(metrics_settings_key, gamification_metrics)
end

local function ensure_gamification_metrics_current()
	local today = current_day_key()

	if gamification_metrics.day_key == today then
		return false
	end

	gamification_metrics.day_key = today
	gamification_metrics.today_focus_seconds = 0
	gamification_metrics.today_completed_breaks = 0
	gamification_metrics.today_skipped_breaks = 0
	gamification_metrics.today_goal_reached = false
	persist_gamification_metrics()

	return true
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
local font_name = "Monaco"
local icon_font_name = "Apple Color Emoji"

local work_timer = nil
local break_timer = nil
local friendly_reminder_timer = nil
local friendly_reminder_popup_timer = nil
local menubar_status_timer = nil
local menubar_status_timer_interval = nil
local last_menubar_render_signature = nil
local last_menubar_tooltip = nil
local inactive_resume_timer = nil
local break_ends_at = nil
local next_break_at = nil
local work_cycle_started_at = nil
local current_work_cycle_duration_seconds = nil
local current_break_duration_seconds = nil
local last_work_session_seconds = nil
local session_is_inactive = false
local waiting_for_resume_input = false
local overlays = {}
local frontmost_app = nil
local blocked_event_types = {}
local resume_input_event_types = {}
local friendly_reminder_canvas = nil
local menubar_item = nil
local started = false

local refresh_menubar
local update_menubar_status
local start_menubar_status_timer
local stop_menubar_status_timer
local try_resume_after_inactive_session
local start_inactive_resume_timer
local stop_inactive_resume_timer
local schedule_next_break
local finish_break
local start_break
local skip_break
local restart_work_cycle
local apply_current_configuration
local update_runtime_overrides
local clear_runtime_overrides
local destroy_friendly_reminder_popup
local show_message

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
	return hs.styledtext.new(text, {
		font = {
			name = font_name,
			size = size,
		},
		color = color,
	})
end

local function style_icon_text(text, size)
	return hs.styledtext.new(text, {
		font = {
			name = icon_font_name,
			size = size,
		},
	})
end

local function append_centered_text(canvas, id, styled_text, y)
	local size = canvas:minimumTextSize(styled_text)
	local frame = canvas:frame()

	canvas:appendElements({
		id = id,
		type = "text",
		text = styled_text,
		frame = {
			x = math.floor((frame.w - size.w) / 2),
			y = y,
			w = size.w,
			h = size.h,
		},
	})
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

local function menubar_skin_label(skin)
	if skin == "hourglass" then
		return "沙漏"
	end

	if skin == "bars" then
		return "律动条"
	end

	return "咖啡杯"
end

local function current_streak_days()
	ensure_gamification_metrics_current()

	local today = current_day_key()
	local yesterday = shift_day_key(today, -1)

	if gamification_metrics.last_goal_day_key == today or gamification_metrics.last_goal_day_key == yesterday then
		return gamification_metrics.streak_days
	end

	return 0
end

local function current_skip_penalty_seconds()
	ensure_gamification_metrics_current()

	if state.rest_penalty_seconds_per_skip <= 0 or gamification_metrics.today_skipped_breaks <= 0 then
		return 0
	end

	return math.min(state.max_rest_penalty_seconds, gamification_metrics.today_skipped_breaks * state.rest_penalty_seconds_per_skip)
end

local function effective_rest_seconds()
	return state.rest_seconds + current_skip_penalty_seconds()
end

local function effective_mode()
	ensure_gamification_metrics_current()

	if state.strict_mode_after_skips > 0 and gamification_metrics.today_skipped_breaks >= state.strict_mode_after_skips then
		return "hard", true
	end

	return state.mode, false
end

local function is_soft_mode()
	local mode = effective_mode()

	return mode == "soft"
end

local function is_hard_mode()
	local mode = effective_mode()

	return mode == "hard"
end

local function effective_mode_label()
	local mode, enforced = effective_mode()

	if enforced == true then
		return "硬性提醒（跳过惩罚生效）"
	end

	return mode_label(mode)
end

local function rest_duration_label()
	local penalty_seconds = current_skip_penalty_seconds()

	if penalty_seconds <= 0 then
		return format_duration(state.rest_seconds)
	end

	return string.format("%s（+%s 惩罚）", format_duration(effective_rest_seconds()), format_duration(penalty_seconds))
end

local function gamification_points()
	ensure_gamification_metrics_current()

	local focus_points = math.floor(gamification_metrics.today_focus_seconds / 60)
	local break_points = gamification_metrics.today_completed_breaks * 18
	local goal_bonus = gamification_metrics.today_goal_reached == true and 40 or 0
	local streak_bonus = math.min(40, current_streak_days() * 5)
	local skip_penalty = gamification_metrics.today_skipped_breaks * 25

	return focus_points + break_points + goal_bonus + streak_bonus - skip_penalty
end

local function break_goal_reached()
	ensure_gamification_metrics_current()

	if state.break_goal_count <= 0 then
		return false
	end

	return gamification_metrics.today_completed_breaks >= state.break_goal_count
end

local function current_break_completion_rate()
	ensure_gamification_metrics_current()

	local opportunities = gamification_metrics.today_completed_breaks + gamification_metrics.today_skipped_breaks

	if opportunities <= 0 then
		return nil, opportunities
	end

	return clamp_number(gamification_metrics.today_completed_breaks / opportunities, 0, 1), opportunities
end

local function break_completion_rate_label()
	local rate, opportunities = current_break_completion_rate()

	if opportunities <= 0 or rate == nil then
		return "暂无数据"
	end

	return string.format("%d%%（%d/%d）", math.floor((rate * 100) + 0.5), gamification_metrics.today_completed_breaks, opportunities)
end

local function gamification_rank_label()
	local points = gamification_points()

	if points >= 220 then
		return "休息大师"
	end

	if points >= 140 then
		return "节奏稳定"
	end

	if points >= 80 then
		return "渐入佳境"
	end

	if points >= 20 then
		return "开始热身"
	end

	return "等待起步"
end

local function maybe_unlock_focus_goal_reward()
	ensure_gamification_metrics_current()

	if gamification_metrics.today_goal_reached == true then
		return
	end

	if gamification_metrics.today_focus_seconds < state.focus_goal_seconds then
		return
	end

	local today = current_day_key()
	local yesterday = shift_day_key(today, -1)

	if gamification_metrics.last_goal_day_key == yesterday then
		gamification_metrics.streak_days = gamification_metrics.streak_days + 1
	else
		gamification_metrics.streak_days = 1
	end

	gamification_metrics.today_goal_reached = true
	gamification_metrics.last_goal_day_key = today
	gamification_metrics.best_streak_days = math.max(gamification_metrics.best_streak_days, gamification_metrics.streak_days)
	persist_gamification_metrics()
	show_message(string.format("今日专注目标达成，连续达标 %d 天", current_streak_days()))
end

local function add_today_focus_seconds(seconds, reason)
	local focus_seconds = math.max(0, math.floor(seconds or 0))

	if focus_seconds <= 0 then
		return 0
	end

	ensure_gamification_metrics_current()
	gamification_metrics.today_focus_seconds = gamification_metrics.today_focus_seconds + focus_seconds
	persist_gamification_metrics()
	log.i(string.format("focus time added: %d seconds, reason=%s", focus_seconds, tostring(reason)))
	maybe_unlock_focus_goal_reward()

	return focus_seconds
end

local function record_completed_break()
	ensure_gamification_metrics_current()
	gamification_metrics.today_completed_breaks = gamification_metrics.today_completed_breaks + 1
	persist_gamification_metrics()

	local rewards = {
		[1] = "完成第 1 次休息，今天已经进入节奏",
		[3] = "完成第 3 次休息，节奏很稳",
		[5] = "完成第 5 次休息，今天的自控力很强",
	}
	local message = rewards[gamification_metrics.today_completed_breaks]

	if message ~= nil then
		show_message(message)
		return
	end

	if break_goal_reached() == true and gamification_metrics.today_completed_breaks == state.break_goal_count then
		show_message(string.format("今日休息目标达成，已完成 %d 次休息", state.break_goal_count))
	end
end

local function record_skipped_break()
	ensure_gamification_metrics_current()
	gamification_metrics.today_skipped_breaks = gamification_metrics.today_skipped_breaks + 1
	persist_gamification_metrics()
end

local function commit_active_work_progress(reason)
	if work_cycle_started_at == nil then
		return 0
	end

	if break_ends_at ~= nil or waiting_for_resume_input == true or session_is_inactive == true then
		work_cycle_started_at = nil
		next_break_at = nil
		current_work_cycle_duration_seconds = nil
		return 0
	end

	local cycle_duration = current_work_cycle_duration_seconds or state.work_seconds
	local elapsed_seconds = clamp_number(os.time() - work_cycle_started_at, 0, cycle_duration)

	work_cycle_started_at = nil
	next_break_at = nil
	current_work_cycle_duration_seconds = nil

	if elapsed_seconds <= 0 then
		return 0
	end

	return add_today_focus_seconds(elapsed_seconds, reason or "work cycle committed")
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

	local _, enforced = effective_mode()

	if enforced == true then
		return "今日跳过休息过多，已升级为硬性强制"
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
		_M.resume_input_watcher = hs.eventtap.new(resume_input_event_types, function()
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
		end)
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
		_M.input_blocker = hs.eventtap.new(blocked_event_types, function()
			return true
		end)
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
	if clear_break_cycle ~= false then
		commit_active_work_progress("active runtime cleared")
	end

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
		current_work_cycle_duration_seconds = nil
		current_break_duration_seconds = nil
		last_work_session_seconds = nil
	end
end

local function restore_frontmost_app()
	if not is_soft_mode() or frontmost_app == nil then
		return
	end

	hs.timer.doAfter(0, function()
		if break_ends_at == nil or frontmost_app == nil then
			return
		end

		pcall(function()
			frontmost_app:activate()
		end)
	end)
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
	canvas:appendElements({
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
	})

	if state.minimal_display then
		local icon = style_icon_text("☕️", math.floor(math.min(frame.w, frame.h) * 0.22))
		local icon_height = canvas:minimumTextSize(icon).h

		append_centered_text(canvas, "icon", icon, math.floor((frame.h - icon_height) / 2))
		canvas:show(0)
		return canvas
	end

	local title = style_text("休息时间", 40, title_color)
	local countdown = style_text(format_seconds(remaining_seconds), 72, countdown_color)
	local worked_seconds = last_work_session_seconds or state.work_seconds
	local rest_seconds = current_break_duration_seconds or effective_rest_seconds()
	local description = style_text(
		string.format("你已经连续工作 %s\n请离开屏幕休息 %s", format_duration(worked_seconds), format_duration(rest_seconds)),
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

	inactive_resume_timer = hs.timer.doEvery(1, function()
		if try_resume_after_inactive_session ~= nil then
			try_resume_after_inactive_session("inactive resume retry timer")
		end

		if session_is_inactive ~= true then
			stop_inactive_resume_timer()
		end
	end)
end

local function current_status()
	if state.enabled ~= true then
		return "已关闭", "提醒未启用"
	end

	if session_is_inactive == true then
		return "会话未激活", "锁屏、熄屏或睡眠期间不会累计工作时长"
	end

	if waiting_for_resume_input == true then
		return "等待输入", "休息已结束，首次键盘或鼠标输入后开始下一轮工作计时"
	end

	if break_ends_at ~= nil then
		local remaining_seconds = math.max(0, break_ends_at - os.time())

		return "休息中",
			string.format(
				"距离结束还有 %s，当前休息目标 %s",
				format_seconds(remaining_seconds),
				format_duration(current_break_duration_seconds or effective_rest_seconds())
			)
	end

	if next_break_at ~= nil then
		local remaining_seconds = math.max(0, next_break_at - os.time())

		return "工作中", string.format("距离下一次休息还有 %s", format_duration(remaining_seconds))
	end

	return "待机中", "等待开始新的工作计时"
end

local function menubar_visual_state()
	local icon_color = menubar_active_color

	if state.enabled ~= true then
		icon_color = menubar_disabled_color
	elseif session_is_inactive == true then
		icon_color = menubar_paused_color
	elseif waiting_for_resume_input == true then
		icon_color = menubar_waiting_color
	end

	local progress_fraction = nil
	local progress_update_interval = nil

	if state.enabled == true and session_is_inactive ~= true and waiting_for_resume_input ~= true then
		if break_ends_at ~= nil then
			local total_seconds = math.max(1, current_break_duration_seconds or effective_rest_seconds())
			local remaining_seconds = clamp_number(break_ends_at - os.time(), 0, total_seconds)

			progress_fraction = clamp_number((total_seconds - remaining_seconds) / total_seconds, 0, 1)
			progress_update_interval = 10
		elseif next_break_at ~= nil then
			local total_seconds = math.max(1, current_work_cycle_duration_seconds or state.work_seconds)
			local remaining_seconds = clamp_number(next_break_at - os.time(), 0, total_seconds)

			progress_fraction = clamp_number((total_seconds - remaining_seconds) / total_seconds, 0, 1)
			progress_update_interval = 60
		end
	end

	return {
		icon_color = icon_color,
		progress_fraction = progress_fraction,
		progress_update_interval = progress_update_interval,
	}
end

local function menubar_render_signature(status_title, status_detail, tooltip, visual_state)
	return table.concat({
		tostring(status_title or ""),
		tostring(status_detail or ""),
		tostring(tooltip or ""),
		tostring(state.menubar_skin),
		tostring(visual_state.icon_color and visual_state.icon_color.alpha or ""),
		visual_state.progress_fraction ~= nil and string.format("%.4f", visual_state.progress_fraction) or "",
	}, "|")
end

local function menubar_tooltip_status_detail()
	if state.enabled ~= true then
		return "提醒未启用"
	end

	if session_is_inactive == true then
		return "锁屏、熄屏或睡眠期间不会累计工作时长"
	end

	if waiting_for_resume_input == true then
		return "休息已结束，等待首次输入后开始下一轮"
	end

	if break_ends_at ~= nil then
		return string.format(
			"休息进行中，目标时长 %s",
			format_duration(current_break_duration_seconds or effective_rest_seconds())
		)
	end

	if next_break_at ~= nil then
		return string.format("工作进行中，当前节奏 %s / %s", format_minutes(state.work_seconds), rest_duration_label())
	end

	return "等待开始新的工作计时"
end

local function build_menubar_icon(visual_state)
	visual_state = visual_state or menubar_visual_state()
	local canvas = hs.canvas.new({
		x = 0,
		y = 0,
		w = menubar_canvas_size,
		h = menubar_canvas_size,
	})
	local center_x = menubar_canvas_size / 2
	local center_y = menubar_canvas_size / 2
	local icon_color = visual_state.icon_color
	local elements = {}

	local function color_with_alpha(color, alpha)
		local updated = shallow_copy(color or {})

		updated.alpha = alpha

		return updated
	end

	local function circle_path_coordinates(start_radians, end_radians, radius)
		local radians_span = end_radians - start_radians
		local steps = math.max(12, math.ceil(math.abs(radians_span) * 12))
		local coordinates = {}

		for index = 0, steps do
			local ratio = index / steps
			local angle = start_radians + (radians_span * ratio)

			table.insert(coordinates, {
				x = center_x + (math.cos(angle) * radius),
				y = center_y + (math.sin(angle) * radius),
			})
		end

		return coordinates
	end

	local function transform_coordinates(coordinates, scale, offset_x, offset_y)
		local transformed = {}

		for _, point in ipairs(coordinates) do
			table.insert(transformed, {
				x = center_x + ((point.x - center_x) * scale) + offset_x,
				y = center_y + ((point.y - center_y) * scale) + offset_y,
			})
		end

		return transformed
	end

	local function append_progress_ring()
		if visual_state.progress_fraction == nil then
			return
		end

		local radius = 14.2
		local ring_start = -math.pi / 2
		local full_circle = (math.pi * 2) - math.rad(8)

		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.8,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = color_with_alpha(icon_color, 0.16),
			coordinates = circle_path_coordinates(ring_start, ring_start + full_circle, radius),
		})

		if visual_state.progress_fraction <= 0 then
			return
		end

		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 2.2,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = color_with_alpha(icon_color, icon_color.alpha or 1),
			coordinates = circle_path_coordinates(
				ring_start,
				ring_start + (full_circle * visual_state.progress_fraction),
				radius
			),
		})
	end

	append_progress_ring()

	local function append_coffee_skin()
		local icon_scale = 1.24
		local icon_offset_x = 0.2
		local icon_offset_y = 0.35
		local transform = function(coordinates)
			return transform_coordinates(coordinates, icon_scale, icon_offset_x, icon_offset_y)
		end

		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.95,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 11.6, y = 16.6 },
				{ x = 11.6, y = 23.3 },
				{ x = 13.1, y = 25.1 },
				{ x = 20.8, y = 25.1 },
				{ x = 22.3, y = 23.3 },
				{ x = 22.3, y = 16.6 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.85,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 12.5, y = 16.3 },
				{ x = 21.4, y = 16.3 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.95,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 22.2, y = 17.9 },
				{ x = 24.9, y = 18.1 },
				{ x = 25.5, y = 20.7 },
				{ x = 24.9, y = 23.2 },
				{ x = 22.1, y = 23.4 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.55,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 14.2, y = 12.8 },
				{ x = 13.3, y = 11.2 },
				{ x = 14.4, y = 9.8 },
				{ x = 13.8, y = 8.5 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.55,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 18.9, y = 12.5 },
				{ x = 18.0, y = 10.9 },
				{ x = 19.0, y = 9.5 },
				{ x = 18.5, y = 8.2 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.75,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 10.4, y = 27.9 },
				{ x = 24.3, y = 27.9 },
			}),
		})
	end

	local function append_hourglass_skin()
		local icon_scale = 1.18
		local icon_offset_x = 0
		local icon_offset_y = 0.3
		local transform = function(coordinates)
			return transform_coordinates(coordinates, icon_scale, icon_offset_x, icon_offset_y)
		end
		local stroke_width = 1.95

		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = stroke_width,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 11.7, y = 8.9 },
				{ x = 24.3, y = 8.9 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = stroke_width,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 11.7, y = 27.1 },
				{ x = 24.3, y = 27.1 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = stroke_width,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 12.8, y = 10.8 },
				{ x = 21.8, y = 10.8 },
				{ x = 18.0, y = 17.6 },
				{ x = 14.2, y = 24.9 },
				{ x = 23.2, y = 24.9 },
			}),
		})
		table.insert(elements, {
			type = "segments",
			action = "stroke",
			closed = false,
			strokeWidth = 1.5,
			strokeCapStyle = "round",
			strokeJoinStyle = "round",
			strokeColor = icon_color,
			coordinates = transform({
				{ x = 18.0, y = 17.6 },
				{ x = 18.0, y = 18.9 },
			}),
		})
	end

	local function append_bars_skin()
		local icon_scale = 1.1
		local icon_offset_y = 0.2
		local heights = {
			12.6,
			17.8,
			13.0,
		}
		local bars = {
			{ x = 10.8, width = 4.2, height = heights[1] },
			{ x = 16.0, width = 4.2, height = heights[2] },
			{ x = 21.2, width = 4.2, height = heights[3] },
		}

		for _, bar in ipairs(bars) do
			local scaled_height = bar.height * icon_scale

			table.insert(elements, {
				type = "rectangle",
				action = "fill",
				fillColor = icon_color,
				roundedRectRadii = { xRadius = 1.4, yRadius = 1.4 },
				frame = {
					x = bar.x,
					y = 27.4 - scaled_height + icon_offset_y,
					w = bar.width,
					h = scaled_height,
				},
			})
		end
	end

	if state.menubar_skin == "hourglass" then
		append_hourglass_skin()
	elseif state.menubar_skin == "bars" then
		append_bars_skin()
	else
		append_coffee_skin()
	end

	canvas:appendElements(table.unpack(elements))

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

	ensure_gamification_metrics_current()

	local status_title, status_detail = current_status()
	local visual_state = menubar_visual_state()
	local icon = build_menubar_icon(visual_state)
	local tooltip = string.format(
		"Break Reminder\n状态: %s\n%s\n模式: %s | 工作: %s | 休息: %s | 下一轮: %s\n今日专注: %s / %s | 完成休息: %d | 跳过: %d\n休息目标: %s | 休息完成率: %s\n连续达标: %d 天 | 今日积分: %d (%s) | 皮肤: %s",
		status_title,
		menubar_tooltip_status_detail(),
		effective_mode_label(),
		format_minutes(state.work_seconds),
		rest_duration_label(),
		start_next_cycle_label(state.start_next_cycle),
		format_duration(gamification_metrics.today_focus_seconds),
		format_duration(state.focus_goal_seconds),
		gamification_metrics.today_completed_breaks,
		gamification_metrics.today_skipped_breaks,
		state.break_goal_count <= 0 and "未启用"
			or string.format(
				"%d/%d%s",
				gamification_metrics.today_completed_breaks,
				state.break_goal_count,
				break_goal_reached() == true and "（已达成）" or ""
			),
		break_completion_rate_label(),
		current_streak_days(),
		gamification_points(),
		gamification_rank_label(),
		menubar_skin_label(state.menubar_skin)
	)
	local render_signature = menubar_render_signature(status_title, status_detail, tooltip, visual_state)

	if render_signature == last_menubar_render_signature then
		return
	end

	menubar_item:setTitle(nil)

	if icon ~= nil then
		menubar_item:setIcon(icon, true)
	else
		menubar_item:setIcon(nil)
		menubar_item:setTitle(state.menubar_title)
	end

	if tooltip ~= last_menubar_tooltip then
		menubar_item:setTooltip(tooltip)
		last_menubar_tooltip = tooltip
	end

	last_menubar_render_signature = render_signature
	start_menubar_status_timer()
end

start_menubar_status_timer = function()
	local interval = nil

	if menubar_item ~= nil then
		interval = menubar_visual_state().progress_update_interval
	end

	if interval == nil then
		stop_menubar_status_timer()
		return
	end

	if menubar_status_timer ~= nil and menubar_status_timer_interval == interval then
		return
	end

	stop_menubar_status_timer()
	menubar_status_timer_interval = interval
	menubar_status_timer = hs.timer.doEvery(interval, function()
		if menubar_item == nil then
			stop_menubar_status_timer()
			return
		end

		update_menubar_status()
	end)
end

stop_menubar_status_timer = function()
	if menubar_status_timer == nil then
		menubar_status_timer_interval = nil
		return
	end

	menubar_status_timer:stop()
	menubar_status_timer = nil
	menubar_status_timer_interval = nil
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

	local work_seconds = current_work_cycle_duration_seconds or state.work_seconds
	local rest_seconds = effective_rest_seconds()

	if state.friendly_reminder_seconds <= 0 or state.friendly_reminder_seconds >= work_seconds then
		return
	end

	local message = render_template(state.friendly_reminder_message, {
		remaining = format_duration(state.friendly_reminder_seconds),
		remaining_seconds = state.friendly_reminder_seconds,
		remaining_mmss = format_seconds(state.friendly_reminder_seconds),
		rest = format_duration(rest_seconds),
		rest_seconds = rest_seconds,
		rest_mmss = format_seconds(rest_seconds),
	})

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
	friendly_reminder_canvas:appendElements({
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
	}, {
		id = "message",
		type = "text",
		text = body_style,
		frame = {
			x = 20,
			y = 18,
			w = popup_width - 56,
			h = popup_height - 30,
		},
	}, {
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
	})
	friendly_reminder_canvas:mouseCallback(function(_, callback_message, element_id)
		if callback_message == "mouseUp" and element_id == "close_button" then
			destroy_friendly_reminder_popup()
		end
	end)
	friendly_reminder_canvas:show(0)

	if state.friendly_reminder_duration_seconds > 0 then
		friendly_reminder_popup_timer = hs.timer.doAfter(state.friendly_reminder_duration_seconds, function()
			destroy_friendly_reminder_popup()
		end)
	end
end

finish_break = function()
	stop_break_timer()
	stop_input_blocker()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	record_completed_break()
	break_ends_at = nil
	current_break_duration_seconds = nil
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
		current_work_cycle_duration_seconds = nil
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
	last_work_session_seconds = commit_active_work_progress("break started")
	waiting_for_resume_input = false
	next_break_at = nil
	work_cycle_started_at = nil
	current_work_cycle_duration_seconds = nil
	current_break_duration_seconds = effective_rest_seconds()
	break_ends_at = os.time() + current_break_duration_seconds
	frontmost_app = nil

	if is_soft_mode() then
		frontmost_app = hs.application.frontmostApplication()
	end

	log.i(
		string.format(
			"break started, mode=%s, rest_seconds=%d, reason=%s",
			select(1, effective_mode()),
			current_break_duration_seconds,
			tostring(reason)
		)
	)
	render_overlays(current_break_duration_seconds)
	start_input_blocker()
	update_menubar_status()

	stop_break_timer()
	break_timer = hs.timer.doEvery(1, function()
		local remaining_seconds = break_ends_at - os.time()

		if remaining_seconds <= 0 then
			finish_break()
			return
		end

		update_overlays(remaining_seconds)
	end)
end

skip_break = function(reason)
	if break_ends_at == nil then
		return false
	end

	stop_break_timer()
	stop_input_blocker()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	break_ends_at = nil
	current_break_duration_seconds = nil
	frontmost_app = nil
	waiting_for_resume_input = false
	record_skipped_break()

	local penalty_seconds = current_skip_penalty_seconds()
	local _, enforced = effective_mode()
	local penalty_message = penalty_seconds > 0 and ("后续休息增加 " .. format_duration(penalty_seconds))
		or "未增加额外休息时长"

	log.i(
		string.format(
			"break skipped, skipped_today=%d, penalty_seconds=%d, reason=%s",
			gamification_metrics.today_skipped_breaks,
			penalty_seconds,
			tostring(reason)
		)
	)

	if state.enabled == true and session_is_inactive ~= true then
		schedule_next_break(reason or "break skipped")
	else
		update_menubar_status()
	end

	show_message(
		string.format(
			"已跳过本次休息，今日已跳过 %d 次。%s%s",
			gamification_metrics.today_skipped_breaks,
			penalty_message,
			enforced == true and "，并升级为硬性提醒" or ""
		)
	)

	return true
end

schedule_next_break = function(reason)
	if state.enabled ~= true or session_is_inactive == true then
		return
	end

	commit_active_work_progress(reason or "reschedule work cycle")

	stop_work_timer()
	stop_break_timer()
	stop_input_blocker()
	stop_resume_input_watcher()
	stop_friendly_reminder_timer()
	destroy_friendly_reminder_popup()
	destroy_overlays()
	break_ends_at = nil
	current_break_duration_seconds = nil
	frontmost_app = nil
	waiting_for_resume_input = false
	last_work_session_seconds = nil
	work_cycle_started_at = os.time()
	current_work_cycle_duration_seconds = state.work_seconds
	next_break_at = work_cycle_started_at + current_work_cycle_duration_seconds

	if state.friendly_reminder_seconds > 0 and state.friendly_reminder_seconds < current_work_cycle_duration_seconds then
		friendly_reminder_timer = hs.timer.doAfter(current_work_cycle_duration_seconds - state.friendly_reminder_seconds, function()
			friendly_reminder_timer = nil

			if break_ends_at ~= nil or state.enabled ~= true then
				return
			end

			show_friendly_reminder()
		end)
	elseif state.friendly_reminder_seconds >= current_work_cycle_duration_seconds then
		log.w("friendly reminder is not scheduled because it is greater than or equal to work duration")
	end

	work_timer = hs.timer.doAfter(current_work_cycle_duration_seconds, function()
		work_timer = nil
		next_break_at = nil
		start_break(reason or "work timer reached")
	end)

	log.i(string.format("break scheduled in %d seconds, reason=%s", current_work_cycle_duration_seconds, tostring(reason)))
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

show_message = function(message)
	hs.alert.show(message)
end

local function confirm_restore_defaults()
	if table_is_empty(runtime_overrides) then
		return false
	end

	local button = hs.dialog.blockAlert(
		"恢复默认",
		"这会清除当前通过菜单修改的运行时配置，并恢复为 keybindings_config.lua 中定义的默认值。是否继续？",
		"恢复默认",
		"取消"
	)

	if button ~= "恢复默认" then
		return false
	end

	clear_runtime_overrides("restore defaults")
	show_message("已恢复默认配置")

	return true
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

local function menu_item_set_work_minutes(minutes)
	update_runtime_overrides({
		work_minutes = minutes,
	}, string.format("工作时长已更新为 %s", format_minutes(math.floor(minutes * 60))))
end

local function menu_item_set_rest_seconds(seconds)
	update_runtime_overrides({
		rest_seconds = seconds,
	}, string.format("休息时长已更新为 %s", format_duration(seconds)))
end

local function menu_item_set_friendly_reminder_seconds(seconds)
	update_runtime_overrides({
		friendly_reminder_seconds = seconds,
	}, seconds <= 0 and "已关闭友好提醒" or string.format("友好提醒已调整为提前 %s", format_duration(seconds)))
end

local function menu_item_set_friendly_reminder_duration(seconds)
	update_runtime_overrides(
		{
			friendly_reminder_duration_seconds = seconds,
		},
		seconds <= 0 and "友好提醒已改为手动关闭"
			or string.format("友好提醒停留时长已更新为 %s", format_duration(seconds))
	)
end

local function menu_item_set_overlay_opacity(opacity)
	update_runtime_overrides({
		overlay_opacity = opacity,
	}, string.format("遮罩透明度已更新为 %s", format_decimal(opacity)))
end

local function menu_item_set_minimal_display(minimal_display)
	if state.minimal_display == minimal_display then
		return
	end

	update_runtime_overrides({
		minimal_display = minimal_display,
	}, minimal_display and "已切换为仅显示咖啡图标" or "已切换为显示丰富信息")
end

local function menu_item_set_focus_goal_minutes(minutes)
	update_runtime_overrides({
		focus_goal_minutes = minutes,
	}, string.format("每日专注目标已更新为 %s", format_minutes(math.floor(minutes * 60))))
end

local function menu_item_set_break_goal_count(count)
	update_runtime_overrides({
		break_goal_count = count,
	}, count <= 0 and "已关闭每日休息目标" or string.format("每日休息目标已更新为 %d 次", count))
end

local function menu_item_set_menubar_skin(skin)
	if state.menubar_skin == skin then
		return
	end

	update_runtime_overrides({
		menubar_skin = skin,
	}, string.format("菜单栏图标已切换为%s", menubar_skin_label(skin)))
end

local function menu_item_set_strict_mode_after_skips(count)
	update_runtime_overrides({
		strict_mode_after_skips = count,
	}, count <= 0 and "已关闭跳过后自动升级硬性提醒" or string.format("跳过 %d 次后将升级为硬性提醒", count))
end

local function menu_item_set_rest_penalty_seconds_per_skip(seconds)
	update_runtime_overrides(
		{
			rest_penalty_seconds_per_skip = seconds,
		},
		seconds <= 0 and "已关闭跳过休息的时长惩罚"
			or string.format("每次跳过将额外增加 %s 休息惩罚", format_duration(seconds))
	)
end

local function menu_item_set_max_rest_penalty_seconds(seconds)
	update_runtime_overrides({
		max_rest_penalty_seconds = seconds,
	}, string.format("跳过休息惩罚上限已更新为 %s", format_duration(seconds)))
end

local function build_work_duration_menu()
	local current_minutes = state.work_seconds / 60
	local menu = {
		{ title = string.format("当前: %s", format_minutes(state.work_seconds)), disabled = true },
	}
	local presets = { 25, 28, 30, 45, 50 }

	for _, minutes in ipairs(presets) do
		table.insert(menu, {
			title = string.format("%s", format_minutes(minutes * 60)),
			checked = math.abs(current_minutes - minutes) < 0.001,
			fn = function()
				menu_item_set_work_minutes(minutes)
			end,
		})
	end

	table.insert(menu, {
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
	})

	return menu
end

local function build_rest_duration_menu()
	local menu = {
		{ title = string.format("当前: %s", format_duration(state.rest_seconds)), disabled = true },
	}
	local presets = { 60, 120, 300, 600 }

	for _, seconds in ipairs(presets) do
		table.insert(menu, {
			title = format_duration(seconds),
			checked = state.rest_seconds == seconds,
			fn = function()
				menu_item_set_rest_seconds(seconds)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义...",
		fn = function()
			local seconds = prompt_number("休息时长", "请输入休息时长，单位为秒", state.rest_seconds, 1, nil)

			if seconds == nil then
				return
			end

			menu_item_set_rest_seconds(math.floor(seconds))
		end,
	})

	return menu
end

local function build_focus_goal_menu()
	local current_minutes = state.focus_goal_seconds / 60
	local menu = {
		{
			title = string.format("当前: %s", format_minutes(state.focus_goal_seconds)),
			disabled = true,
		},
	}
	local presets = { 60, 90, 120, 180, 240, 300, 360, 480 }

	for _, minutes in ipairs(presets) do
		table.insert(menu, {
			title = format_minutes(minutes * 60),
			checked = math.abs(current_minutes - minutes) < 0.001,
			fn = function()
				menu_item_set_focus_goal_minutes(minutes)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义...",
		fn = function()
			local minutes = prompt_number(
				"每日专注目标",
				"请输入每日专注目标，单位为分钟",
				format_decimal(current_minutes),
				1,
				nil
			)

			if minutes == nil then
				return
			end

			menu_item_set_focus_goal_minutes(minutes)
		end,
	})

	return menu
end

local function build_break_goal_menu()
	local menu = {
		{
			title = state.break_goal_count <= 0 and "当前: 已关闭" or string.format("当前: %d 次", state.break_goal_count),
			disabled = true,
		},
	}

	for _, count in ipairs({ 0, 2, 4, 6, 8, 10, 12 }) do
		table.insert(menu, {
			title = count == 0 and "关闭休息目标" or string.format("%d 次", count),
			checked = state.break_goal_count == count,
			fn = function()
				menu_item_set_break_goal_count(count)
			end,
		})
	end

	table.insert(menu, {
		title = "自定义...",
		fn = function()
			local count = prompt_number("每日休息目标", "请输入每日休息目标次数，0 表示关闭", state.break_goal_count, 0, nil)

			if count == nil then
				return
			end

			if math.abs(count - math.floor(count)) > 0.000001 then
				show_message("请输入整数次数")
				return
			end

			menu_item_set_break_goal_count(math.floor(count))
		end,
	})

	return menu
end

local function build_menubar_skin_menu()
	return {
		{ title = "当前皮肤: " .. menubar_skin_label(state.menubar_skin), disabled = true },
		{
			title = "咖啡杯",
			checked = state.menubar_skin == "coffee",
			fn = function()
				menu_item_set_menubar_skin("coffee")
			end,
		},
		{
			title = "沙漏",
			checked = state.menubar_skin == "hourglass",
			fn = function()
				menu_item_set_menubar_skin("hourglass")
			end,
		},
		{
			title = "律动条",
			checked = state.menubar_skin == "bars",
			fn = function()
				menu_item_set_menubar_skin("bars")
			end,
		},
	}
end

local function build_skip_punishment_menu()
	local menu = {
		{
			title = string.format("当前累计惩罚: %s", format_duration(current_skip_penalty_seconds())),
			disabled = true,
		},
	}
	local strict_presets = { 0, 1, 2, 3 }

	table.insert(menu, { title = "跳过多少次后升级硬性提醒", disabled = true })

	for _, count in ipairs(strict_presets) do
		local title = count == 0 and "禁用自动升级" or string.format("%d 次", count)

		table.insert(menu, {
			title = title,
			checked = state.strict_mode_after_skips == count,
			fn = function()
				menu_item_set_strict_mode_after_skips(count)
			end,
		})
	end

	table.insert(menu, { title = "-" })
	table.insert(menu, { title = "每次跳过追加时长", disabled = true })

	for _, seconds in ipairs({ 0, 30, 60, 120 }) do
		local title = seconds == 0 and "禁用时长惩罚" or format_duration(seconds)

		table.insert(menu, {
			title = title,
			checked = state.rest_penalty_seconds_per_skip == seconds,
			fn = function()
				menu_item_set_rest_penalty_seconds_per_skip(seconds)
			end,
		})
	end

	table.insert(menu, { title = "-" })
	table.insert(menu, { title = "惩罚上限", disabled = true })

	for _, seconds in ipairs({ 60, 180, 300, 600 }) do
		table.insert(menu, {
			title = format_duration(seconds),
			checked = state.max_rest_penalty_seconds == seconds,
			fn = function()
				menu_item_set_max_rest_penalty_seconds(seconds)
			end,
		})
	end

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
		table.insert(menu, {
			title = format_decimal(opacity),
			checked = math.abs(state.overlay_opacity - opacity) < 0.001,
			fn = function()
				menu_item_set_overlay_opacity(opacity)
			end,
		})
	end

	table.insert(menu, {
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
	})

	return menu
end

local function build_friendly_reminder_menu()
	local current_duration = state.friendly_reminder_duration_seconds
	local duration_label = current_duration <= 0 and "手动关闭" or format_duration(current_duration)
	local menu = {
		{
			title = state.friendly_reminder_seconds <= 0 and "当前提前提醒: 已关闭"
				or string.format("当前提前提醒: %s", format_duration(state.friendly_reminder_seconds)),
			disabled = true,
		},
	}
	local reminder_presets = { 0, 60, 120, 300 }

	for _, seconds in ipairs(reminder_presets) do
		local title = seconds == 0 and "关闭提前提醒" or string.format("提前 %s", format_duration(seconds))

		table.insert(menu, {
			title = title,
			checked = state.friendly_reminder_seconds == seconds,
			fn = function()
				menu_item_set_friendly_reminder_seconds(seconds)
			end,
		})
	end

	table.insert(menu, {
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
	})

	table.insert(menu, { title = "-" })
	table.insert(menu, {
		title = string.format("当前停留时长: %s", duration_label),
		disabled = true,
	})

	local duration_presets = { 0, 5, 10, 15 }

	for _, seconds in ipairs(duration_presets) do
		local title = seconds == 0 and "手动关闭" or format_duration(seconds)

		table.insert(menu, {
			title = title,
			checked = math.abs(current_duration - seconds) < 0.001,
			fn = function()
				menu_item_set_friendly_reminder_duration(seconds)
			end,
		})
	end

	table.insert(menu, {
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
	})

	table.insert(menu, { title = "-" })
	table.insert(menu, {
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

			update_runtime_overrides({
				friendly_reminder_message = message,
			}, "友好提醒文案已更新")
		end,
	})

	return menu
end

local function build_gamification_menu()
	ensure_gamification_metrics_current()

	return {
		{
			title = string.format("今日专注: %s", format_duration(gamification_metrics.today_focus_seconds)),
			disabled = true,
		},
		{
			title = string.format("今日完成休息: %d 次", gamification_metrics.today_completed_breaks),
			disabled = true,
		},
		{
			title = string.format("今日跳过休息: %d 次", gamification_metrics.today_skipped_breaks),
			disabled = true,
		},
		{
			title = string.format(
				"专注目标: %s%s",
				format_duration(state.focus_goal_seconds),
				gamification_metrics.today_goal_reached == true and "（已达成）" or ""
			),
			disabled = true,
		},
		{
			title = state.break_goal_count <= 0 and "休息目标: 未启用" or string.format(
				"休息目标: %d/%d%s",
				gamification_metrics.today_completed_breaks,
				state.break_goal_count,
				break_goal_reached() == true and "（已达成）" or ""
			),
			disabled = true,
		},
		{
			title = "休息完成率: " .. break_completion_rate_label(),
			disabled = true,
		},
		{
			title = string.format("连续达标: %d 天 | 最佳: %d 天", current_streak_days(), gamification_metrics.best_streak_days),
			disabled = true,
		},
		{
			title = string.format("今日积分: %d | 称号: %s", gamification_points(), gamification_rank_label()),
			disabled = true,
		},
		{ title = "-" },
		{
			title = "专注目标",
			menu = build_focus_goal_menu(),
		},
		{
			title = "休息目标",
			menu = build_break_goal_menu(),
		},
		{
			title = "跳过惩罚",
			menu = build_skip_punishment_menu(),
		},
	}
end

local function build_mode_menu()
	local _, enforced = effective_mode()
	local menu = {
		{
			title = enforced == true and "当前已因跳过休息过多而强制升级为硬性提醒" or "当前按基础模式执行",
			disabled = true,
		},
		{
			title = "柔性提醒",
			checked = state.mode == "soft",
			fn = function()
				update_runtime_overrides({
					mode = "soft",
				}, "已切换为柔性提醒模式")
			end,
		},
		{
			title = "硬性提醒",
			checked = state.mode == "hard",
			fn = function()
				update_runtime_overrides({
					mode = "hard",
				}, "已切换为硬性提醒模式")
			end,
		},
	}

	return menu
end

local function build_start_next_cycle_menu()
	return {
		{
			title = "休息结束立即开始",
			checked = state.start_next_cycle == "auto",
			fn = function()
				update_runtime_overrides({
					start_next_cycle = "auto",
				}, "已切换为休息结束立即开始下一轮工作计时")
			end,
		},
		{
			title = "首次输入后开始",
			checked = state.start_next_cycle == "on_input",
			fn = function()
				update_runtime_overrides({
					start_next_cycle = "on_input",
				}, "已切换为休息结束后等待首次输入再开始")
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
		return string.format(
			"休息剩余: %s | 当前休息: %s",
			format_seconds(math.max(0, break_ends_at - os.time())),
			format_compact_duration(current_break_duration_seconds or effective_rest_seconds())
		)
	end

	if next_break_at ~= nil then
		return string.format("下次休息: %s", format_seconds(math.max(0, next_break_at - os.time())))
	end

	return "等待新一轮计时"
end

local function menu_config_summary()
	local penalty_seconds = current_skip_penalty_seconds()

	return string.format(
		"%s | 工%s | 休%s%s",
		short_mode_label(select(1, effective_mode())),
		format_compact_duration(state.work_seconds),
		format_compact_duration(state.rest_seconds),
		penalty_seconds > 0 and ("+" .. format_compact_duration(penalty_seconds)) or ""
	)
end

local function menu_config_source_label()
	if table_is_empty(runtime_overrides) then
		return "配置: 文件"
	end

	return "配置: 文件+菜单"
end

local function build_menu()
	ensure_gamification_metrics_current()

	local status_title = current_status()

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
			title = string.format(
				"今日专注 %s | 连胜 %d 天 | 跳过 %d 次",
				format_compact_duration(gamification_metrics.today_focus_seconds),
				current_streak_days(),
				gamification_metrics.today_skipped_breaks
			),
			disabled = true,
		},
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

				update_runtime_overrides({
					enabled = enabled,
				}, enabled and "已启用休息提醒" or "已关闭休息提醒")
			end,
		},
		{
			title = "图标皮肤",
			disabled = state.show_menubar ~= true,
			menu = build_menubar_skin_menu(),
		},
		{
			title = "行为反馈",
			menu = build_gamification_menu(),
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
			title = "跳过本次休息",
			disabled = break_ends_at == nil,
			fn = function()
				skip_break("manual skip from menubar")
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
			title = "恢复默认",
			disabled = table_is_empty(runtime_overrides),
			fn = confirm_restore_defaults,
		},
	}
end

refresh_menubar = function(force_refresh)
	force_refresh = force_refresh == true

	if state.show_menubar ~= true then
		stop_menubar_status_timer()
		last_menubar_render_signature = nil
		last_menubar_tooltip = nil

		if menubar_item ~= nil then
			menubar_item:delete()
			menubar_item = nil
		end

		return
	end

	if menubar_item == nil then
		menubar_item = hs.menubar.new(true, menubar_autosave_name)

		if menubar_item == nil then
			log.e("failed to create break reminder menubar item")
			return
		end

		last_menubar_render_signature = nil
		last_menubar_tooltip = nil
	end

	if force_refresh == true then
		last_menubar_render_signature = nil
		last_menubar_tooltip = nil
	end

	if type(menubar_item.autosaveName) == "function" then
		pcall(function()
			menubar_item:autosaveName(menubar_autosave_name)
		end)
	end

	menubar_item:setMenu(build_menu)
	update_menubar_status()
	start_menubar_status_timer()
end

local function ensure_screen_watcher()
	if _M.screen_watcher ~= nil then
		return
	end

	_M.screen_watcher = hs.screen.watcher.new(function()
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
	end)
end

local function ensure_caffeinate_watcher()
	if _M.caffeinate_watcher ~= nil then
		return
	end

	_M.caffeinate_watcher = hs.caffeinate.watcher.new(function(event)
		if
			event == hs.caffeinate.watcher.screensDidLock
			or event == hs.caffeinate.watcher.screensDidSleep
			or event == hs.caffeinate.watcher.systemWillSleep
			or event == hs.caffeinate.watcher.sessionDidResignActive
		then
			reset_cycle_for_inactive_session(tostring(event))
			return
		end

		if
			event ~= hs.caffeinate.watcher.systemDidWake
			and event ~= hs.caffeinate.watcher.screensDidWake
			and event ~= hs.caffeinate.watcher.screensDidUnlock
			and event ~= hs.caffeinate.watcher.sessionDidBecomeActive
		then
			return
		end

		if session_is_inactive ~= true then
			return
		end

		if try_resume_after_inactive_session("caffeinate watcher resume event") ~= true then
			log.i("session is still locked/inactive after wake, waiting for a later retry")
			return
		end
	end)
end

local function start_watchers()
	ensure_screen_watcher()
	ensure_caffeinate_watcher()

	if _M.screen_watcher ~= nil then
		_M.screen_watcher:start()
	end

	if _M.caffeinate_watcher ~= nil then
		_M.caffeinate_watcher:start()
	end
end

local function stop_watchers()
	if _M.screen_watcher ~= nil then
		_M.screen_watcher:stop()
	end

	if _M.caffeinate_watcher ~= nil then
		_M.caffeinate_watcher:stop()
	end
end

function _M.start()
	if started == true then
		return true
	end

	started = true
	start_watchers()

	session_is_inactive = can_resume_after_inactive_session() ~= true

	if session_is_inactive == true then
		start_inactive_resume_timer()
	else
		stop_inactive_resume_timer()
	end

	ensure_gamification_metrics_current()
	refresh_menubar()

	if state.enabled == true and session_is_inactive ~= true then
		schedule_next_break("module start")
	else
		update_menubar_status()
	end

	return true
end

_M.start_break_now = function()
	start_break("manual api start")
end

_M.skip_break_now = function()
	return skip_break("manual api skip")
end

_M.reset_cycle = function()
	restart_work_cycle("manual api reset")
end

_M.clear_runtime_overrides = function()
	clear_runtime_overrides("manual api clear")
end

_M.restore_defaults = function()
	return confirm_restore_defaults()
end

_M.refresh_menubar = function(force_refresh)
	refresh_menubar(force_refresh == true)
end

_M.stop = function()
	if started ~= true then
		stop_watchers()
		stop_inactive_resume_timer()
		return true
	end

	clear_active_runtime(true)
	stop_inactive_resume_timer()
	stop_menubar_status_timer()
	stop_watchers()

	if menubar_item ~= nil then
		menubar_item:delete()
		menubar_item = nil
	end

	last_menubar_render_signature = nil
	last_menubar_tooltip = nil
	session_is_inactive = false
	started = false

	return true
end

_M.get_state = function()
	local break_completion_rate, break_completion_opportunities = current_break_completion_rate()
	local menubar_in_menu_bar = nil
	local menubar_frame = nil
	local menubar_title = nil

	if menubar_item ~= nil and type(menubar_item.isInMenuBar) == "function" then
		local ok, is_in_menu_bar = pcall(function()
			return menubar_item:isInMenuBar()
		end)

		if ok == true then
			menubar_in_menu_bar = is_in_menu_bar == true
		end
	end

	if menubar_item ~= nil and type(menubar_item.frame) == "function" then
		local ok, frame = pcall(function()
			return menubar_item:frame()
		end)

		if ok == true and frame ~= nil then
			menubar_frame = {
				x = frame.x,
				y = frame.y,
				w = frame.w,
				h = frame.h,
			}
		end
	end

	if menubar_item ~= nil and type(menubar_item.title) == "function" then
		local ok, title = pcall(function()
			return menubar_item:title()
		end)

		if ok == true then
			menubar_title = title
		end
	end

	return {
		enabled = state.enabled,
		show_menubar = state.show_menubar,
		menubar_exists = menubar_item ~= nil,
		menubar_in_menu_bar = menubar_in_menu_bar,
		menubar_frame = menubar_frame,
		menubar_title = menubar_title,
		menubar_skin = state.menubar_skin,
		start_next_cycle = state.start_next_cycle,
		mode = state.mode,
		effective_mode = select(1, effective_mode()),
		minimal_display = state.minimal_display,
		work_seconds = state.work_seconds,
		rest_seconds = state.rest_seconds,
		effective_rest_seconds = effective_rest_seconds(),
		focus_goal_seconds = state.focus_goal_seconds,
		break_goal_count = state.break_goal_count,
		strict_mode_after_skips = state.strict_mode_after_skips,
		rest_penalty_seconds_per_skip = state.rest_penalty_seconds_per_skip,
		max_rest_penalty_seconds = state.max_rest_penalty_seconds,
		friendly_reminder_seconds = state.friendly_reminder_seconds,
		friendly_reminder_duration_seconds = state.friendly_reminder_duration_seconds,
		friendly_reminder_message = state.friendly_reminder_message,
		overlay_opacity = state.overlay_opacity,
		break_ends_at = break_ends_at,
		next_break_at = next_break_at,
		work_cycle_started_at = work_cycle_started_at,
		current_work_cycle_duration_seconds = current_work_cycle_duration_seconds,
		current_break_duration_seconds = current_break_duration_seconds,
		last_work_session_seconds = last_work_session_seconds,
		session_is_inactive = session_is_inactive,
		waiting_for_resume_input = waiting_for_resume_input,
		gamification = shallow_copy(gamification_metrics),
		current_streak_days = current_streak_days(),
		break_goal_reached = break_goal_reached(),
		break_completion_rate = break_completion_rate,
		break_completion_opportunities = break_completion_opportunities,
		break_completion_rate_label = break_completion_rate_label(),
		gamification_points = gamification_points(),
		gamification_rank = gamification_rank_label(),
		runtime_overrides = shallow_copy(runtime_overrides),
	}
end

return _M
