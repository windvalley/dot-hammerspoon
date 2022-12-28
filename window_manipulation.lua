local _M = {}

_M.name = "window_manipulation"
_M.description = "app窗口管理, 比如移动、放大、缩小、分屏等"

local window_position = require("keybindings_config").window_position
local window_movement = require("keybindings_config").window_movement
local window_resize = require("keybindings_config").window_resize
local window_batch = require("keybindings_config").window_batch
local window_monitor = require("keybindings_config").window_monitor

local window_lib = require("window_lib")

local log = hs.logger.new("window")

-- 窗口动画持续时间, 0为关闭动画效果.
hs.window.animationDuration = 0.1

-- ********** window position **********
-- 居中
hs.hotkey.bind(
    window_position.center.prefix,
    window_position.center.key,
    window_position.center.message,
    function()
        window_lib.moveAndResize("center")
    end
)
-- 左半屏
hs.hotkey.bind(
    window_position.left.prefix,
    window_position.left.key,
    window_position.left.message,
    function()
        window_lib.moveAndResize("halfleft")
    end
)
-- 右半屏
hs.hotkey.bind(
    window_position.right.prefix,
    window_position.right.key,
    window_position.right.message,
    function()
        window_lib.moveAndResize("halfright")
    end
)
-- 上半屏
hs.hotkey.bind(
    window_position.up.prefix,
    window_position.up.key,
    window_position.up.message,
    function()
        window_lib.moveAndResize("halfup")
    end
)
-- 下半屏
hs.hotkey.bind(
    window_position.down.prefix,
    window_position.down.key,
    window_position.down.message,
    function()
        window_lib.moveAndResize("halfdown")
    end
)
-- 左上角
hs.hotkey.bind(
    window_position.top_left.prefix,
    window_position.top_left.key,
    window_position.top_left.message,
    function()
        window_lib.moveAndResize("cornerTopLeft")
    end
)
-- 右上角
hs.hotkey.bind(
    window_position.top_right.prefix,
    window_position.top_right.key,
    window_position.top_right.message,
    function()
        window_lib.moveAndResize("cornerTopRight")
    end
)
-- 左下角
hs.hotkey.bind(
    window_position.bottom_left.prefix,
    window_position.bottom_left.key,
    window_position.bottom_left.message,
    function()
        window_lib.moveAndResize("cornerBottomLeft")
    end
)
-- 右下角
hs.hotkey.bind(
    window_position.bottom_right.prefix,
    window_position.bottom_right.key,
    window_position.bottom_right.message,
    function()
        window_lib.moveAndResize("cornerBottomRight")
    end
)
-- 左 1/3（横屏）或上 1/3（竖屏）
hs.hotkey.bind(
    window_position.left_1_3.prefix,
    window_position.left_1_3.key,
    window_position.left_1_3.message,
    function()
        window_lib.moveAndResize("left_1_3")
    end
)
-- 右 1/3（横屏）或下 1/3（竖屏）
hs.hotkey.bind(
    window_position.right_1_3.prefix,
    window_position.right_1_3.key,
    window_position.right_1_3.message,
    function()
        window_lib.moveAndResize("right_1_3")
    end
)
-- 左 2/3（横屏）或上 2/3（竖屏）
hs.hotkey.bind(
    window_position.left_2_3.prefix,
    window_position.left_2_3.key,
    window_position.left_2_3.message,
    function()
        window_lib.moveAndResize("left_2_3")
    end
)
-- 右 2/3（横屏）或下 2/3（竖屏）
hs.hotkey.bind(
    window_position.right_2_3.prefix,
    window_position.right_2_3.key,
    window_position.right_2_3.message,
    function()
        window_lib.moveAndResize("right_2_3")
    end
)

