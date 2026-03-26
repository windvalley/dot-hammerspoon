local _M = {}

_M.name = "manual_input_method"
_M.description = "明确指定切换到某个输入法"

local manual_input_methods = require("keybindings_config").manual_input_methods
local input_method_helper = require("input_method_helper")
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("input")
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

local pop_msg = false

local function switch_input_method(input_method)
	local ok = input_method_helper.switch(input_method)

	if ok ~= true then
		log.w(string.format("failed to switch input method to '%s'", tostring(input_method)))
		hs.alert.show("切换输入法失败")
		return false
	end

	return true
end

function _M.start()
	if state.started == true then
		return state.start_ok
	end

	state.binding_failures = 0

	hs.fnutils.each(manual_input_methods, function(item)
		bind(item.prefix, item.key, item.message, function()
			if switch_input_method(item.input_method) ~= true then
				return
			end

			if pop_msg then
				hs.alert.show(item.input_method, 0.5)
			end

			log.d(string.format("manual switched to '%s'", item.input_method))
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
