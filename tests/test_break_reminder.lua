local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

local function assert_contains(text, expected, message)
	if tostring(text or ""):find(expected, 1, true) == nil then
		error(string.format("%s: expected to find %s in %s", message or "assert_contains failed", tostring(expected), tostring(text)))
	end
end

local function assert_nil(value, message)
	if value ~= nil then
		error(string.format("%s: expected nil, got %s", message or "assert_nil failed", tostring(value)))
	end
end

local function assert_table_empty(value, message)
	if next(value or {}) ~= nil then
		error(message or "expected empty table")
	end
end

local function reset_modules()
	loaded_modules["break_reminder"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		alerts = {},
		dialog_calls = {},
		dialog_responses = { "取消", "恢复默认" },
		settings_store = {
			["break_reminder.runtime_overrides"] = {
				work_minutes = 42,
				rest_seconds = 180,
			},
		},
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
					d = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return recorded.settings_store[key]
			end,
			set = function(key, value)
				recorded.settings_store[key] = value
			end,
			clear = function(key)
				recorded.settings_store[key] = nil
			end,
		},
		eventtap = {
			event = {
				types = {},
			},
		},
		alert = {
			show = function(message)
				table.insert(recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function(title, informative_text, primary_button, secondary_button)
				table.insert(recorded.dialog_calls, {
					title = title,
					informative_text = informative_text,
					primary_button = primary_button,
					secondary_button = secondary_button,
				})

				return table.remove(recorded.dialog_responses, 1)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		break_reminder = {
			enabled = false,
			show_menubar = false,
			friendly_reminder_message = "还有 {{remaining}} 开始休息",
			work_minutes = 28,
			rest_seconds = 120,
		},
	}

	loaded_modules["utils_lib"] = {
		prompt_text = function()
			return nil
		end,
	}

	local break_reminder = require("break_reminder")
	local state = break_reminder.get_state()

	assert_equal(state.work_seconds, 42 * 60, "runtime override should replace configured work duration")
	assert_equal(state.rest_seconds, 180, "runtime override should replace configured rest duration")
	assert_equal(state.friendly_reminder_duration_seconds, 10, "default friendly reminder duration should match config documentation")
	assert_nil(break_reminder.export_current_config_to_file, "export api should be removed")

	local cancelled = break_reminder.restore_defaults()

	assert_equal(cancelled, false, "cancelled restore should return false")
	state = break_reminder.get_state()
	assert_equal(state.work_seconds, 42 * 60, "cancelled restore should keep runtime override")
	assert_equal(state.rest_seconds, 180, "cancelled restore should not reset rest duration")
	assert_equal(#recorded.dialog_calls, 1, "restore should show a confirmation dialog")
	assert_contains(recorded.dialog_calls[1].title, "恢复默认", "dialog title should match restore defaults action")
	assert_contains(
		recorded.dialog_calls[1].informative_text,
		"恢复为 keybindings_config.lua 中定义的默认值",
		"dialog should explain the fallback target"
	)

	local restored = break_reminder.restore_defaults()

	assert_true(restored, "confirmed restore should return true")
	state = break_reminder.get_state()
	assert_equal(state.work_seconds, 28 * 60, "confirmed restore should revert to configured default work duration")
	assert_equal(state.rest_seconds, 120, "confirmed restore should revert to configured default rest duration")
	assert_table_empty(state.runtime_overrides, "confirmed restore should clear runtime overrides from state")
	assert_nil(recorded.settings_store["break_reminder.runtime_overrides"], "confirmed restore should clear persisted overrides")
	assert_contains(recorded.alerts[#recorded.alerts], "已恢复默认配置", "confirmed restore should surface a success message")

	reset_modules()

	local lifecycle_recorded = {
		alerts = {},
		settings_store = {},
		after_timers = {},
		every_timers = {},
		screen_watcher_started = 0,
		screen_watcher_stopped = 0,
		caffeinate_watcher_started = 0,
		caffeinate_watcher_stopped = 0,
		overlay_canvas_deleted = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
					d = function() end,
				}
			end,
		},
		settings = {
			get = function(key)
				return lifecycle_recorded.settings_store[key]
			end,
			set = function(key, value)
				lifecycle_recorded.settings_store[key] = value
			end,
			clear = function(key)
				lifecycle_recorded.settings_store[key] = nil
			end,
		},
		eventtap = {
			event = {
				types = {},
			},
		},
		timer = {
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				table.insert(lifecycle_recorded.after_timers, timer)

				return timer
			end,
			doEvery = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				table.insert(lifecycle_recorded.every_timers, timer)

				return timer
			end,
		},
		alert = {
			show = function(message)
				table.insert(lifecycle_recorded.alerts, message)
			end,
		},
		dialog = {
			blockAlert = function()
				return "取消"
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
			canvas = {
				windowLevels = {
					screenSaver = 1,
				},
				new = function(frame)
					local canvas_state = {
						frame = frame,
					}

				return {
					behaviorAsLabels = function() end,
					clickActivating = function() end,
					level = function() end,
					appendElements = function() end,
					minimumTextSize = function(_, text)
						return {
							w = #tostring(text or ""),
							h = 10,
						}
					end,
					frame = function(_, value)
						if value ~= nil then
							canvas_state.frame = value
						end

						return canvas_state.frame
					end,
					show = function() end,
					hide = function() end,
					delete = function()
						lifecycle_recorded.overlay_canvas_deleted = lifecycle_recorded.overlay_canvas_deleted + 1
					end,
					mouseCallback = function() end,
				}
			end,
		},
		screen = {
			allScreens = function()
				return {
					{
						fullFrame = function()
							return { x = 0, y = 0, w = 1440, h = 900 }
						end,
					},
				}
			end,
			watcher = {
				new = function()
					return {
						start = function()
							lifecycle_recorded.screen_watcher_started = lifecycle_recorded.screen_watcher_started + 1
						end,
						stop = function()
							lifecycle_recorded.screen_watcher_stopped = lifecycle_recorded.screen_watcher_stopped + 1
						end,
					}
				end,
			},
		},
		caffeinate = {
			sessionProperties = function()
				return {
					CGSSessionScreenIsLocked = false,
					kCGSSessionOnConsoleKey = true,
				}
			end,
				watcher = {
					screensDidLock = 1,
					screensDidSleep = 2,
					systemWillSleep = 3,
					sessionDidResignActive = 4,
					systemDidWake = 5,
					screensDidWake = 6,
					screensDidUnlock = 7,
					sessionDidBecomeActive = 8,
					new = function(callback)
						lifecycle_recorded.caffeinate_callback = callback
						return {
							start = function()
								lifecycle_recorded.caffeinate_watcher_started = lifecycle_recorded.caffeinate_watcher_started + 1
						end,
						stop = function()
							lifecycle_recorded.caffeinate_watcher_stopped = lifecycle_recorded.caffeinate_watcher_stopped + 1
						end,
					}
				end,
			},
		},
		application = {
			frontmostApplication = function()
				return nil
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		break_reminder = {
			enabled = true,
			show_menubar = false,
			mode = "soft",
			minimal_display = true,
			start_next_cycle = "auto",
			work_minutes = 15,
			rest_seconds = 90,
			friendly_reminder_seconds = 0,
			focus_goal_minutes = 60,
			break_goal_count = 0,
			strict_mode_after_skips = 0,
			rest_penalty_seconds_per_skip = 0,
			max_rest_penalty_seconds = 0,
		},
	}

	loaded_modules["utils_lib"] = {
		prompt_text = function()
			return nil
		end,
	}

	break_reminder = require("break_reminder")

	assert_true(break_reminder.start(), "enabled reminder module should start successfully")
	state = break_reminder.get_state()
		assert_equal(state.current_work_cycle_duration_seconds, 15 * 60, "start should schedule a work cycle")
		assert_true(state.next_break_at ~= nil, "start should record next break timestamp")
		assert_equal(lifecycle_recorded.screen_watcher_started, 1, "start should activate screen watcher")
		assert_equal(lifecycle_recorded.caffeinate_watcher_started, 1, "start should activate caffeinate watcher")
		assert_true(type(lifecycle_recorded.caffeinate_callback) == "function", "start should create a caffeinate watcher callback")

		lifecycle_recorded.caffeinate_callback(hs.caffeinate.watcher.screensDidSleep)
		state = break_reminder.get_state()
		assert_equal(state.session_is_inactive, true, "display sleep should pause the active work cycle")
		assert_nil(state.next_break_at, "display sleep should clear the pending work timer target")

		lifecycle_recorded.caffeinate_callback(hs.caffeinate.watcher.screensDidWake)
		state = break_reminder.get_state()
		assert_equal(state.session_is_inactive, false, "display wake should resume the reminder session")
		assert_true(state.next_break_at ~= nil, "display wake should restart the next work cycle")

		break_reminder.start_break_now()
	state = break_reminder.get_state()
	assert_true(state.break_ends_at ~= nil, "manual start should enter break state")
	assert_equal(state.current_break_duration_seconds, 90, "manual start should use configured rest duration")
	assert_equal(state.next_break_at, nil, "break state should clear pending work timer target")

	assert_true(break_reminder.skip_break_now(), "skip api should succeed during an active break")
	state = break_reminder.get_state()
	assert_equal(state.gamification.today_skipped_breaks, 1, "skip should increase skipped break count")
	assert_equal(state.break_ends_at, nil, "skip should leave break state")
	assert_equal(state.current_work_cycle_duration_seconds, 15 * 60, "skip should immediately schedule the next work cycle")
	assert_true(state.next_break_at ~= nil, "skip should schedule another break")

	assert_true(break_reminder.stop(), "stop should succeed after lifecycle transitions")
	assert_equal(lifecycle_recorded.screen_watcher_stopped, 1, "stop should deactivate screen watcher")
	assert_equal(lifecycle_recorded.caffeinate_watcher_stopped, 1, "stop should deactivate caffeinate watcher")
	assert_true(lifecycle_recorded.overlay_canvas_deleted >= 1, "stop should clean up rendered overlays")

	reset_modules()
	hs = nil
end

return _M
