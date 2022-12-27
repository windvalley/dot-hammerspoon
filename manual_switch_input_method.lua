local _M = {}

_M.name = "manual_switch_input_method"
_M.version = "0.1.1"
_M.description = "明确指定切换到某个输入法"

local input_methods = require("keybindings_config").manual_input_methods

local pinyin = "com.apple.inputmethod.SCIM.ITABC"
local abc = "com.apple.keylayout.ABC"

-- 切换到简体拼音
local function switch_pinyin()
    hs.keycodes.currentSourceID(pinyin)
end

-- 切换到ABC
local function switch_abc()
    hs.keycodes.currentSourceID(abc)
end

hs.hotkey.bind(input_methods.abc.prefix, input_methods.abc.key, input_methods.abc.message, switch_abc)

hs.hotkey.bind(input_methods.pinyin.prefix, input_methods.pinyin.key, input_methods.pinyin.message, switch_pinyin)

return _M
