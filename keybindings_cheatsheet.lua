local _M = {}

_M.name = "keybindings_cheatsheet"
_M.version = "0.1.0"
_M.description = "展示快捷键备忘列表"

local keybindings_cheatsheet = require "keybindings_config".keybindings_cheatsheet
local input_methods = require "keybindings_config".input_methods
local system = require "keybindings_config".system
local urls = require "keybindings_config".urls

local window_position = require("keybindings_config").window_position
local window_movement = require("keybindings_config").window_movement
local window_resize = require("keybindings_config").window_resize
local window_monitor = require("keybindings_config").window_monitor
local window_batch = require("keybindings_config").window_batch

local utf8len = require "utils_lib".utf8len
local utf8sub = require "utils_lib".utf8sub

local focusedWindow = hs.window.focusedWindow()
if focusedWindow == nil then
    return
end

local screen = focusedWindow:screen():frame()

local COORIDNATE_X = screen.w / 2
local COORIDNATE_Y = screen.h / 2

-- 快捷键总数
local num = 0

local canvas = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})

-- 背景面板
canvas:appendElements(
    {
        id = "pannel",
        action = "fill",
        fillColor = {alpha = 0.8, red = 0, green = 0, blue = 0},
        type = "rectangle"
    }
)

local function styleText(text)
    return hs.styledtext.new(
        text,
        {
            font = {
                name = "Monaco",
                size = 15
            },
            color = {hex = "#c6c6c6"},
            paragraphStyle = {
                lineSpacing = 5
            }
        }
    )
end

local function formatText()
    -- 加载所有绑定的快捷键
    local hotkeys = hs.hotkey.getHotkeys()

    local renderText = {}

    local inputMethods = {}
    table.insert(inputMethods, {msg = "[Input Methods]"})

    local systemManagement = {}
    table.insert(systemManagement, {msg = "[System Management]"})

    local openURL = {}
    table.insert(openURL, {msg = "[Open URL]"})

    local applicationLaunch = {}
    table.insert(applicationLaunch, {msg = "[Application Launch]"})

    local windowPosition = {}
    table.insert(windowPosition, {msg = "[Window Position]"})

    local windowMovement = {}
    table.insert(windowMovement, {msg = "[Window Movement]"})

    local windowResize = {}
    table.insert(windowResize, {msg = "[Window Resize]"})

    local windowMonitor = {}
    table.insert(windowMonitor, {msg = "[Window Monitor]"})

    local windowBatch = {}
    table.insert(windowBatch, {msg = "[Window Batch]"})

    -- 每行最多 35 个字符
    local MAX_LEN = 35

    -- 快捷键分类
    for _, v in ipairs(hotkeys) do
        -- 输入法切换.
        if
            string.find(v.msg, input_methods.abc.message) ~= nil or
                string.find(v.msg, input_methods.pinyin.message) ~= nil
         then
            table.insert(inputMethods, {msg = v.msg})
            goto continue
        end

        -- 系统管理.
        if
            string.find(v.msg, system.lock_screen.message) ~= nil or
                string.find(v.msg, system.screen_saver.message) ~= nil or
                string.find(v.msg, system.restart.message) ~= nil or
                string.find(v.msg, system.shutdown.message) ~= nil
         then
            table.insert(systemManagement, {msg = v.msg})
            goto continue
        end

        -- Open URL.
        for _, u in pairs(urls) do
            if string.find(v.msg, u.message) ~= nil then
                table.insert(openURL, {msg = v.msg})
                goto continue
            end
        end

        -- window position
        if
            string.find(v.msg, window_position.up.message) ~= nil or
                string.find(v.msg, window_position.down.message) ~= nil or
                string.find(v.msg, window_position.left.message) ~= nil or
                string.find(v.msg, window_position.right.message) ~= nil or
                string.find(v.msg, window_position.center.message) ~= nil or
                string.find(v.msg, window_position.top_left.message) ~= nil or
                string.find(v.msg, window_position.top_right.message) ~= nil or
                string.find(v.msg, window_position.bottom_left.message) ~= nil or
                string.find(v.msg, window_position.bottom_right.message) ~= nil or
                string.find(v.msg, window_position.left_1_3.message) ~= nil or
                string.find(v.msg, window_position.right_1_3.message) ~= nil or
                string.find(v.msg, window_position.left_2_3.message) ~= nil or
                string.find(v.msg, window_position.right_2_3.message) ~= nil
         then
            table.insert(windowPosition, {msg = v.msg})
            goto continue
        end

        -- window movement
        if
            string.find(v.msg, window_movement.to_up.message) ~= nil or
                string.find(v.msg, window_movement.to_down.message) ~= nil or
                string.find(v.msg, window_movement.to_left.message) ~= nil or
                string.find(v.msg, window_movement.to_right.message) ~= nil
         then
            table.insert(windowMovement, {msg = v.msg})
            goto continue
        end

        -- window resize
        if
            string.find(v.msg, window_resize.max.message) ~= nil or
                string.find(v.msg, window_resize.stretch.message) ~= nil or
                string.find(v.msg, window_resize.shrink.message) ~= nil or
                string.find(v.msg, window_resize.stretch_up.message) ~= nil or
                string.find(v.msg, window_resize.stretch_down.message) ~= nil or
                string.find(v.msg, window_resize.stretch_left.message) ~= nil or
                string.find(v.msg, window_resize.stretch_right.message) ~= nil
         then
            table.insert(windowResize, {msg = v.msg})
            goto continue
        end

        -- window monitor
        if
            string.find(v.msg, window_monitor.to_above_screen.message) ~= nil or
                string.find(v.msg, window_monitor.to_below_screen.message) ~= nil or
                string.find(v.msg, window_monitor.to_left_screen.message) ~= nil or
                string.find(v.msg, window_monitor.to_right_screen.message) ~= nil or
                string.find(v.msg, window_monitor.to_next_screen.message) ~= nil
         then
            table.insert(windowMonitor, {msg = v.msg})
            goto continue
        end

        -- window batch
        if
            string.find(v.msg, window_batch.minimize_all_windows.message) ~= nil or
                string.find(v.msg, window_batch.un_minimize_all_windows.message) ~= nil or
                string.find(v.msg, window_batch.close_all_windows.message) ~= nil
         then
            table.insert(windowBatch, {msg = v.msg})
            goto continue
        end

        -- 其他的以 ⌥  开头, 表示为应用启动或切换快捷键.
        if string.find(v.idx, "^⌥") ~= nil then
            table.insert(applicationLaunch, {msg = v.msg})
        end

        ::continue::
    end

    table.insert(applicationLaunch, {msg = "⌥/: Toggle Keybindings Cheatsheet"})

    hotkeys = {}

    for _, v in ipairs(inputMethods) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(systemManagement) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(openURL) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(applicationLaunch) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(windowPosition) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(windowMovement) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(windowResize) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(windowMonitor) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(windowBatch) do
        table.insert(hotkeys, {msg = v.msg})
    end

    -- 文本定长
    for _, v in ipairs(hotkeys) do
        num = num + 1

        local msg = v.msg
        local len = utf8len(msg)

        -- 超过最大长度，截断多余部分，截断的部分作为新的一行
        while len > MAX_LEN do
            local substr = utf8sub(msg, 1, MAX_LEN)
            table.insert(renderText, {line = substr})

            msg = utf8sub(msg, MAX_LEN + 1, len)
            len = utf8len(msg)
        end

        for _ = 1, MAX_LEN - utf8len(msg), 1 do
            msg = msg .. " "
        end

        table.insert(renderText, {line = msg})
    end

    return renderText
