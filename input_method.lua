local _M = {}

_M.name = "input_method"
_M.version = "0.1.0"
_M.description = "中英文输入法明确指定切换"

local input_methods = require("shortcuts_config").input_methods

local INPUT_CHINESE = "com.apple.inputmethod.SCIM.ITABC"
local INPUT_ABC = "com.apple.keylayout.ABC"

-- 简体拼音
local function chinese()
    hs.keycodes.currentSourceID(INPUT_CHINESE)
end

-- ABC
local function abc()
    hs.keycodes.currentSourceID(INPUT_ABC)
end

if (input_methods ~= nil) then
    hs.hotkey.bind(input_methods.abc.prefix, input_methods.abc.key, input_methods.abc.message, abc)

    hs.hotkey.bind(input_methods.chinese.prefix, input_methods.chinese.key, input_methods.chinese.message, chinese)
end

return _M
