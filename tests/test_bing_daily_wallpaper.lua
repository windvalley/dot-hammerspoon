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

local function assert_contains(text, expected, message)
	if tostring(text or ""):find(expected, 1, true) == nil then
		error(string.format("%s: expected to find %s in %s", message or "assert_contains failed", tostring(expected), tostring(text)))
	end
end

local function reset_modules()
	loaded_modules["bing_daily_wallpaper"] = nil
	loaded_modules["keybindings_config"] = nil
	loaded_modules["utils_lib"] = nil
end

local function build_hs(recorded, fake_files)
	return {
		logger = {
			new = function()
				return {
					i = function() end,
					e = function() end,
					w = function() end,
					d = function() end,
				}
			end,
		},
		settings = {
			bundleID = "org.hammerspoon.Hammerspoon",
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
			doEvery = function()
				recorded.timer_started = recorded.timer_started + 1
				return {
					stop = function()
						recorded.timer_stopped = recorded.timer_stopped + 1
					end,
				}
			end,
		},
		http = {
			asyncGet = function(_, _, callback)
				recorded.async_get_calls = recorded.async_get_calls + 1
				callback(200, "payload", nil)
			end,
		},
		json = {
			decode = function()
				return {
					images = {
						{ url = "/th?id=OHR.TestImage_UHD.jpg&rf=LaDigue_UHD.jpg" },
					},
				}
			end,
		},
		hash = {
			SHA256 = function(value)
				return "hash-" .. tostring(value)
			end,
		},
		task = {
			new = function(command, callback, args)
				recorded.task_command = command
				recorded.task_callback = callback
				recorded.task_args = args

				return {
					start = function()
						recorded.task_started = recorded.task_started + 1

						local output_path = args[#args]
						fake_files[output_path] = true

						return true
					end,
					terminate = function()
						recorded.task_terminated = recorded.task_terminated + 1
					end,
				}
			end,
		},
		screen = {
			allScreens = function()
				return {
					{
						desktopImageURL = function(_, url)
							table.insert(recorded.desktop_image_urls, url)
						end,
					},
				}
			end,
		},
		fs = {
			dir = function()
				local yielded = false

				return function()
					if yielded == true then
						return nil
					end

					yielded = true
					return nil
				end
			end,
			attributes = function(path)
				if fake_files[path] == true then
					return { mode = "file" }
				end

				return nil
			end,
		},
	}
end

function _M.run()
	reset_modules()

	local original_remove = os.remove
	local original_rename = os.rename

	local success_recorded = {
		settings_store = {},
		timer_started = 0,
		timer_stopped = 0,
		async_get_calls = 0,
		task_started = 0,
		task_terminated = 0,
		desktop_image_urls = {},
		removed_paths = {},
		renamed_paths = {},
	}
	local success_files = {}

	rawset(os, "remove", function(path)
		table.insert(success_recorded.removed_paths, path)
		success_files[path] = nil
		return true
	end)

	rawset(os, "rename", function(from_path, to_path)
		table.insert(success_recorded.renamed_paths, { from = from_path, to = to_path })

		if success_files[from_path] == true then
			success_files[from_path] = nil
			success_files[to_path] = true
			return true
		end

		return nil, "missing source"
	end)

	hs = build_hs(success_recorded, success_files)

	loaded_modules["keybindings_config"] = {
		bing_daily_wallpaper = {
			enabled = false,
		},
	}
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		file_exists = function(path)
			return success_files[path] == true
		end,
		ensure_directory = function()
			return true
		end,
	}

	local wallpaper = require("bing_daily_wallpaper")

	assert_true(wallpaper.start(), "disabled wallpaper module should be treated as a successful no-op start")
	assert_equal(success_recorded.timer_started, 0, "disabled wallpaper module should not start any refresh timer")

	reset_modules()

	loaded_modules["keybindings_config"] = {
		bing_daily_wallpaper = {
			enabled = true,
			refresh_interval_seconds = 60,
			cache_dir = "/tmp/bing-test-cache",
		},
	}
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		file_exists = function(path)
			return success_files[path] == true
		end,
		ensure_directory = function()
			return true
		end,
	}

	local active_wallpaper = require("bing_daily_wallpaper")
	local expected_final_path = "/tmp/bing-test-cache/bing_OHR.TestImage_UHD.jpg"
	local expected_temp_path = expected_final_path .. ".part"

	assert_true(active_wallpaper.start(), "enabled wallpaper module should start successfully")
	assert_equal(success_recorded.timer_started, 1, "enabled wallpaper module should start refresh timer")
	assert_equal(success_recorded.async_get_calls, 1, "startup should trigger one metadata refresh")
	assert_equal(success_recorded.task_started, 1, "startup should begin a download task when cache is empty")
	assert_contains(success_recorded.task_args[#success_recorded.task_args], ".part", "download should target a temporary file")

	success_recorded.task_callback(0, "", "")

	assert_equal(success_recorded.renamed_paths[1].from, expected_temp_path, "successful downloads should rename from temp path")
	assert_equal(success_recorded.renamed_paths[1].to, expected_final_path, "successful downloads should finalize to cache path")
	assert_equal(success_recorded.desktop_image_urls[1], "file://" .. expected_final_path, "wallpaper should be applied from finalized cache file")
	assert_true(active_wallpaper.stop(), "stop should return true for lifecycle consistency")
	assert_equal(success_recorded.timer_stopped, 1, "stop should cancel active refresh timer")

	reset_modules()

	local interrupted_recorded = {
		settings_store = {},
		timer_started = 0,
		timer_stopped = 0,
		async_get_calls = 0,
		task_started = 0,
		task_terminated = 0,
		desktop_image_urls = {},
		removed_paths = {},
		renamed_paths = {},
	}
	local interrupted_files = {}

	rawset(os, "remove", function(path)
		table.insert(interrupted_recorded.removed_paths, path)
		interrupted_files[path] = nil
		return true
	end)

	rawset(os, "rename", function(from_path, to_path)
		table.insert(interrupted_recorded.renamed_paths, { from = from_path, to = to_path })

		if interrupted_files[from_path] == true then
			interrupted_files[from_path] = nil
			interrupted_files[to_path] = true
			return true
		end

		return nil, "missing source"
	end)

	hs = build_hs(interrupted_recorded, interrupted_files)

	loaded_modules["keybindings_config"] = {
		bing_daily_wallpaper = {
			enabled = true,
			refresh_interval_seconds = 60,
			cache_dir = "/tmp/bing-test-cache",
		},
	}
	loaded_modules["utils_lib"] = {
		trim = function(value)
			return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
		end,
		file_exists = function(path)
			return interrupted_files[path] == true
		end,
		ensure_directory = function()
			return true
		end,
	}

	local interrupted_wallpaper = require("bing_daily_wallpaper")

	assert_true(interrupted_wallpaper.start(), "wallpaper module should start before interruption test")
	assert_equal(interrupted_recorded.task_started, 1, "interruption scenario should start a download task")
	assert_true(interrupted_files[expected_temp_path] == true, "partial download should exist before stop")

	assert_true(interrupted_wallpaper.stop(), "stop should succeed during active download")
	assert_equal(interrupted_recorded.task_terminated, 1, "stop should terminate in-flight downloads")
	assert_equal(interrupted_recorded.removed_paths[#interrupted_recorded.removed_paths], expected_temp_path, "stop should remove partial downloads")

	rawset(os, "remove", original_remove)
	rawset(os, "rename", original_rename)

	reset_modules()
	hs = nil
end

return _M
