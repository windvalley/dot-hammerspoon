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
	loaded_modules["manual_input_method"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		bindings = {},
		deleted_bindings = 0,
		switched_to = {},
	}

	hs = {
		logger = {
			new = function()
				return {
					d = function() end,
				}
			end,
		},
		fnutils = {
			each = function(items, fn)
				for _, item in ipairs(items or {}) do
					fn(item)
				end
			end,
		},
		keycodes = {
			currentSourceID = function(source_id)
				table.insert(recorded.switched_to, source_id)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		manual_input_methods = {
			{ prefix = { "Option" }, key = "1", message = "ABC", input_method = "com.apple.keylayout.ABC" },
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

	local manual_input_method = require("manual_input_method")

	assert_true(manual_input_method.start(), "manual_input_method.start() should succeed")
	assert_equal(#recorded.bindings, 1, "module should register one manual input hotkey")

	recorded.bindings[1].pressedfn()
	assert_equal(recorded.switched_to[1], "com.apple.keylayout.ABC", "hotkey should switch to configured input source")

	manual_input_method.stop()
	assert_equal(recorded.deleted_bindings, 1, "stop should delete registered bindings")

	reset_modules()
	hs = nil
end

return _M
