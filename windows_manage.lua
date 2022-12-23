local _M = {}

_M.name = "windows_manage"
_M.version = "0.1.0"
_M.description = "app窗口管理, 比如移动、放大、缩小、分屏等"

local windows = require("shortcuts_config").windows
local windows_lib = require("windows_lib")

-- 窗口动画持续时间, 0为关闭动画效果.
hs.window.animationDuration = 0.1

-- 左半屏
hs.hotkey.bind(
    windows.left.prefix,
    windows.left.key,
    windows.left.message,
    function()
        windows_lib.moveAndResize("halfleft")
    end
)

-- 右半屏
hs.hotkey.bind(
    windows.right.prefix,
    windows.right.key,
    windows.right.message,
    function()
        windows_lib.moveAndResize("halfright")
    end
)

-- 上半屏
hs.hotkey.bind(
    windows.up.prefix,
    windows.up.key,
    windows.up.message,
    function()
        windows_lib.moveAndResize("halfup")
    end
)

-- 下半屏
hs.hotkey.bind(
    windows.down.prefix,
    windows.down.key,
    windows.down.message,
    function()
        windows_lib.moveAndResize("halfdown")
    end
)

-- 左上角
hs.hotkey.bind(
    windows.top_left.prefix,
    windows.top_left.key,
    windows.top_left.message,
    function()
        windows_lib.moveAndResize("cornerTopLeft")
    end
)

-- 右上角
hs.hotkey.bind(
    windows.top_right.prefix,
    windows.top_right.key,
    windows.top_right.message,
    function()
        windows_lib.moveAndResize("cornerTopRight")
    end
)

-- 左下角
hs.hotkey.bind(
    windows.bottom_left.prefix,
    windows.bottom_left.key,
    windows.bottom_left.message,
    function()
        windows_lib.moveAndResize("cornerBottomLeft")
    end
)

-- 右下角
hs.hotkey.bind(
    windows.bottom_right.prefix,
    windows.bottom_right.key,
    windows.bottom_right.message,
    function()
        windows_lib.moveAndResize("cornerBottomRight")
    end
)

-- 保持原有窗口大小居中
hs.hotkey.bind(
    windows.center.prefix,
    windows.center.key,
    windows.center.message,
    function()
        windows_lib.moveAndResize("center")
    end
)

-- 最大化
hs.hotkey.bind(
    windows.max.prefix,
    windows.max.key,
    windows.max.message,
    function()
        windows_lib.moveAndResize("max")
    end
)

-- 等比例放大窗口
hs.hotkey.bind(
    windows.stretch.prefix,
    windows.stretch.key,
    windows.stretch.message,
    function()
        windows_lib.moveAndResize("stretch")
    end
)

-- 等比例缩小窗口
hs.hotkey.bind(
    windows.shrink.prefix,
    windows.shrink.key,
    windows.shrink.message,
    function()
        windows_lib.moveAndResize("shrink")
    end
)

-- 左 1/3（横屏）或上 1/3（竖屏）
hs.hotkey.bind(
    windows.left_1_3.prefix,
    windows.left_1_3.key,
    windows.left_1_3.message,
    function()
        windows_lib.moveAndResize("left_1_3")
    end
)

-- 右 1/3（横屏）或下 1/3（竖屏）
hs.hotkey.bind(
    windows.right_1_3.prefix,
    windows.right_1_3.key,
    windows.right_1_3.message,
    function()
        windows_lib.moveAndResize("right_1_3")
    end
)

-- 左 2/3（横屏）或上 2/3（竖屏）
hs.hotkey.bind(
    windows.left_2_3.prefix,
    windows.left_2_3.key,
    windows.left_2_3.message,
    function()
        windows_lib.moveAndResize("left_2_3")
    end
)

-- 右 2/3（横屏）或下 2/3（竖屏）
hs.hotkey.bind(
    windows.right_2_3.prefix,
    windows.right_2_3.key,
    windows.right_2_3.message,
    function()
        windows_lib.moveAndResize("right_2_3")
    end
)

-- 上下左右移动窗口.
hs.hotkey.bind(
    windows.to_up.prefix,
    windows.to_up.key,
    windows.to_up.message,
    function()
        windows_lib.stepMove("up")
    end,
    nil,
    function()
        windows_lib.stepMove("up")
    end
)
hs.hotkey.bind(
    windows.to_down.prefix,
    windows.to_down.key,
    windows.to_down.message,
    function()
        windows_lib.stepMove("down")
    end,
    nil,
    function()
        windows_lib.stepMove("down")
    end
)
hs.hotkey.bind(
    windows.to_left.prefix,
    windows.to_left.key,
    windows.to_left.message,
    function()
        windows_lib.stepMove("left")
    end,
    nil,
    function()
        windows_lib.stepMove("left")
    end
)
hs.hotkey.bind(
    windows.to_right.prefix,
    windows.to_right.key,
    windows.to_right.message,
    function()
        windows_lib.stepMove("right")
    end,
    nil,
    function()
        windows_lib.stepMove("right")
    end
)

-- 基于底边向上或向下伸展.
hs.hotkey.bind(
    windows.stretch_up.prefix,
    windows.stretch_up.key,
    windows.stretch_up.message,
    function()
        windows_lib.directionStepResize("up")
    end,
    nil,
    function()
        windows_lib.directionStepResize("up")
    end
)
hs.hotkey.bind(
    windows.stretch_down.prefix,
    windows.stretch_down.key,
    windows.stretch_down.message,
    function()
        windows_lib.directionStepResize("down")
    end,
    nil,
    function()
        windows_lib.directionStepResize("down")
    end
)
-- 基于右边向左或向右伸展.
hs.hotkey.bind(
    windows.stretch_left.prefix,
    windows.stretch_left.key,
    windows.stretch_left.message,
    function()
        windows_lib.directionStepResize("left")
    end,
    nil,
    function()
        windows_lib.directionStepResize("left")
    end
)
hs.hotkey.bind(
    windows.stretch_right.prefix,
    windows.stretch_right.key,
    windows.stretch_right.message,
    function()
        windows_lib.directionStepResize("right")
    end,
    nil,
    function()
        windows_lib.directionStepResize("right")
    end
)

-- 将窗口移动到上下左右或下一个显示器.
hs.hotkey.bind(
    windows.to_above_screen.prefix,
    windows.to_above_screen.key,
    windows.to_above_screen.message,
    function()
        print("[INFO] move to above monitor")
        windows_lib.moveToScreen("up")
    end
)
hs.hotkey.bind(
    windows.to_below_screen.prefix,
    windows.to_below_screen.key,
    windows.to_below_screen.message,
    function()
        print("[INFO] move to below monitor")
        windows_lib.moveToScreen("down")
    end
)
hs.hotkey.bind(
    windows.to_left_screen.prefix,
    windows.to_left_screen.key,
    windows.to_left_screen.message,
    function()
        print("[INFO] move to left monitor")
        windows_lib.moveToScreen("left")
    end
)
hs.hotkey.bind(
    windows.to_right_screen.prefix,
    windows.to_right_screen.key,
    windows.to_right_screen.message,
    function()
        print("[INFO] move to right monitor")
        windows_lib.moveToScreen("right")
    end
)
hs.hotkey.bind(
    windows.to_next_screen.prefix,
    windows.to_next_screen.key,
    windows.to_next_screen.message,
    function()
        print("[INFO] move to next monitor")
        windows_lib.moveToScreen("space")
    end
)

return _M
