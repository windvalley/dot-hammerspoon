local _M = {}
local loaded_modules = rawget(package, "loaded")

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

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function reset_modules()
	loaded_modules["keep_awake"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["hotkey_helper"] = nil
	loaded_modules["utils_lib"] = nil
end

function _M.run()
	reset_modules()

	local recorded = {
		alerts = {},
		caffeinate_sets = {},
		menubar_created = 0,
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
		settings = {
			get = function()
				return nil
			end,
			set = function() end,
			clear = function() end,
		},
		host = {
			interfaceStyle = function()
				return "Light"
			end,
		},
		styledtext = {
			new = function(text)
				return {
					value = text,
					setStyle = function(self)
						return self
					end,
				}
			end,
		},
		canvas = {
			new = function()
				return {
					appendElements = function() end,
					imageFromCanvas = function()
						return {
							size = function() end,
						}
					end,
					delete = function() end,
				}
			end,
		},
		menubar = {
			new = function()
				recorded.menubar_created = recorded.menubar_created + 1

				return {
					setMenu = function(_, builder)
						recorded.menu_builder = builder
					end,
					setIcon = function() end,
					setTitle = function() end,
					setTooltip = function(_, tooltip)
						recorded.tooltip = tooltip
					end,
					delete = function()
						recorded.menubar_deleted = true
					end,
				}
			end,
		},
		caffeinate = {
			set = function(kind, value)
				recorded.caffeinate_sets[kind] = value
			end,
		},
		alert = {
			show = function(message)
				table.insert(recorded.alerts, message)
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		system = {
			keep_awake = {
				enabled = false,
				show_menubar = false,
				prefix = { "Option" },
				key = "A",
				message = "Toggle Prevent Sleep",
			},
		},
	}

	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		copy_list = function(items)
			local copied = {}

			for _, item in ipairs(items or {}) do
				table.insert(copied, item)
			end

			return copied
		end,
		prompt_text = function()
			return nil
		end,
	}

	loaded_modules["hotkey_helper"] = {
		normalize_hotkey_modifiers = function(modifiers)
			return modifiers or {}
		end,
		format_hotkey = function(modifiers, key)
			return table.concat(modifiers or {}, "+") .. (key and ("+" .. key) or "")
		end,
		modifier_prompt_names = {
			Option = "option",
		},
		bind = function()
			return nil, "bind failed"
		end,
	}

	local keep_awake = require("keep_awake")

	assert_true(keep_awake.start(), "module should still start when hotkey binding fails")
	assert_equal(recorded.menubar_created, 1, "startup hotkey failure should force-create a menubar item")
	assert_contains(recorded.alerts[#recorded.alerts], "防休眠快捷键绑定失败", "startup should surface a hotkey failure alert")
	assert_contains(recorded.alerts[#recorded.alerts], "已临时显示菜单栏图标", "startup should restore a visible recovery entry point")
	assert_equal(recorded.caffeinate_sets.displayIdle, false, "startup should still apply display idle state")
	assert_equal(recorded.caffeinate_sets.systemIdle, false, "startup should still apply system idle state")

	keep_awake.stop()
	assert_equal(recorded.menubar_deleted, true, "stop should delete the recovery menubar item")

	reset_modules()
	hs = nil
end

return _M
