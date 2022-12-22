local _M = {}

_M.name = "windows_lib"
_M.version = "0.1.0"
_M.description = "窗口管理相关函数库"

-- 判断指定屏幕是否为竖屏
local isVerticalScreen = function(screen)
    if screen:rotate() == 90 or screen:rotate() == 270 then
        return true
    else
        return false
    end
end

-- An integer specifying how many gridparts the screen should be divided into.
-- Defaults to 30.
_M.gridparts = 30

-- Move the focused window in the `direction` by on step.
-- Parameters: left, right, up, down
_M.stepMove = function(direction)
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

-- Move and resize the focused window.
-- Parameters:
--   halfleft: 左半屏
--   halfright: 右半屏
--   halfup: 上半屏
--   halfdown: 下半屏
--   left_1_3: 左或上1/3
--   right_1_3: 右或下1/3
--   left_2_3: 左或上2/3
--   right_2_3: 右或下2/3
--   cornerTopLeft: 左上角
--   cornerTopRight: 右上角
--   cornerBottomLeft: 左下角
--   cornerBottomRight: 右下角
--   max: 最大化
--   center: 保持窗口原右大小居中
--   stretch: 放大
--   shrink: 缩小
_M.moveAndResize = function(option)
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
        elseif option == "left_1_3" then
            local obj
            if isVerticalScreen(cscreen) then
                obj = {
                    x = cres.x,
                    y = cres.y,
                    w = cres.w,
                    h = cres.h / 3
                }
            else
                obj = {
                    x = cres.x,
                    y = cres.y,
                    w = cres.w / 3,
                    h = cres.h
                }
            end

            cwin:setFrame(obj)
        elseif option == "right_1_3" then
            local obj
            if isVerticalScreen(cscreen) then
                obj = {
                    x = cres.x,
                    y = cres.y + (cres.h / 3 * 2),
                    w = cres.w,
                    h = cres.h / 3
                }
            else
                obj = {
                    x = cres.x + (cres.w / 3 * 2),
                    y = cres.y,
                    w = cres.w / 3,
                    h = cres.h
                }
            end

            cwin:setFrame(obj)
        elseif option == "left_2_3" then
            local obj
            if isVerticalScreen(cscreen) then
                obj = {
                    x = cres.x,
                    y = cres.y,
                    w = cres.w,
                    h = cres.h / 3 * 2
                }
            else
                obj = {
                    x = cres.x,
                    y = cres.y,
                    w = cres.w / 3 * 2,
                    h = cres.h
                }
            end

            cwin:setFrame(obj)
        elseif option == "right_2_3" then
            local obj
            if isVerticalScreen(cscreen) then
                obj = {
                    x = cres.x,
                    y = cres.y + (cres.h / 3),
                    w = cres.w,
                    h = cres.h / 3 * 2
                }
            else
                obj = {
                    x = cres.x + (cres.w / 3),
                    y = cres.y,
                    w = cres.w / 3 * 2,
                    h = cres.h
                }
            end

            cwin:setFrame(obj)
        end
    else
        hs.alert.show("No focused window!")
    end
end

-- Resize the focused window in the `direction` by on step.
-- Parameters: left, right, up, down
_M.directionStepResize = function(direction)
    local cwin = hs.window.focusedWindow()

    if cwin then
        local cscreen = cwin:screen()
        local cres = cscreen:fullFrame()
        local stepw = cres.w / _M.gridparts
        local steph = cres.h / _M.gridparts
        local wsize = cwin:size()
        if direction == "left" then
            cwin:setSize({w = wsize.w - stepw, h = wsize.h})
        elseif direction == "right" then
            cwin:setSize({w = wsize.w + stepw, h = wsize.h})
        elseif direction == "up" then
            cwin:setSize({w = wsize.w, h = wsize.h - steph})
        elseif direction == "down" then
            cwin:setSize({w = wsize.w, h = wsize.h + steph})
        end
    else
        hs.alert.show("No focused window!")
    end
end

-- 窗口枚举
_M.AUTO_LAYOUT_TYPE = {
    -- 网格式布局
    GRID = "GRID",
    -- 水平或垂直评分
    HORIZONTAL_OR_VERTICAL = "HORIZONTAL_OR_VERTICAL"
}

