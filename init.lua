local _M = {}

_M.__index = _M

_M.name = "init"
_M.version = "0.1.0"
_M.author = "XG <levinwang6@gmail.com>"
_M.license = "MIT"
_M.homepage = "https://github.com/windvalley/dot-hammerspoon"

-- 每次按快捷键时显示快捷键alert消息持续的秒数, 0 为禁用.
hs.hotkey.alertDuration = 0

-- app切换
require("apps_switch")

-- app窗口管理
require("windows_manage")

-- 指定输入法切换
require("input_method")

-- 显示快捷键列表
require("hotkeys_show")

-- lua文件变动自动reload
require("auto_reload")

return _M