end

local function drawText(renderText)
    -- 每列最多 20 行
    local MAX_LINE_NUM = 20
    local w = 0
    local h = 0
    -- 文本距离分割线的距离
    local SEPRATOR_W = 5

    -- 每一列需要显示的文本
    local column = ""

    for k, v in ipairs(renderText) do
        local line = v.line
        if math.fmod(k, MAX_LINE_NUM) == 0 then
            column = column .. line .. "  "
        else
            column = column .. line .. "  \n"
        end

        -- k mod MAX_LINE_NUM
        if math.fmod(k, MAX_LINE_NUM) == 0 then
            local itemText = styleText(column)
            local size = canvas:minimumTextSize(itemText)

            -- 多 text size w 累加
            w = w + size.w
            if k == MAX_LINE_NUM then
                h = size.h
            end

            canvas:appendElements(
                {
                    type = "text",
                    text = itemText,
                    frame = {
                        x = (k / MAX_LINE_NUM - 1) * size.w + SEPRATOR_W,
                        y = 0,
                        w = size.w + SEPRATOR_W,
                        h = size.h
                    }
                }
            )

            canvas:appendElements(
                {
                    type = "segments",
                    closed = false,
                    -- 分割线的颜色
                    strokeColor = {hex = "#585858"},
                    action = "stroke",
                    -- 分隔线的宽度
                    strokeWidth = 1,
                    coordinates = {
                        {x = (k / MAX_LINE_NUM) * size.w - SEPRATOR_W, y = 0},
                        {x = (k / MAX_LINE_NUM) * size.w - SEPRATOR_W, y = h}
                    }
                }
            )

            column = ""
        end
    end

    if column ~= nil then
        local itemText = styleText(column)
        local size = canvas:minimumTextSize(itemText)

        w = w + size.w

        canvas:appendElements(
            {
                type = "text",
                text = itemText,
                frame = {
                    x = math.ceil(num / MAX_LINE_NUM - 1) * size.w + SEPRATOR_W,
                    y = 0,
                    w = size.w + SEPRATOR_W,
                    h = size.h
                }
            }
        )
    end

    -- 居中显示
    canvas:frame({x = COORIDNATE_X - w / 2, y = COORIDNATE_Y - h / 2, w = w, h = h})
end

-- 默认不显示
local show = false
local function toggleHotkeysShow()
    if show then
        -- 0.3s 过渡
        canvas:hide(.3)
    else
        canvas:show(.3)
    end

    show = not show
end

-- 执行绘制
drawText(formatText())

-- 显示/隐藏快捷键备忘列表
hs.hotkey.bind(
    keybindings_cheatsheet.prefix,
    keybindings_cheatsheet.key,
    keybindings_cheatsheet.message,
    toggleHotkeysShow
)

return _M
