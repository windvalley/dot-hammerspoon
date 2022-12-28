local _M = {}

_M.name = "app_launch"
_M.description = "app启动或切换"

local apps = require "keybindings_config".apps

local log = hs.logger.new("appLaunch")

-- App显示或隐藏
local function toggleAppByBundleId(bundleID)
    local frontApp = hs.application.frontmostApplication()
    if frontApp:bundleID() == bundleID and frontApp:focusedWindow() then
        log.d(string.format("hide app: %s", bundleID))
        frontApp:hide()
    else
        log.d(string.format("launch app: %s", bundleID))
        hs.application.launchOrFocusByBundleID(bundleID)
    end
end

hs.fnutils.each(
    apps,
    function(item)
        hs.hotkey.bind(
            item.prefix,
            item.key,
            item.message,
            function()
                toggleAppByBundleId(item.bundleId)
            end
        )
    end
)

return _M
