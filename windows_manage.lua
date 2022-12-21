local _M = {}

_M.name = "windows_manage"
_M.version = "0.1.0"
_M.description = "app窗口管理, 比如移动、放大、缩小、分屏等"

local windows = require("shortcuts_config").windows
local windows_lib = require("windows_lib")

-- 窗口动画持续时间, 0为关闭动画效果.
hs.window.animationDuration = 0.1

-- An integer specifying how many gridparts the screen should be divided into.
-- Defaults to 30.
_M.gridparts = 30

-- 上下左右移动窗口.
local function stepMove(direction)
    local cwin = hs.window.focusedWindow()
    if cwin then
        local cscreen = cwin:screen()
        local cres = cscreen:fullFrame()
        local stepw = cres.w / _M.gridparts
        local steph = cres.h / _M.gridparts
        local wtopleft = cwin:topLeft()

        if direction == "left" then
            cwin:setTopLeft({x = wtopleft.x - stepw, y = wtopleft.y})
        elseif direction == "right" then
            cwin:setTopLeft({x = wtopleft.x + stepw, y = wtopleft.y})
        elseif direction == "up" then
            cwin:setTopLeft({x = wtopleft.x, y = wtopleft.y - steph})
        elseif direction == "down" then
            cwin:setTopLeft({x = wtopleft.x, y = wtopleft.y + steph})
        end
    else
        hs.alert.show("No focused window!")
    end
end

-- option的可选值:
--   halfleft: 左半屏
--   halfright: 右半屏
--   halfup: 上半屏
--   halfdown: 下半屏
--   cornerTopLeft: 左上角
--   cornerTopRight: 右上角
--   cornerBottomLeft: 左下角
--   cornerBottomRight: 右下角
--   max: 最大化
--   center: 保持窗口原右大小居中
--   stretch: 放大
--   shrink: 缩小
local function moveAndResize(option)
    local cwin = hs.window.focusedWindow()

    if cwin then
        local cscreen = cwin:screen()
        local cres = cscreen:fullFrame()
        local stepw = cres.w / _M.gridparts
        local steph = cres.h / _M.gridparts
        local wf = cwin:frame()

        if option == "halfleft" then
            cwin:setFrame({x = cres.x, y = cres.y, w = cres.w / 2, h = cres.h})
        elseif option == "halfright" then
            cwin:setFrame({x = cres.x + cres.w / 2, y = cres.y, w = cres.w / 2, h = cres.h})
        elseif option == "halfup" then
            cwin:setFrame({x = cres.x, y = cres.y, w = cres.w, h = cres.h / 2})
        elseif option == "halfdown" then
            cwin:setFrame({x = cres.x, y = cres.y + cres.h / 2, w = cres.w, h = cres.h / 2})
        elseif option == "cornerTopLeft" then
            cwin:setFrame({x = cres.x, y = cres.y, w = cres.w / 2, h = cres.h / 2})
        elseif option == "cornerTopRight" then
            cwin:setFrame({x = cres.x + cres.w / 2, y = cres.y, w = cres.w / 2, h = cres.h / 2})
        elseif option == "cornerBottomLeft" then
            cwin:setFrame({x = cres.x, y = cres.y + cres.h / 2, w = cres.w / 2, h = cres.h / 2})
        elseif option == "cornerBottomRight" then
            cwin:setFrame({x = cres.x + cres.w / 2, y = cres.y + cres.h / 2, w = cres.w / 2, h = cres.h / 2})
        elseif option == "max" then
            cwin:setFrame({x = cres.x, y = cres.y, w = cres.w, h = cres.h})
        elseif option == "center" then
            cwin:centerOnScreen()
        elseif option == "stretch" then
            cwin:setFrame({x = wf.x - stepw, y = wf.y - steph, w = wf.w + (stepw * 2), h = wf.h + (steph * 2)})
        elseif option == "shrink" then
            cwin:setFrame({x = wf.x + stepw, y = wf.y + steph, w = wf.w - (stepw * 2), h = wf.h - (steph * 2)})
        end
    else
        hs.alert.show("No focused window!")
    end
end

-- 左半屏
hs.hotkey.bind(
    windows.left.prefix,
    windows.left.key,
    windows.left.message,
    function()
        moveAndResize("halfleft")
    end
)

-- 右半屏
hs.hotkey.bind(
    windows.right.prefix,
    windows.right.key,
    windows.right.message,
    function()
        moveAndResize("halfright")
    end
)

-- 上半屏
hs.hotkey.bind(
    windows.up.prefix,
    windows.up.key,
    windows.up.message,
    function()
        moveAndResize("halfup")
    end
)

-- 下半屏
hs.hotkey.bind(
    windows.down.prefix,
    windows.down.key,
    windows.down.message,
    function()
        moveAndResize("halfdown")
    end
)

-- 左上角
hs.hotkey.bind(
    windows.top_left.prefix,
    windows.top_left.key,
    windows.top_left.message,
    function()
        moveAndResize("cornerTopLeft")
    end
)