-- 平铺模式-网格均分
local function layout_grid(windows)
    local focusedScreen = hs.screen.mainScreen()

    local layout = {
        {
            num = 1,
            row = 0,
            column = 0
        },
        {
            num = 2,
            row = 0,
            column = 1
        },
        {
            num = 4,
            row = 1,
            column = 1
        },
        {
            num = 6,
            row = 1,
            column = 2
        },
        {
            num = 9,
            row = 2,
            column = 2
        },
        {
            num = 12,
            row = 2,
            column = 3
        },
        {
            num = 16,
            row = 3,
            column = 3
        }
    }

    local windowNum = #windows
    local focusedScreenFrame = focusedScreen:frame()

    for _, item in ipairs(layout) do
        if windowNum <= item.num then
            local column = item.column
            local row = item.row

            if isVerticalScreen(focusedScreen) then
                if item.column > item.row then
                    column = item.row
                    row = item.column
                end
            end

            local widthForPerWindow = focusedScreenFrame.w / (column + 1)
            local heightForPerWindow = focusedScreenFrame.h / (row + 1)
            local nth = 1

            for i = 0, column, 1 do
                for j = 0, row, 1 do
                    -- 已没有可用窗口
                    if nth > windowNum then
                        break
                    end

                    local window = windows[nth]
                    local windowFrame = window:frame()
                    windowFrame.x = focusedScreenFrame.x + i * widthForPerWindow
                    windowFrame.y = focusedScreenFrame.y + j * heightForPerWindow
                    windowFrame.w = widthForPerWindow
                    windowFrame.h = heightForPerWindow
                    window:setFrame(windowFrame)
                    -- 让窗口获取焦点以将窗口置前
                    window:focus()
                    nth = nth + 1
                end
            end

            break
        end
    end
end

-- 平铺模式 - 水平均分
local function layout_horizontal(windows, focusedScreenFrame)
    local windowNum = #windows
    local heightForPerWindow = focusedScreenFrame.h / windowNum

    for i, window in ipairs(windows) do
        local windowFrame = window:frame()

        windowFrame.x = focusedScreenFrame.x
        windowFrame.y = focusedScreenFrame.y + heightForPerWindow * (i - 1)
        windowFrame.w = focusedScreenFrame.w
        windowFrame.h = heightForPerWindow
        window:setFrame(windowFrame)
        window:focus()
    end
end

-- 平铺模式 - 垂直均分
local function layout_vertical(windows, focusedScreenFrame)
    local windowNum = #windows
    local widthForPerWindow = focusedScreenFrame.w / windowNum

    for i, window in ipairs(windows) do
        local windowFrame = window:frame()

        windowFrame.x = focusedScreenFrame.x + widthForPerWindow * (i - 1)
        windowFrame.y = focusedScreenFrame.y
        windowFrame.w = widthForPerWindow
        windowFrame.h = focusedScreenFrame.h
        window:setFrame(windowFrame)
        window:focus()
    end
end

-- 平铺模式 - 水平（竖屏）或垂直（横屏）均分
local function layout_horizontal_or_vertical(windows)
    local focusedScreen = hs.screen.mainScreen()
    local focusedScreenFrame = focusedScreen:frame()

    -- 如果是竖屏，就水平均分，否则垂直均分
    if isVerticalScreen(focusedScreen) then
        layout_horizontal(windows, focusedScreenFrame)
    else
        layout_vertical(windows, focusedScreenFrame)
    end
end

local function layout_auto(windows, auto_layout_type)
    if _M.AUTO_LAYOUT_TYPE.GRID == auto_layout_type then
        layout_grid(windows)
    elseif _M.AUTO_LAYOUT_TYPE.HORIZONTAL_OR_VERTICAL == auto_layout_type then
        layout_horizontal_or_vertical(windows)
    end
end

_M.same_application = function(auto_layout_type)
    local focusedWindow = hs.window.focusedWindow()
    local application = focusedWindow:application()
    -- 当前屏幕
    local focusedScreen = focusedWindow:screen()
    -- 同一应用的所有窗口
    local visibleWindows = application:visibleWindows()

    for k, visibleWindow in ipairs(visibleWindows) do
        -- 关于 Standard window 可参考：http://www.hammerspoon.org/docs/hs.window.html#isStandard
        -- 例如打开 Finder 就一定会存在一个非标准窗口，这种窗口需要排除
        if not visibleWindow:isStandard() then
            table.remove(visibleWindows, k)
        end

        if visibleWindow ~= focusedWindow then
            -- 将同一应用的其他窗口移动到当前屏幕
            visibleWindow:moveToScreen(focusedScreen)
        end
    end

    layout_auto(visibleWindows, auto_layout_type)
end

_M.same_space = function(auto_layout_type)
    local spaceId = hs.spaces.focusedSpace()
    -- 该空间下的所有 window 的 id
    -- NOTE: 这里的 window 概念和 Hammerspoon 的 window 概念并不同,
    -- 详请参考：http://www.hammerspoon.org/docs/hs.spaces.html#windowsForSpace
    local windowIds = hs.spaces.windowsForSpace(spaceId)
    local windows = {}

    for _, windowId in ipairs(windowIds) do
        local window = hs.window.get(windowId)
        if window ~= nil then
            table.insert(windows, window)
        end
    end

    layout_auto(windows, auto_layout_type)
end

return _M
