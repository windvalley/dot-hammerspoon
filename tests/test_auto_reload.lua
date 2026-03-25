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
	loaded_modules["auto_reload"] = nil
end

function _M.run()
	reset_modules()

		local recorded = {
			reloads = 0,
			timer_stops = 0,
			watcher_started = 0,
			watcher_stopped = 0,
			settings_store = {},
		}

	hs = {
		logger = {
			new = function()
				return {
					i = function() end,
				}
			end,
		},
			configdir = "/tmp/hammerspoon",
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
			timer = {
			doAfter = function(delay, fn)
				recorded.last_delay = delay
				recorded.pending_timer = fn

				return {
					stop = function()
						recorded.timer_stops = recorded.timer_stops + 1
					end,
				}
			end,
		},
		pathwatcher = {
			new = function(path, callback)
				recorded.watch_path = path
				recorded.watch_callback = callback

				return {
					start = function()
						recorded.watcher_started = recorded.watcher_started + 1
					end,
					stop = function()
						recorded.watcher_stopped = recorded.watcher_stopped + 1
					end,
				}
			end,
		},
		alert = {
			show = function(message)
				recorded.last_alert = message
			end,
		},
		reload = function()
			recorded.reloads = recorded.reloads + 1
		end,
	}

	local auto_reload = require("auto_reload")

		assert_true(auto_reload.start(), "auto_reload.start() should succeed")
		assert_equal(recorded.watch_path, "/tmp/hammerspoon", "watcher should be created for hs.configdir")
		assert_equal(recorded.watcher_started, 1, "watcher should start on module start")
		assert_equal(recorded.last_alert, nil, "cold startup should not claim that a reload already happened")

	recorded.watch_callback({
		"/tmp/hammerspoon/README.md",
	}, {
		{ itemModified = true, itemIsFile = true },
	})
	assert_equal(recorded.pending_timer, nil, "non-lua file changes should not schedule reload")

	recorded.watch_callback({
		"/tmp/hammerspoon/Spoons",
	}, {
		{ mustScanSubDirs = true },
		})
		assert_true(type(recorded.pending_timer) == "function", "recursive scan events should schedule reload")
		recorded.pending_timer()
		assert_equal(recorded.reloads, 1, "scheduled reload should call hs.reload")
		assert_equal(recorded.last_delay, 0.25, "reload debounce delay should match module default")
		assert_equal(recorded.settings_store["auto_reload.pending_notification"], true, "scheduled reload should persist a notification marker")

		recorded.pending_timer = nil
	recorded.watch_callback({
		"/tmp/hammerspoon/init.lua",
	}, {
		{ itemModified = true, itemIsFile = true },
	})
	assert_true(type(recorded.pending_timer) == "function", "lua file changes should schedule reload")

		auto_reload.stop()
		assert_equal(recorded.timer_stops, 1, "stop should cancel pending reload timer")
		assert_equal(recorded.watcher_stopped, 1, "stop should stop watcher")

		reset_modules()
		auto_reload = require("auto_reload")
		assert_true(auto_reload.start(), "module should start again after a reload")
		assert_equal(recorded.last_alert, "hammerspoon reloaded", "reload marker should surface the post-reload alert")
		assert_equal(recorded.settings_store["auto_reload.pending_notification"], nil, "post-reload alert should clear the notification marker")

		reset_modules()
		hs = nil
end

return _M
