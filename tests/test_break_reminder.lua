local _M = {}
local loaded_modules = rawget(package, "loaded")
local original_searchpath = rawget(package, "searchpath")

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

local function reset_modules()
	loaded_modules["break_reminder"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		alerts = {},
		reloaded = false,
		settings_store = {},
	}
	local temp_path = os.tmpname() .. ".lua"
	local file = assert(io.open(temp_path, "w"))

	file:write(table.concat({
		"local _M = {}",
		"",
		"_M.break_reminder = {",
		"\tshow_menubar = true,",
		"\t-- placeholders: {{remaining}} {{rest}}",
		'\tfriendly_reminder_message = "还有 {{remaining}} 开始休息",',
		"\twork_minutes = 28,",
		"\trest_seconds = 120,",
		"}",
		"",
		"return _M",
	}, "\n"))
	file:close()

	rawset(package, "searchpath", function(name, path)
		if name == "keybindings_config" then
			return temp_path
		end

		return original_searchpath(name, path)
	end)

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
		timer = {
			doAfter = function(_, fn)
				fn()
			end,
		},
		reload = function()
			recorded.reloaded = true
		end,
	}

	loaded_modules["keybindings_config"] = {
		break_reminder = {
			enabled = true,
			show_menubar = true,
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

	assert_equal(state.friendly_reminder_duration_seconds, 10, "default friendly reminder duration should match config documentation")

	break_reminder.export_current_config_to_file()

	local updated_file = assert(io.open(temp_path, "r"))
	local updated_content = updated_file:read("*a")

	updated_file:close()

	assert_contains(
		updated_content,
		"friendly_reminder_duration_seconds = 10,",
		"exported config should include the aligned default duration"
	)
	assert_contains(updated_content, "{{remaining}}", "export should preserve placeholder braces inside strings and comments")
	assert_true(recorded.reloaded, "export should trigger a reload callback")
	assert_contains(recorded.alerts[#recorded.alerts], "已导出到 keybindings_config.lua", "export should surface a success message")

	os.remove(temp_path)
	rawset(package, "searchpath", original_searchpath)
	reset_modules()
	hs = nil
end

return _M
