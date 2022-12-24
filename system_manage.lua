local _M = {}

_M.name = "system_manage"
_M.version = "0.1.0"
_M.description = "系统管理, 比如: 锁屏, 启动屏保, 重启等"

local system = require("shortcuts_config").system

-- 锁屏.
hs.hotkey.bind(
    system.lock_screen.prefix,
    system.lock_screen.key,
    system.lock_screen.message,
    function()
        print("[INFO] lock screen")
        hs.caffeinate.lockScreen()
    end
)

-- 启动屏保.
hs.hotkey.bind(
    system.screen_saver.prefix,
    system.screen_saver.key,
    system.screen_saver.message,
    function()
        print("[INFO] start screensaver")
        hs.caffeinate.startScreensaver()
    end
)

-- 重启.
hs.hotkey.bind(
    system.restart.prefix,
    system.restart.key,
    system.restart.message,
    function()
        hs.caffeinate.restartSystem()
    end
)

-- 关机.
hs.hotkey.bind(
    system.shutdown.prefix,
    system.shutdown.key,
    system.shutdown.message,
    function()
        hs.caffeinate.shutdownSystem()
    end
)

return _M
