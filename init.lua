local _M = {}

_M.__index = _M

_M.name = "init"
_M.version = "0.1.0"
_M.author = "XG <levinwang6@gmail.com>"
_M.license = "MIT"
_M.homepage = "https://github.com/windvalley/dot-hammerspoon"

-- app快速启动或切换
require("apps_switch")

-- app窗口管理
require("windows_manage")

-- 指定输入法切换
require("input_method")

-- 显示快捷键列表
require("hotkeys_show")

-- lua文件变动自动reload
require("auto_reload")

-- 使桌面壁纸保持和 Bing Daily Picture 一致
require("bing_daily_wallpaper")

return _M
