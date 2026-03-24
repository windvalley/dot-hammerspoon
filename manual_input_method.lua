local _M = {}

_M.name = "manual_input_method"
_M.description = "明确指定切换到某个输入法"

local manual_input_methods = require "keybindings_config".manual_input_methods
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("input")

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
    return hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })
end

local pop_msg = false

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

return _M
