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

local function assert_nil(value, message)
	if value ~= nil then
		error(string.format("%s: expected nil, got %s", message or "assert_nil failed", tostring(value)))
	end
end

local function reset_modules()
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		warnings = {},
		errors = {},
	}

	hs = {
		logger = {
			new = function()
				return {
					w = function(message)
						table.insert(recorded.warnings, message)
					end,
					e = function(message)
						table.insert(recorded.errors, message)
					end,
				}
			end,
		},
		hotkey = {
			systemAssigned = function()
				return false
			end,
			assignable = function()
				return true
			end,
			bind = function(...)
				recorded.last_bind_args = { ... }
				error("bind failed")
			end,
		},
	}

	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
	}

	local hotkey_helper = require("hotkey_helper")
	local normalized, invalid = hotkey_helper.normalize_hotkey_modifiers("command + shift + option + command")

	assert_equal(table.concat(normalized, ","), "alt,cmd,shift", "normalize should deduplicate and sort modifiers")
	assert_nil(invalid, "valid modifier string should not report invalid token")

	local invalid_normalized, invalid_token = hotkey_helper.normalize_hotkey_modifiers("ctrl+hyper")
	assert_nil(invalid_normalized, "invalid modifier should fail normalization")
	assert_equal(invalid_token, "hyper", "invalid modifier should be returned to caller")

	assert_equal(hotkey_helper.format_hotkey({ "ctrl", "alt" }, "k"), "⌃ ⌥ K", "format should render symbols and uppercase key")

	local binding, bind_error =
		hotkey_helper.bind({ "ctrl" }, "k", "Test", function() end, nil, nil, { logger = hs.logger.new("test") })

	assert_nil(binding, "bind should return nil when hs.hotkey.bind raises")
	assert_true(tostring(bind_error):find("bind failed", 1, true) ~= nil, "bind should surface the underlying error")
	assert_true(#recorded.errors > 0, "bind failure should be logged")

	recorded.errors = {}
	recorded.last_bind_args = nil
	hs.hotkey.bind = function(...)
		recorded.last_bind_args = { ... }
		return {
			delete = function() end,
		}
	end

	local binding_without_message =
		hotkey_helper.bind({ "ctrl" }, "j", nil, function() end, nil, nil, { logger = hs.logger.new("test") })

	assert_true(type(binding_without_message) == "table", "bind should succeed when message is omitted")
	assert_true(type(recorded.last_bind_args[3]) == "function", "bind should pass the pressed callback in the third slot when message is omitted")

	reset_modules()
	hs = nil
end

return _M
