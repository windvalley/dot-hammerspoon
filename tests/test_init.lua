local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function assert_contains(text, expected, message)
	if tostring(text or ""):find(expected, 1, true) == nil then
		error(string.format("%s: expected to find %s in %s", message or "assert_contains failed", tostring(expected), tostring(text)))
	end
end

local module_names = {
	"init",
	"app_launch",
	"window_manipulation",
	"system_manage",
	"keep_awake",
	"website_open",
	"clipboard_center",
	"manual_input_method",
	"auto_input_method",
	"bing_daily_wallpaper",
	"break_reminder",
	"keybindings_cheatsheet",
	"auto_reload",
}

local function reset_modules()
	for _, name in ipairs(module_names) do
		loaded_modules[name] = nil
	end
end

function _M.run()
	reset_modules()

	local recorded = {
		alerts = {},
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
					i = function() end,
				}
			end,
		},
		accessibilityState = function()
			return true
		end,
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
		autoLaunch = function() end,
		automaticallyCheckForUpdates = function() end,
		consoleOnTop = function() end,
		dockIcon = function() end,
		menuIcon = function() end,
		uploadCrashData = function() end,
		hotkey = {
			alertDuration = 0,
		},
		window = {
			animationDuration = 0,
		},
		shutdownCallback = nil,
	}

	for _, name in ipairs(module_names) do
		if name ~= "init" then
			loaded_modules[name] = {
				start = function()
					if name == "clipboard_center" then
						return false
					end

					return true
				end,
				stop = function()
					return true
				end,
			}
		end
	end

	local init_module = require("init")

	assert_true(type(init_module) == "table", "init should load successfully")
	assert_contains(recorded.alerts[1], "clipboard_center", "startup warning should identify the failed module")
	assert_contains(recorded.alerts[1], "start() 返回 false", "startup warning should explain the failed start hook")

	reset_modules()
	hs = nil
end

return _M
