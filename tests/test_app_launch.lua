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
	loaded_modules["app_launch"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		bindings = {},
		launches = {},
		hide_count = 0,
		deleted_bindings = 0,
	}
	local frontmost_app = nil

		hs = {
			logger = {
				new = function()
					return {
						d = function() end,
						w = function() end,
					}
				end,
			},
			application = {
				frontmostApplication = function()
					return frontmost_app
				end,
				launchOrFocusByBundleID = function(bundle_id)
					table.insert(recorded.launches, bundle_id)
					return true
				end,
			},
		fnutils = {
			each = function(items, fn)
				for _, item in ipairs(items or {}) do
					fn(item)
				end
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		apps = {
			{ prefix = { "Option" }, key = "C", message = "Chrome", bundleId = "com.google.Chrome" },
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

	local app_launch = require("app_launch")

	assert_true(app_launch.start(), "module should start")
	assert_equal(#recorded.bindings, 1, "module should register one hotkey binding")

	recorded.bindings[1].pressedfn()
	assert_equal(recorded.launches[#recorded.launches], "com.google.Chrome", "nil frontmost app should fall back to launch")

		frontmost_app = {
			bundleID = function()
				return "com.google.Chrome"
			end,
			hide = function()
				recorded.hide_count = recorded.hide_count + 1
				return true
			end,
		}

	recorded.bindings[1].pressedfn()
	assert_equal(recorded.hide_count, 1, "focused target app should be hidden")

	app_launch.stop()
	assert_equal(recorded.deleted_bindings, 1, "stop should delete registered bindings")

	reset_modules()

	recorded = {
		bindings = {},
		launches = {},
		hide_count = 0,
		deleted_bindings = 0,
	}

	loaded_modules["keybindings_config"] = {
		apps = {
			{ prefix = { "Option" }, key = "C", message = "Chrome", bundleId = "com.google.Chrome" },
		},
	}

	loaded_modules["hotkey_helper"] = {
		bind = function()
			return nil, "bind failed"
		end,
	}

	app_launch = require("app_launch")
	assert_true(app_launch.start() == false, "module should report startup failure when any hotkey binding fails")

	reset_modules()
	hs = nil
end

return _M
