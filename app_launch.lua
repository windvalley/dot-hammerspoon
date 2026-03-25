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

	if frontApp ~= nil and frontApp:bundleID() == bundleID and frontApp:focusedWindow() then
		log.d(string.format("hide app: %s", bundleID))
		frontApp:hide()
	else
		log.d(string.format("launch app: %s", bundleID))
		hs.application.launchOrFocusByBundleID(bundleID)
	end
end

function _M.start()
	if state.started == true then
		return true
	end

	state.started = true
	state.binding_failures = 0

	hs.fnutils.each(apps, function(item)
		bind(item.prefix, item.key, item.message, function()
			toggleAppByBundleId(item.bundleId)
		end)
	end)

	return state.binding_failures == 0
end

function _M.stop()
	clearBindings()
	state.binding_failures = 0
	state.started = false

	return true
end

return _M
