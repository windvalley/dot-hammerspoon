local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function reset_modules()
	loaded_modules["bing_daily_wallpaper"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		timer_started = 0,
		timer_stopped = 0,
		async_get_calls = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
					e = function() end,
					w = function() end,
				}
			end,
		},
		settings = {
			get = function()
				return nil
			end,
			set = function() end,
			clear = function() end,
		},
		timer = {
			doEvery = function()
				recorded.timer_started = recorded.timer_started + 1
				return {
					stop = function()
						recorded.timer_stopped = recorded.timer_stopped + 1
					end,
				}
			end,
		},
		http = {
			asyncGet = function()
				recorded.async_get_calls = recorded.async_get_calls + 1
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		bing_daily_wallpaper = {
			enabled = false,
		},
	}

	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		file_exists = function()
			return false
		end,
		ensure_directory = function()
			return true
		end,
	}

	local wallpaper = require("bing_daily_wallpaper")

	assert_true(wallpaper.start(), "disabled wallpaper module should be treated as a successful no-op start")
	assert_equal(recorded.timer_started, 0, "disabled wallpaper module should not start any refresh timer")

	reset_modules()

	loaded_modules["keybindings_config"] = {
		bing_daily_wallpaper = {
			enabled = true,
			refresh_interval_seconds = 60,
		},
	}
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		file_exists = function()
			return false
		end,
		ensure_directory = function()
			return true
		end,
	}

	local active_wallpaper = require("bing_daily_wallpaper")

	assert_true(active_wallpaper.start(), "enabled wallpaper module should start successfully")
	assert_equal(recorded.timer_started, 1, "enabled wallpaper module should start refresh timer")
	assert_equal(recorded.async_get_calls, 1, "startup should trigger one metadata refresh")
	assert_true(active_wallpaper.stop(), "stop should return true for lifecycle consistency")
	assert_equal(recorded.timer_stopped, 1, "stop should cancel active refresh timer")

	reset_modules()
	hs = nil
end

return _M
