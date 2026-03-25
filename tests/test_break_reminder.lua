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
	hs = nil
end

return _M
