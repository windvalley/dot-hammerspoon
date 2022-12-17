local _M = {}

_M.__index = _M

_M.name = "apps_switch"
_M.version = "0.1.0"
_M.description = "app切换"

local apps = require "shortcuts_config".apps

-- 存储鼠标位置
local mousePositions = {}

local function setMouseToCenter(foucusedWindow)
    if foucusedWindow == nil then
        return
    end

    local frame = foucusedWindow:frame()
    local centerPosition = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2)

    hs.mouse.absolutePosition(centerPosition)
end

local function toggleAppByBundleId(appBundleID)
    local previousFocusedWindow = hs.window.focusedWindow()

    if previousFocusedWindow ~= nil then
        mousePositions[previousFocusedWindow:id()] = hs.mouse.absolutePosition()
    end

    hs.application.launchOrFocusByBundleID(appBundleID)

    -- 获取 application 对象
    local applications = hs.application.applicationsForBundleID(appBundleID)
    local application = nil

    for _, v in ipairs(applications) do
        application = v
    end

    local currentFocusedWindow = application:focusedWindow()

    if currentFocusedWindow ~= nil and mousePositions[currentFocusedWindow:id()] ~= nil then
        hs.mouse.absolutePosition(mousePositions[currentFocusedWindow:id()])
    else
        setMouseToCenter(currentFocusedWindow)
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
