local _M = {}

_M.__index = _M

_M.name = "init"
_M.version = "0.1.0"
_M.author = "XG <levinwang6@gmail.com>"
_M.license = "MIT"
_M.homepage = "https://github.com/windvalley/dot-hammerspoon"

-- app快速启动或切换
require("app_launch")

-- app窗口操作
require("window_manipulation")

-- 指定输入法切换
require("input_method")

-- 系统管理
require("system_manage")

-- 网站快捷访问
require("open_url")

-- 显示快捷键列表
require("keybindings_cheatsheet")

-- lua文件变动自动reload
require("auto_reload")

-- 使桌面壁纸保持和 Bing Daily Picture 一致
require("bing_daily_wallpaper")

return _M
