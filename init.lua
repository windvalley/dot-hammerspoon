local _M = {}

_M.__index = _M

_M.name = "init"
_M.author = "XG <levinwang6@gmail.com>"
_M.license = "MIT"
_M.homepage = "https://github.com/windvalley/dot-hammerspoon"

-- Hammerspoon Preferences
hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(false)
hs.consoleOnTop(false)
hs.dockIcon(false)
hs.menuIcon(true)
hs.uploadCrashData(false)

-- 每次按快捷键时显示快捷键alert消息持续的秒数, 0 为禁用.
hs.hotkey.alertDuration = 0

-- 窗口动画持续时间, 0为关闭动画效果.
hs.window.animationDuration = 0

-- Hammerspoon Console 上打印的日志级别.
-- 可选: verbose, debug, info, warning, error, nothing
-- 默认: warning
hs.logger.defaultLogLevel = "warning"

-- app快速启动或切换
require("app_launch")

-- app窗口操作
require("window_manipulation")

-- 系统管理
require("system_manage")

-- 网站快捷访问
require("website_open")

-- 切换到指定输入法
require("manual_input_method")

-- 根据应用不同, 自动切换输入法
require("auto_input_method")

-- 使桌面壁纸保持和 Bing Daily Picture 一致
require("bing_daily_wallpaper")

-- 显示快捷键备忘面板
require("keybindings_cheatsheet")

-- lua文件变动自动reload
require("auto_reload")

return _M
