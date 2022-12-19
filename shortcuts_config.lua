local _M = {}

_M.version = "0.1.0"
_M.name = "shortcuts_config"
_M.description = "快捷键配置"

-- 快捷键列表展示
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
    zoom = {prefix = {"Ctrl", "Option"}, key = "=", message = "Zoom Window"},
    -- 等比例缩小窗口
    shrink = {prefix = {"Ctrl", "Option"}, key = "-", message = "Shrink Window"},
    -- **************************************
    -- 居中
    center = {prefix = {"Ctrl", "Option"}, key = "C", message = "Window Center"},
    -- 最大化
    max = {prefix = {"Ctrl", "Option"}, key = "M", message = "Max Window"},
    -- **************************************
    -- 左半屏
    left = {prefix = {"Ctrl", "Option"}, key = "H", message = "Left Half"},
    -- 右半屏
    right = {prefix = {"Ctrl", "Option"}, key = "L", message = "Right Half"},
    -- 上半屏
    up = {prefix = {"Ctrl", "Option"}, key = "K", message = "Up Half"},
    -- 下半屏
    down = {prefix = {"Ctrl", "Option"}, key = "J", message = "Down Half"},
    -- **************************************
    -- 左上角
    top_left = {prefix = {"Ctrl", "Option"}, key = "U", message = "Top Left"},
    -- 右上角
    top_right = {prefix = {"Ctrl", "Option"}, key = "I", message = "Top Right"},
    -- 左下角
    left_bottom = {prefix = {"Ctrl", "Option"}, key = "O", message = "Left Bottom"},
    -- 右下角
    right_bottom = {prefix = {"Ctrl", "Option"}, key = "P", message = "Right Bottom"},
    -- **********************************
    -- 左 1/3（横屏）或上 1/3（竖屏）
    left_1_3 = {
        prefix = {"Ctrl", "Option"},
        key = "D",
        message = "Left 1/3 or Top 1/3"
    },
    -- 中 1/3
    middle = {prefix = {"Ctrl", "Option"}, key = "F", message = "Middle 1/3"},
    -- 右 1/3（横屏）或下 1/3（竖屏）
    right_1_3 = {
        prefix = {"Ctrl", "Option"},
        key = "G",
        message = "Right 1/3 or Bottom 1/3"
    },
    -- 左 2/3（横屏）或上 2/3（竖屏）
    left_2_3 = {
        prefix = {"Ctrl", "Option"},
        key = "E",
        message = "Left 2/3 or Top 2/3"
    },
    -- 右 2/3（横屏）或下 2/3（竖屏）
    right_2_3 = {
        prefix = {"Ctrl", "Option"},
        key = "T",
        message = "Right 2/3 or Bottom 2/3"
    },
    -- **************************************
    -- 1/9
    one = {prefix = {"Ctrl", "Option"}, key = "1", message = "1/9"},
    -- 2/9
    two = {prefix = {"Ctrl", "Option"}, key = "2", message = "2/9"},
    -- 3/9
    three = {prefix = {"Ctrl", "Option"}, key = "3", message = "3/9"},
    -- 4/9
    four = {prefix = {"Ctrl", "Option"}, key = "4", message = "4/9"},
    -- 5/9
    five = {prefix = {"Ctrl", "Option"}, key = "5", message = "5/9"},
    -- 6/9
    six = {prefix = {"Ctrl", "Option"}, key = "6", message = "6/9"},
    -- 7/9
    seven = {prefix = {"Ctrl", "Option"}, key = "7", message = "7/9"},
    -- 8/9
    eight = {prefix = {"Ctrl", "Option"}, key = "8", message = "8/9"},
    -- 9/9
    nine = {prefix = {"Ctrl", "Option"}, key = "9", message = "9/9"},
    -- **************************************
    -- 同一工作空间下的所有窗口自动网格式布局
    same_space_auto_layout_grid = {prefix = {"Ctrl", "Option"}, key = "X", message = "Same space layout grid"},
    -- 同一工作空间下的所有窗口自动水平均分或垂直均分
    same_space_auto_layout_horizontal_or_vertical = {
        prefix = {"Ctrl", "Option"},
        key = "S",
        message = "Same space layout Horz/Vert"
    },
    -- **************************************
    -- 同一应用的所有窗口自动网格式布局
    same_application_auto_layout_grid = {
        prefix = {"Ctrl", "Option"},
        key = "Z",
        message = "Same app layout grid"
    },
    -- 同一应用的所有窗口自动水平均分或垂直均分
    same_application_auto_layout_horizontal_or_vertical = {
        prefix = {"Ctrl", "Option"},
        key = "A",
        message = "Same app layout Horz/Vert"
    },
    -- **********************************
    -- 将窗口移动到上方屏幕
    to_up = {prefix = {"Ctrl", "Option", "Command"}, key = "K", message = "Move To Up Screen"},
    -- 将窗口移动到下方屏幕
    to_down = {prefix = {"Ctrl", "Option", "Command"}, key = "J", message = "Move To Down Screen"},
    -- 将窗口移动到左侧屏幕
    to_left = {prefix = {"Ctrl", "Option", "Command"}, key = "H", message = "Move To Left Screen"},
    -- 将窗口移动到右侧屏幕
    to_right = {prefix = {"Ctrl", "Option", "Command"}, key = "L", message = "Move To Right Screen"}
}

return _M
