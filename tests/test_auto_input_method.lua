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
	loaded_modules["auto_input_method"] = nil
	loaded_modules["keybindings_config"] = nil
end

function _M.run()
	reset_modules()

		local recorded = {
			watcher_started = 0,
			watcher_stopped = 0,
			switched_to = {},
		}
		local frontmost_app = {
			bundleID = function()
				return "com.google.Chrome"
			end,
		}

		hs = {
			logger = {
				new = function()
					return {
						d = function() end,
						e = function() end,
						w = function() end,
					}
				end,
			},
			application = {
				frontmostApplication = function()
					return frontmost_app
				end,
				watcher = {
					activated = "activated",
					new = function(callback)
					recorded.callback = callback

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
			},
			keycodes = {
				currentSourceID = function(source_id)
					table.insert(recorded.switched_to, source_id)
					return true
				end,
			},
		}

	loaded_modules["keybindings_config"] = {
		auto_input_methods = {
			["com.google.Chrome"] = "com.apple.keylayout.ABC",
		},
	}

		local auto_input_method = require("auto_input_method")

		assert_true(auto_input_method.start(), "auto_input_method.start() should succeed")
		assert_equal(recorded.watcher_started, 1, "module should start application watcher")
		assert_equal(#recorded.switched_to, 1, "startup should synchronize the current frontmost application")
		assert_equal(recorded.switched_to[1], "com.apple.keylayout.ABC", "startup sync should use the configured input source")

		recorded.callback("Chrome", "deactivated", {
			bundleID = function()
			return "com.google.Chrome"
		end,
	})
	recorded.callback("Chrome", "activated", nil)
	recorded.callback("Unknown", "activated", {
		bundleID = function()
			return nil
		end,
	})
		recorded.callback("Chrome", "activated", {
			bundleID = function()
				return "com.google.Chrome"
			end,
		})

		assert_equal(#recorded.switched_to, 2, "only mapped activated apps should switch input source after startup sync")
		assert_equal(recorded.switched_to[2], "com.apple.keylayout.ABC", "mapped app activation should switch to configured input source")

		auto_input_method.stop()
		assert_equal(recorded.watcher_stopped, 1, "stop should stop application watcher")

		reset_modules()

		loaded_modules["keybindings_config"] = {
			auto_input_methods = {
				["com.google.Chrome"] = "com.apple.keylayout.ABC",
			},
		}

		hs.application.watcher.new = function()
			return nil
		end

		auto_input_method = require("auto_input_method")
		assert_true(auto_input_method.start() == false, "module should surface watcher creation failures")

		reset_modules()
		hs = nil
end

return _M
