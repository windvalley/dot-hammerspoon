local _M = {}

_M.name = "website_open"
_M.description = "快速打开目标网站"

local websites = require("keybindings_config").websites
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("website")
local state = {
	started = false,
	bindings = {},
}

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
	local binding = hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })

	if binding ~= nil then
		table.insert(state.bindings, binding)
	end

	return binding
end

local function clearBindings()
	for _, binding in ipairs(state.bindings) do
		binding:delete()
	end

	state.bindings = {}
end

function _M.start()
	if state.started == true then
		return true
	end

	state.started = true

	hs.fnutils.each(websites, function(item)
		bind(item.prefix, item.key, item.message, function()
			log.d(string.format("open website: %s", item.target))
			hs.urlevent.openURL(item.target)
		end)
	end)

	return true
end

function _M.stop()
	clearBindings()
	state.started = false

	return true
end

return _M
