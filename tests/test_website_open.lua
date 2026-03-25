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
	loaded_modules["website_open"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		bindings = {},
		opened_urls = {},
		deleted_bindings = 0,
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
		urlevent = {
			openURL = function(url)
				table.insert(recorded.opened_urls, url)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		websites = {
			{ prefix = { "Option" }, key = "8", message = "github.com", target = "https://github.com" },
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

	local website_open = require("website_open")

	assert_true(website_open.start(), "website_open.start() should succeed")
	assert_equal(#recorded.bindings, 1, "module should register one website hotkey")

	recorded.bindings[1].pressedfn()
	assert_equal(recorded.opened_urls[1], "https://github.com", "hotkey should open configured website")

	website_open.stop()
	assert_equal(recorded.deleted_bindings, 1, "stop should delete registered bindings")

	reset_modules()
	hs = nil
end

return _M
