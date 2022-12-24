local _M = {}

_M.name = "windows_lib"
_M.version = "0.1.0"
_M.description = "窗口管理相关函数库"

-- An integer specifying how many gridparts the screen should be divided into.
-- Defaults to 30.
local gridparts = 30

-- 判断指定屏幕是否为竖屏
local isVerticalScreen = function(screen)
    if screen:rotate() == 90 or screen:rotate() == 270 then
        return true
    else
        return false
    end
end

-- Move the focused window in the `direction` by on step.
-- Parameters: left, right, up, down
_M.stepMove = function(direction)
    local cwin = hs.window.focusedWindow()
    if cwin then
        local cscreen = cwin:screen()
        local cres = cscreen:fullFrame()
        local stepw = cres.w / gridparts
        local steph = cres.h / gridparts
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
        local stepw = cres.w / gridparts
        local steph = cres.h / gridparts
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
            -- cwin:centerOnScreen() 居中但不改变大小,
            -- 改成如下居中且调整成适当的大小.
            cwin:setFrame(
                {
                    x = cres.x + cres.w / 6,
                    y = cres.y + cres.h / 6,
                    w = cres.w / 1.5,
                    h = cres.h / 1.5
                }
            )
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
        local stepw = cres.w / gridparts
        local steph = cres.h / gridparts
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

-- Move the focused window between all of the screens in the `direction`.
-- Parameters: up, down, left, right, next
_M.moveToScreen = function(direction)
    local cwin = hs.window.focusedWindow()

    if cwin then
        local cscreen = cwin:screen()
        if direction == "up" then
            cwin:moveOneScreenNorth()
        elseif direction == "down" then
            cwin:moveOneScreenSouth()
        elseif direction == "left" then
            cwin:moveOneScreenWest()
        elseif direction == "right" then
            cwin:moveOneScreenEast()
        elseif direction == "next" then
            cwin:moveToScreen(cscreen:next())
        end
    else
        hs.alert.show("No focused window!")
    end
end

return _M
