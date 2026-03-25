local _M = {}

_M.name = "auto_input_method"
_M.description = "切换应用时自动切换输入法"

local auto_input_methods = require("keybindings_config").auto_input_methods

local log = hs.logger.new("input")
local state = {
	started = false,
	watcher = nil,
}
local pop_msg = false

local function switch_input_method(input_method, context_label)
	local ok = hs.keycodes.currentSourceID(input_method)

	if ok ~= true then
		log.w(string.format("failed to switch input method to '%s' (%s)", tostring(input_method), tostring(context_label or "unknown")))
		return false
	end

	return true
end

local function update_input_method_for_app(appName, appObject, reason)
	if appObject == nil then
		log.d(string.format("skip input method switch because appObject is nil (%s)", tostring(reason or "unknown")))
		return
	end

	local bundleID = appObject:bundleID()

	if bundleID == nil then
		log.d(string.format("skip input method switch because bundleID is nil for '%s' (%s)", tostring(appName), tostring(reason or "unknown")))
		return
	end

	local input_method = auto_input_methods[bundleID]

	if input_method ~= nil then
		if switch_input_method(input_method, appName or bundleID) ~= true then
			return
		end

		if pop_msg then
			hs.alert.show(input_method, 0.5)
		end

		log.d(string.format("app '%s' switched to '%s' (%s)", tostring(appName or bundleID), input_method, tostring(reason or "unknown")))
	end
end

local function applicationWatcher(appName, eventType, appObject)
	if eventType ~= hs.application.watcher.activated then
		return
	end

	update_input_method_for_app(appName, appObject, "application activated")
end

function _M.start()
	if state.started == true then
		return true
	end

	if state.watcher == nil then
		state.watcher = hs.application.watcher.new(applicationWatcher)
	end

	if state.watcher == nil then
		log.e("failed to create application watcher for auto input method")
		return false
	end

	local ok, started_watcher = pcall(function()
		return state.watcher:start()
	end)

	if ok ~= true or started_watcher == false then
		log.e("failed to start application watcher for auto input method")
		return false
	end

	state.started = true

	update_input_method_for_app(nil, hs.application.frontmostApplication(), "module start")

	return true
end

function _M.stop()
	if state.watcher ~= nil then
		state.watcher:stop()
	end

	state.started = false

	return true
end

return _M
