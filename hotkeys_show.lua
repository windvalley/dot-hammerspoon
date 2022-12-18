local _M = {}

_M.name = "hotkeys_show"
_M.version = "0.1.0"
_M.description = "展示快捷键列表"

local hotkeys_show = require "shortcuts_config".hotkeys_show
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
        fillColor = {alpha = 0.9, red = 0, green = 0, blue = 0},
        type = "rectangle"
    }
)

local function styleText(text)
    return hs.styledtext.new(
        text,
        {
            font = {
                name = "Monaco",
                size = 16
            },
            color = {hex = "#0096FA"},
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

    -- 快捷键分类
    -- 应用切换类
    local applicationSwitchText = {}
    table.insert(applicationSwitchText, {msg = "[Apps Switch]"})

    -- 窗口管理类
    local windowManagement = {}
    table.insert(windowManagement, {msg = "[Windows Manage]"})

    -- 每行最多 40 个字符
    local MAX_LEN = 40

    -- 快捷键分类
    for _, v in ipairs(hotkeys) do
        -- 以 ⌥ 开头，表示为应用切换快捷键
        if string.find(v.idx, "^⌥") ~= nil then
            table.insert(applicationSwitchText, {msg = v.msg})
        end

        -- 以 ⌃⌥ 或 ⌘⌃⌥ 开头，表示为窗口管理快捷键
        if string.find(v.idx, "^⌃⌥") ~= nil or string.find(v.idx, "^⌘⌃⌥") ~= nil then
            table.insert(windowManagement, {msg = v.msg})
        end
    end

    hotkeys = {}

    for _, v in ipairs(applicationSwitchText) do
        table.insert(hotkeys, {msg = v.msg})
    end

    for _, v in ipairs(windowManagement) do
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
                    strokeColor = {hex = "#0096FA"},
                    action = "stroke",
                    strokeWidth = 2,
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

        column = nil
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

-- 绑定显示/隐藏快捷键列表功能的快捷键
hs.hotkey.bind(hotkeys_show.prefix, hotkeys_show.key, toggleHotkeysShow)

return _M
