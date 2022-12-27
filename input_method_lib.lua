local _M = {}

_M.name = "input_method_lib"
_M.description = "切换输入法相关的函数库"

_M.pinyin = "com.apple.inputmethod.SCIM.ITABC"
_M.abc = "com.apple.keylayout.ABC"

_M.switch_input_method = function(inputMethod)
    hs.keycodes.currentSourceID(inputMethod)
end

return _M
