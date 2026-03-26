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
	loaded_modules["key_caster"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["utils_lib"] = nil
end

local function create_canvas_stub(recorded)
	return {
		new = function(frame)
			local state = {
				frame = frame,
				deleted = false,
			}

			table.insert(recorded.canvas_frames, frame)

			return {
				appendElements = function(_, ...)
					for _, element in ipairs({ ... }) do
						if element.type == "text" then
							table.insert(recorded.rendered_text, tostring(element.text))
							table.insert(recorded.text_frames, element.frame)
						end
					end
				end,
				minimumTextSize = function(_, text)
					return {
						w = #tostring(text or "") * 12,
						h = 36,
					}
				end,
				level = function(_, level)
					recorded.levels[#recorded.levels + 1] = level
				end,
				show = function()
					recorded.shown = recorded.shown + 1
				end,
				delete = function()
					if state.deleted ~= true then
						state.deleted = true
						recorded.deleted_canvases = recorded.deleted_canvases + 1
					end
				end,
			}
		end,
		windowLevels = {
			overlay = 9,
		},
	}
end

function _M.run()
	reset_modules()

	local disabled_recorded = {
		eventtap_created = 0,
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = false,
		},
	}
	loaded_modules["utils_lib"] = {
		shallow_copy = function(value)
			local copied = {}

			for key, item in pairs(value or {}) do
				copied[key] = item
			end

			return copied
		end,
	}

	hs.eventtap = {
		new = function()
			disabled_recorded.eventtap_created = disabled_recorded.eventtap_created + 1
		end,
	}

	local key_caster = require("key_caster")
	assert_true(key_caster.start(), "disabled key caster should still start successfully")
	assert_equal(disabled_recorded.eventtap_created, 0, "disabled key caster should not create event taps")
	assert_true(key_caster.stop(), "disabled key caster should stop cleanly")

	reset_modules()

	local recorded = {
		eventtap_created = 0,
		eventtap_started = 0,
		eventtap_stopped = 0,
		rendered_text = {},
		text_frames = {},
		canvas_frames = {},
		levels = {},
		shown = 0,
		deleted_canvases = 0,
		timers = {},
	}

	hs = {
		logger = {
			new = function()
				return {
					e = function() end,
					w = function() end,
				}
			end,
		},
		styledtext = {
			new = function(text)
				return text
			end,
		},
		canvas = create_canvas_stub(recorded),
		timer = {
			doAfter = function(interval, fn)
				local timer = {
					interval = interval,
					callback = fn,
					stopped = false,
					stop = function(self)
						self.stopped = true
					end,
				}

				table.insert(recorded.timers, timer)

				return timer
			end,
		},
		window = {
			focusedWindow = function()
				return nil
			end,
		},
		screen = {
			mainScreen = function()
				return {
					frame = function()
						return { x = 0, y = 0, w = 1440, h = 900 }
					end,
				}
			end,
		},
		keycodes = {
			map = {
				[0] = "a",
				[55] = "cmd",
				[56] = "shift",
			},
		},
		eventtap = {
			event = {
				types = {
					keyDown = 10,
					flagsChanged = 12,
				},
			},
			new = function(_, callback)
				recorded.eventtap_created = recorded.eventtap_created + 1
				recorded.callback = callback

				return {
					start = function()
						recorded.eventtap_started = recorded.eventtap_started + 1
						return true
					end,
					stop = function()
						recorded.eventtap_stopped = recorded.eventtap_stopped + 1
					end,
				}
			end,
		},
	}

	loaded_modules["keybindings_config"] = {
		key_caster = {
			enabled = true,
			position = {
				anchor = "top_right",
				offset_x = 20,
				offset_y = 30,
			},
			font = {
				name = "Monaco",
				size = 36,
			},
			text_color = {
				hex = "#FFFFFF",
				alpha = 1,
			},
			background_color = {
				hex = "#000000",
				alpha = 0.6,
			},
			duration_seconds = 1.5,
		},
	}
	loaded_modules["utils_lib"] = {
		shallow_copy = function(value)
			local copied = {}

			for key, item in pairs(value or {}) do
				copied[key] = item
			end

			return copied
		end,
	}

	key_caster = require("key_caster")

	assert_true(key_caster.start(), "enabled key caster should start")
	assert_equal(recorded.eventtap_created, 1, "enabled key caster should create one event tap")
	assert_equal(recorded.eventtap_started, 1, "enabled key caster should start event tap")

	recorded.callback({
		getType = function()
			return hs.eventtap.event.types.keyDown
		end,
		getKeyCode = function()
			return 0
		end,
		getFlags = function()
			return {
				cmd = true,
				shift = true,
			}
		end,
	})

	assert_equal(recorded.rendered_text[#recorded.rendered_text], "⌘ ⇧ A", "keyDown should render modifier combo and key")
	assert_equal(recorded.canvas_frames[#recorded.canvas_frames].y, 30, "top_right anchor should honor y offset")
	assert_equal(
		recorded.canvas_frames[#recorded.canvas_frames].x,
		1440 - recorded.canvas_frames[#recorded.canvas_frames].w - 20,
		"top_right anchor should honor x offset"
	)
	assert_equal(recorded.timers[#recorded.timers].interval, 1.5, "timer should use configured duration")

	recorded.callback({
		getType = function()
			return hs.eventtap.event.types.flagsChanged
		end,
		getKeyCode = function()
			return 55
		end,
		getFlags = function()
			return {
				cmd = true,
			}
		end,
	})

	assert_equal(recorded.rendered_text[#recorded.rendered_text], "⌘", "flagsChanged should render standalone modifier keys")
	assert_true(recorded.timers[1].stopped, "new keystroke should stop previous hide timer")

	assert_true(key_caster.stop(), "stop should succeed")
	assert_equal(recorded.eventtap_stopped, 1, "stop should stop event tap")
	assert_true(recorded.deleted_canvases >= 2, "stop and redraw should clean up canvases")
	assert_true(recorded.timers[#recorded.timers].stopped, "stop should cancel pending hide timer")

	reset_modules()
	hs = nil
end

return _M
