local _M = {}

_M.__index = _M

_M.name = "app_launch"
_M.version = "0.1.0"
_M.description = "app启动或切换"

local apps = require "keybindings_config".apps

-- App显示或隐藏
local function toggleAppByBundleId(bundleID)
    local frontApp = hs.application.frontmostApplication()
    if frontApp:bundleID() == bundleID and frontApp:focusedWindow() then
        frontApp:hide()
    else
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
