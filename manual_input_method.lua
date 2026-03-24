local _M = {}

_M.name = "manual_input_method"
_M.description = "明确指定切换到某个输入法"

local manual_input_methods = require "keybindings_config".manual_input_methods
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("input")
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

local pop_msg = false

function _M.start()
    if state.started == true then
        return true
    end

    state.started = true

    hs.fnutils.each(
        manual_input_methods,
        function(item)
            bind(
                item.prefix,
                item.key,
                item.message,
                function()
                    hs.keycodes.currentSourceID(item.input_method)

                    if pop_msg then
                        hs.alert.show(item.input_method, 0.5)
                    end

                    log.d(string.format("manual switched to '%s'", item.input_method))
                end
            )
        end
    )

    return true
end

function _M.stop()
    clearBindings()
    state.started = false

    return true
end

return _M