-- 右上角
hs.hotkey.bind(
    windows.top_right.prefix,
    windows.top_right.key,
    windows.top_right.message,
    function()
        moveAndResize("cornerTopRight")
    end
)

-- 左下角
hs.hotkey.bind(
    windows.bottom_left.prefix,
    windows.bottom_left.key,
    windows.bottom_left.message,
    function()
        moveAndResize("cornerBottomLeft")
    end
)

-- 右下角
hs.hotkey.bind(
    windows.bottom_right.prefix,
    windows.bottom_right.key,
    windows.bottom_right.message,
    function()
        moveAndResize("cornerBottomRight")
    end
)

-- 左 1/3（横屏）或上 1/3（竖屏）
hs.hotkey.bind(
    windows.left_1_3.prefix,
    windows.left_1_3.key,
    windows.left_1_3.message,
    function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = screen:frame()
        -- 如果为竖屏
        if windows_lib.isVerticalScreen(screen) then
            -- 如果为横屏
            f.x = max.x
            f.y = max.y
            f.w = max.w
            f.h = max.h / 3
        else
            f.x = max.x
            f.y = max.y
            f.w = max.w / 3
            f.h = max.h
        end
        win:setFrame(f)
    end
)

-- 右 1/3（横屏）或下 1/3（竖屏）
hs.hotkey.bind(
    windows.right_1_3.prefix,
    windows.right_1_3.key,
    windows.right_1_3.message,
    function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = screen:frame()
        -- 如果为竖屏
        if windows_lib.isVerticalScreen(screen) then
            -- 如果为横屏
            f.x = max.x
            f.y = max.y + (max.h / 3 * 2)
            f.w = max.w
            f.h = max.h / 3
        else
            f.x = max.x + (max.w / 3 * 2)
            f.y = max.y
            f.w = max.w / 3
            f.h = max.h
        end
        win:setFrame(f)
    end
)

-- 左 2/3（横屏）或上 2/3（竖屏）
hs.hotkey.bind(
    windows.left_2_3.prefix,
    windows.left_2_3.key,
    windows.left_2_3.message,
    function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = screen:frame()
        -- 如果为竖屏
        if windows_lib.isVerticalScreen(screen) then
            -- 如果为横屏
            f.x = max.x
            f.y = max.y
            f.w = max.w
            f.h = max.h / 3 * 2
        else
            f.x = max.x
            f.y = max.y
            f.w = max.w / 3 * 2
            f.h = max.h
        end
        win:setFrame(f)
    end
)

-- 右 2/3（横屏）或下 2/3（竖屏）
hs.hotkey.bind(
    windows.right_2_3.prefix,
    windows.right_2_3.key,
    windows.right_2_3.message,
    function()
        local win = hs.window.focusedWindow()
        local f = win:frame()
        local screen = win:screen()
        local max = screen:frame()
        -- 如果为竖屏
        if windows_lib.isVerticalScreen(screen) then
            -- 如果为横屏
            f.x = max.x
            f.y = max.y + (max.h / 3)
            f.w = max.w
            f.h = max.h / 3 * 2
        else
            f.x = max.x + (max.w / 3)
            f.y = max.y
            f.w = max.w / 3 * 2
            f.h = max.h
        end
        win:setFrame(f)
    end
)

-- 保持原有窗口大小居中
hs.hotkey.bind(
    windows.center.prefix,
    windows.center.key,
    windows.center.message,
    function()
        moveAndResize("center")
    end
)

-- 最大化
hs.hotkey.bind(
    windows.max.prefix,
    windows.max.key,
    windows.max.message,
    function()
        moveAndResize("max")
    end
)

-- 等比例放大窗口
hs.hotkey.bind(
    windows.stretch.prefix,
    windows.stretch.key,
    windows.stretch.message,
    function()
        moveAndResize("stretch")
    end
)

-- 等比例缩小窗口
hs.hotkey.bind(
    windows.shrink.prefix,
    windows.shrink.key,
    windows.shrink.message,
    function()
        moveAndResize("shrink")
    end
)

-- 将窗口进行上下左右移动.
hs.hotkey.bind(
    windows.to_up.prefix,
    windows.to_up.key,
    windows.to_up.message,
    function()
        stepMove("up")
    end,
    nil,
    function()
        stepMove("up")
    end
)
hs.hotkey.bind(
    windows.to_down.prefix,
    windows.to_down.key,
    windows.to_down.message,
    function()
        stepMove("down")
    end,
    nil,
    function()
        stepMove("down")
    end
)
hs.hotkey.bind(
    windows.to_left.prefix,
    windows.to_left.key,
    windows.to_left.message,
    function()
        stepMove("left")
    end,
    nil,
    function()
        stepMove("left")
    end
)
hs.hotkey.bind(
    windows.to_right.prefix,
    windows.to_right.key,
    windows.to_right.message,
    function()
        stepMove("right")
    end,
    nil,
    function()
        stepMove("right")
    end
)

return _M
