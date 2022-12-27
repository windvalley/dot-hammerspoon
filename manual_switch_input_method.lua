local _M = {}

_M.name = "manual_switch_input_method"
_M.description = "明确指定切换到某个输入法"

local manual_input_methods = require "keybindings_config".manual_input_methods
local input_method_lib = require "input_method_lib"

hs.fnutils.each(
    manual_input_methods,
    function(item)
        hs.hotkey.bind(
            item.prefix,
            item.key,
            item.message,
            function()
                input_method_lib.switch_input_method(item.input_method)
            end
        )
    end
)

return _M
