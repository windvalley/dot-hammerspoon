local _M = {}

_M.name = "app_launch"
_M.description = "app启动或切换"

local apps = require("keybindings_config").apps
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("appLaunch")
local state = {
	started = false,
	bindings = {},
	binding_failures = 0,
	start_ok = true,
}

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
	local binding = hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })

	if binding ~= nil then
		table.insert(state.bindings, binding)
	else
		state.binding_failures = state.binding_failures + 1
	end

	return binding
end

local function clearBindings()
	for _, binding in ipairs(state.bindings) do
		binding:delete()
	end

	state.bindings = {}
end

-- App显示或隐藏
local function toggleAppByBundleId(bundleID)
	local frontApp = hs.application.frontmostApplication()

	if frontApp ~= nil and frontApp:bundleID() == bundleID then
		log.d(string.format("hide app: %s", bundleID))
		if frontApp:hide() ~= true then
			log.w(string.format("failed to hide app: %s", bundleID))
		end
	else
		log.d(string.format("launch app: %s", bundleID))
		if hs.application.launchOrFocusByBundleID(bundleID) ~= true then
			log.w(string.format("failed to launch or focus app: %s", bundleID))
		end
	end
end

function _M.start()
	if state.started == true then
		return state.start_ok
	end

	state.binding_failures = 0

	hs.fnutils.each(apps, function(item)
		bind(item.prefix, item.key, item.message, function()
			toggleAppByBundleId(item.bundleId)
		end)
	end)

	state.started = true
	state.start_ok = state.binding_failures == 0

	return state.start_ok
end

function _M.stop()
	clearBindings()
	state.binding_failures = 0
	state.start_ok = true
	state.started = false

	return true
end

return _M
