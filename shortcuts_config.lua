local _M = {}

_M.name = "shortcuts_config"
_M.version = "0.1.0"
_M.description = "快捷键配置"

-- 每次按快捷键时显示快捷键alert消息持续的秒数, 0 为禁用.
hs.hotkey.alertDuration = 0

-- 快捷键备忘单展示
_M.hotkeys_show = {
    prefix = {
        "Option"
    },
    key = "/"
}

-- 指定目标输入法
_M.input_methods = {
    abc = {prefix = {"Option"}, key = "1", message = "ABC"},
    -- NOTE: message的值不能是中文, 会导致快捷键列表面板显示错位.
    chinese = {prefix = {"Option"}, key = "2", message = "Pinyin"}
}

-- App切换
-- NOTE:
--   获取某个App的bundleId的方法举例: osascript -e 'id of app "chrome"'
_M.apps = {
    {prefix = {"Option"}, key = "H", message = "Hammerspoon", bundleId = "org.hammerspoon.Hammerspoon"},
    {prefix = {"Option"}, key = "F", message = "Finder", bundleId = "com.apple.finder"},
    {prefix = {"Option"}, key = "I", message = "Alacritty", bundleId = "io.alacritty"},
    {prefix = {"Option"}, key = "C", message = "Chrome", bundleId = "com.google.Chrome"},
    {prefix = {"Option"}, key = "N", message = "Note", bundleId = "ynote-desktop"},
    {prefix = {"Option"}, key = "M", message = "Mail", bundleId = "com.apple.mail"},
    {prefix = {"Option"}, key = "P", message = "Postman", bundleId = "com.postmanlabs.mac"},
    {prefix = {"Option"}, key = "E", message = "Excel", bundleId = "com.microsoft.Excel"},
    {prefix = {"Option"}, key = "V", message = "VSCode", bundleId = "com.microsoft.VSCode"},
    {prefix = {"Option"}, key = "J", message = "Tuitui", bundleId = "mac.im.qihoo.net"},
    {prefix = {"Option"}, key = "W", message = "WeChat", bundleId = "com.tencent.xinWeChat"}
}

-- 窗口管理
_M.windows = {
    -- 等比例放大窗口
    stretch = {prefix = {"Ctrl", "Option"}, key = "=", message = "Stretch Outward"},
    -- 等比例缩小窗口
    shrink = {prefix = {"Ctrl", "Option"}, key = "-", message = "Shrink Inward"},
    -- **************************************
    -- 居中
    center = {prefix = {"Ctrl", "Option"}, key = "C", message = "Center Window"},
    -- 最大化
    max = {prefix = {"Ctrl", "Option"}, key = "M", message = "Max Window"},
    -- **************************************
    -- 左半屏
    left = {prefix = {"Ctrl", "Option"}, key = "H", message = "Left Half of Screen"},
    -- 右半屏
    right = {prefix = {"Ctrl", "Option"}, key = "L", message = "Right Half of Screen"},
    -- 上半屏
    up = {prefix = {"Ctrl", "Option"}, key = "K", message = "Up Half of Screen"},
    -- 下半屏
    down = {prefix = {"Ctrl", "Option"}, key = "J", message = "Down Half of Screen"},
    -- **************************************
    -- 左上角
    top_left = {prefix = {"Ctrl", "Option"}, key = "Y", message = "Top Left Corner"},
    -- 右上角
    top_right = {prefix = {"Ctrl", "Option"}, key = "O", message = "Top Right Corner"},
    -- 左下角
    bottom_left = {prefix = {"Ctrl", "Option"}, key = "U", message = "Bottom Left Corner"},
    -- 右下角
    bottom_right = {prefix = {"Ctrl", "Option"}, key = "I", message = "Bottom Right Corner"},
    -- **********************************
    -- 左 1/3（横屏）或上 1/3（竖屏）
    left_1_3 = {
        prefix = {"Ctrl", "Option"},
        key = "Q",
        message = "Left or Top 1/3"
    },
    -- 右 1/3（横屏）或下 1/3（竖屏）
    right_1_3 = {
        prefix = {"Ctrl", "Option"},
        key = "W",
        message = "Right or Bottom 1/3"
    },
    -- 左 2/3（横屏）或上 2/3（竖屏）
    left_2_3 = {
        prefix = {"Ctrl", "Option"},
        key = "E",
        message = "Left or Top 2/3"
    },
    -- 右 2/3（横屏）或下 2/3（竖屏）
    right_2_3 = {
        prefix = {"Ctrl", "Option"},
        key = "R",
        message = "Right or Bottom 2/3"
    },
    -- **************************************
    -- 向上移动窗口
    to_up = {
        prefix = {"Ctrl", "Option", "Command"},
        key = "K",
        message = "Move Upward"
    },
    -- 向下移动窗口
    to_down = {
        prefix = {"Ctrl", "Option", "Command"},
        key = "J",
        message = "Move Downward"
    },
    -- 向左移动窗口
    to_left = {
        prefix = {"Ctrl", "Option", "Command"},
        key = "H",
        message = "Move Leftward"
    },
    -- 向右移动窗口
    to_right = {
        prefix = {"Ctrl", "Option", "Command"},
        key = "L",
        message = "Move Rightward"
    },
    -- **************************************
    -- 底边向上伸展窗口
    stretch_up = {
        prefix = {"Ctrl", "Option", "Command", "Shift"},
        key = "K",
        message = "Bottom Side Stretch Upward"
    },
    -- 底边向下伸展窗口
    stretch_down = {
        prefix = {"Ctrl", "Option", "Command", "Shift"},
        key = "J",
        message = "Bottom Side Stretch Downward"
    },
    -- 右边向左伸展窗口
    stretch_left = {
        prefix = {"Ctrl", "Option", "Command", "Shift"},
        key = "H",
        message = "Right Side Stretch Leftward"
    },
    -- 右边向右伸展窗口
    stretch_right = {
        prefix = {"Ctrl", "Option", "Command", "Shift"},
        key = "L",
        message = "Right Side Stretch Rightward"
    }
}

return _M