-- ********** window resize **********
-- 最大化
hs.hotkey.bind(
    window_resize.max.prefix,
    window_resize.max.key,
    window_resize.max.message,
    function()
        window_lib.moveAndResize("max")
    end
)
-- 等比例放大窗口
hs.hotkey.bind(
    window_resize.stretch.prefix,
    window_resize.stretch.key,
    window_resize.stretch.message,
    function()
        window_lib.moveAndResize("stretch")
    end
)
-- 等比例缩小窗口
hs.hotkey.bind(
    window_resize.shrink.prefix,
    window_resize.shrink.key,
    window_resize.shrink.message,
    function()
        window_lib.moveAndResize("shrink")
    end
)
-- 基于底边向上或向下伸展.
hs.hotkey.bind(
    window_resize.stretch_up.prefix,
    window_resize.stretch_up.key,
    window_resize.stretch_up.message,
    function()
        window_lib.directionStepResize("up")
    end,
    nil,
    function()
        window_lib.directionStepResize("up")
    end
)
hs.hotkey.bind(
    window_resize.stretch_down.prefix,
    window_resize.stretch_down.key,
    window_resize.stretch_down.message,
    function()
        window_lib.directionStepResize("down")
    end,
    nil,
    function()
        window_lib.directionStepResize("down")
    end
)
-- 基于右边向左或向右伸展.
hs.hotkey.bind(
    window_resize.stretch_left.prefix,
    window_resize.stretch_left.key,
    window_resize.stretch_left.message,
    function()
        window_lib.directionStepResize("left")
    end,
    nil,
    function()
        window_lib.directionStepResize("left")
    end
)
hs.hotkey.bind(
    window_resize.stretch_right.prefix,
    window_resize.stretch_right.key,
    window_resize.stretch_right.message,
    function()
        window_lib.directionStepResize("right")
    end,
    nil,
    function()
        window_lib.directionStepResize("right")
    end
)

-- ********** window movement **********
-- 上下左右移动窗口.
hs.hotkey.bind(
    window_movement.to_up.prefix,
    window_movement.to_up.key,
    window_movement.to_up.message,
    function()
        window_lib.stepMove("up")
    end,
    nil,
    function()
        window_lib.stepMove("up")
    end
)
hs.hotkey.bind(
    window_movement.to_down.prefix,
    window_movement.to_down.key,
    window_movement.to_down.message,
    function()
        window_lib.stepMove("down")
    end,
    nil,
    function()
        window_lib.stepMove("down")
    end
)
hs.hotkey.bind(
    window_movement.to_left.prefix,
    window_movement.to_left.key,
    window_movement.to_left.message,
    function()
        window_lib.stepMove("left")
    end,
    nil,
    function()
        window_lib.stepMove("left")
    end
)
hs.hotkey.bind(
    window_movement.to_right.prefix,
    window_movement.to_right.key,
    window_movement.to_right.message,
    function()
        window_lib.stepMove("right")
    end,
    nil,
    function()
        window_lib.stepMove("right")
    end
)

-- ********** window monitor **********
-- 将窗口移动到上下左右或下一个显示器.
hs.hotkey.bind(
    window_monitor.to_above_screen.prefix,
    window_monitor.to_above_screen.key,
    window_monitor.to_above_screen.message,
    function()
        log.d("move to above monitor")
        window_lib.moveToScreen("up")
    end
)
hs.hotkey.bind(
    window_monitor.to_below_screen.prefix,
    window_monitor.to_below_screen.key,
    window_monitor.to_below_screen.message,
    function()
        log.d("move to below monitor")
        window_lib.moveToScreen("down")
    end
)
hs.hotkey.bind(
    window_monitor.to_left_screen.prefix,
    window_monitor.to_left_screen.key,
    window_monitor.to_left_screen.message,
    function()
        log.d("move to left monitor")
        window_lib.moveToScreen("left")
    end
)
hs.hotkey.bind(
    window_monitor.to_right_screen.prefix,
    window_monitor.to_right_screen.key,
    window_monitor.to_right_screen.message,
    function()
        log.d("move to right monitor")
        window_lib.moveToScreen("right")
    end
)
hs.hotkey.bind(
    window_monitor.to_next_screen.prefix,
    window_monitor.to_next_screen.key,
    window_monitor.to_next_screen.message,
    function()
        log.d("move to next monitor")
        window_lib.moveToScreen("next")
    end
)

-- ********** window batch **********
-- 最小化所有窗口
hs.hotkey.bind(
    window_batch.minimize_all_windows.prefix,
    window_batch.minimize_all_windows.key,
    window_batch.minimize_all_windows.message,
    function()
        log.d("minimized all windows")
        window_lib.minimizeAllWindows()
    end
)
-- 恢复所有最小化的窗口
hs.hotkey.bind(
    window_batch.un_minimize_all_windows.prefix,
    window_batch.un_minimize_all_windows.key,
    window_batch.un_minimize_all_windows.message,
    function()
        log.d("unminimize all windows")
        window_lib.unMinimizeAllWindows()
    end
)
-- 关闭所有窗口
hs.hotkey.bind(
    window_batch.close_all_windows.prefix,
    window_batch.close_all_windows.key,
    window_batch.close_all_windows.message,
    function()
        log.d("close all windows")
        window_lib.closeAllWindows()
    end
)

return _M
