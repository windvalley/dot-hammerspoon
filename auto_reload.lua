local _M = {}

_M.name = "auto_reload"
_M.description = "lua文件变动自动reload, 使实时生效"

local log = hs.logger.new("reload")
local reload_delay_seconds = 0.25
local reload_notification_settings_key = "auto_reload.pending_notification"
local started = false

local reload_timer = nil

local function persist_reload_notification()
	if type(hs.settings) ~= "table" or type(hs.settings.set) ~= "function" then
		return
	end

	hs.settings.set(reload_notification_settings_key, true)
end

local function flush_reload_notification()
	if type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return
	end

	if hs.settings.get(reload_notification_settings_key) ~= true then
		return
	end

	if type(hs.settings.clear) == "function" then
		hs.settings.clear(reload_notification_settings_key)
	elseif type(hs.settings.set) == "function" then
		hs.settings.set(reload_notification_settings_key, false)
	end

	hs.alert.show("hammerspoon reloaded")
end

local function stop_reload_timer()
	if reload_timer == nil then
		return
	end

	reload_timer:stop()
	reload_timer = nil
end

local function schedule_reload(reason)
	stop_reload_timer()

	reload_timer = hs.timer.doAfter(reload_delay_seconds, function()
		reload_timer = nil
		log.i("reload hammerspoon config: " .. tostring(reason or "file change"))
		persist_reload_notification()
		hs.reload()
	end)
end

local function is_recursive_scan_event(flags)
	if type(flags) ~= "table" then
		return false
	end

	return flags.mustScanSubDirs == true or flags.rootChanged == true
end

local function is_relevant_lua_change(path, flags)
	if is_recursive_scan_event(flags) then
		return true
	end

	if type(path) ~= "string" or path:sub(-4) ~= ".lua" then
		return false
	end

	if type(flags) ~= "table" then
		return true
	end

	if flags.itemIsFile ~= true and flags.itemRenamed ~= true then
		return false
	end

	return flags.itemCreated == true or flags.itemRemoved == true or flags.itemRenamed == true or flags.itemModified == true
end

local function reload(paths, flag_tables)
	for index, path in ipairs(paths or {}) do
		if is_relevant_lua_change(path, flag_tables and flag_tables[index]) then
			schedule_reload(path)
			return
		end
	end
end

function _M.start()
	if started == true then
		return true
	end

	if _M.watcher == nil then
		_M.watcher = hs.pathwatcher.new(hs.configdir, reload)
	end

	if _M.watcher == nil then
		log.i("failed to create auto reload watcher")
		return false
	end

	local ok, started_watcher = pcall(function()
		return _M.watcher:start()
	end)

	if ok ~= true or started_watcher == false then
		log.i("failed to start auto reload watcher")
		return false
	end

	started = true
	flush_reload_notification()

	return true
end

function _M.stop()
	stop_reload_timer()

	if _M.watcher ~= nil then
		_M.watcher:stop()
	end

	started = false

	return true
end

return _M
