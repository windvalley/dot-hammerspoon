local _M = {}

_M.name = "system_manage"
_M.description = "系统管理, 比如: 锁屏, 启动屏保, 重启等"

local system = require("keybindings_config").system
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("system")

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
    return hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })
end

-- 锁屏.
bind(
    system.lock_screen.prefix,
    system.lock_screen.key,
    system.lock_screen.message,
    function()
        log.d("lock screen")
        hs.caffeinate.lockScreen()
    end
)

-- 启动屏保.
bind(
    system.screen_saver.prefix,
    system.screen_saver.key,
    system.screen_saver.message,
    function()
        log.d("start screensaver")
        hs.caffeinate.startScreensaver()
    end
)

-- 重启.
bind(
    system.restart.prefix,
    system.restart.key,
    system.restart.message,
    function()
        hs.caffeinate.restartSystem()
    end
)

-- 关机.
bind(
    system.shutdown.prefix,
    system.shutdown.key,
    system.shutdown.message,
    function()
        hs.caffeinate.shutdownSystem()
    end
)

return _M
