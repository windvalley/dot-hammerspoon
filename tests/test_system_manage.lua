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
	loaded_modules["system_manage"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		bindings = {},
		deleted_bindings = 0,
		lock_count = 0,
		screensaver_count = 0,
		restart_count = 0,
		shutdown_count = 0,
		dialog_responses = { "取消", "重启", "关机" },
	}

	hs = {
		logger = {
			new = function()
				return {
					d = function() end,
					i = function() end,
				}
			end,
		},
		caffeinate = {
			lockScreen = function()
				recorded.lock_count = recorded.lock_count + 1
			end,
			startScreensaver = function()
				recorded.screensaver_count = recorded.screensaver_count + 1
			end,
			restartSystem = function()
				recorded.restart_count = recorded.restart_count + 1
			end,
			shutdownSystem = function()
				recorded.shutdown_count = recorded.shutdown_count + 1
			end,
		},
		dialog = {
			blockAlert = function()
				return table.remove(recorded.dialog_responses, 1)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		system = {
			lock_screen = { prefix = { "Option" }, key = "Q", message = "Lock Screen" },
			screen_saver = { prefix = { "Option" }, key = "S", message = "Start Screensaver" },
			restart = { prefix = { "Ctrl", "Option" }, key = "R", message = "Restart Computer" },
			shutdown = { prefix = { "Ctrl", "Option" }, key = "X", message = "Shutdown Computer" },
		},
	}

	loaded_modules["hotkey_helper"] = {
		bind = function(modifiers, key, message, pressedfn)
			local binding = {
				modifiers = modifiers,
				key = key,
				message = message,
				pressedfn = pressedfn,
				delete = function()
					recorded.deleted_bindings = recorded.deleted_bindings + 1
				end,
			}

			table.insert(recorded.bindings, binding)

			return binding
		end,
	}

	local system_manage = require("system_manage")

	assert_true(system_manage.start(), "system_manage.start() should succeed")
	assert_equal(#recorded.bindings, 4, "module should register all system hotkeys")

	recorded.bindings[1].pressedfn()
	recorded.bindings[2].pressedfn()
	recorded.bindings[3].pressedfn()
	recorded.bindings[3].pressedfn()
	recorded.bindings[4].pressedfn()

	assert_equal(recorded.lock_count, 1, "lock screen hotkey should trigger lock")
	assert_equal(recorded.screensaver_count, 1, "screensaver hotkey should trigger screensaver")
	assert_equal(recorded.restart_count, 1, "restart should only occur after confirmation")
	assert_equal(recorded.shutdown_count, 1, "shutdown should occur after confirmation")

	system_manage.stop()
	assert_equal(recorded.deleted_bindings, 4, "stop should delete all registered bindings")

	reset_modules()
	hs = nil
end

return _M
