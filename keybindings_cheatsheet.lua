local _M = {}

_M.name = "keybindings_cheatsheet"
_M.description = "展示快捷键备忘列表"

local keybindings_cheatsheet = require "keybindings_config".keybindings_cheatsheet
local input_methods = require "keybindings_config".manual_input_methods
local system = require "keybindings_config".system
local websites = require "keybindings_config".websites
local apps = require "keybindings_config".apps

local window_position = require("keybindings_config").window_position
local window_movement = require("keybindings_config").window_movement
local window_resize = require("keybindings_config").window_resize
local window_monitor = require("keybindings_config").window_monitor
local window_batch = require("keybindings_config").window_batch

local utf8len = require "utils_lib".utf8len
local utf8sub = require "utils_lib".utf8sub
local split = require "utils_lib".split
local trim = require "utils_lib".trim

-- 背景不透明度
local background_opacity = 0.8
-- 每行最大的长度
local max_line_length = 35
-- 每列的行数
local max_line_number = 20
-- 行距
local line_spacing = 5
-- 文本距离分割线的距离
local seperator_spacing = 6
-- 字体名称
local font_name = "Monaco"
-- 字体大小
local font_size = 15
-- 字体颜色
local font_color = "#c6c6c6"
-- 分割线颜色
local stroke_color = "#585858"
-- 分割线的宽度
local stroke_width = 1

local focusedWindow = hs.window.focusedWindow()
if focusedWindow == nil then
    return
end

local screen = focusedWindow:screen():frame()

local cooridnate_x = screen.w / 2
local cooridnate_y = screen.h / 2

-- 快捷键总数
local num = 0

local canvas = hs.canvas.new({x = 0, y = 0, w = 0, h = 0})

-- 背景面板
canvas:appendElements(
    {
        id = "pannel",
        action = "fill",
        fillColor = {alpha = background_opacity, red = 0, green = 0, blue = 0},
        type = "rectangle"
    }
)

local function styleText(text)
    return hs.styledtext.new(
        text,
        {
            font = {
                name = font_name,
                size = font_size
            },
            color = {hex = font_color},
            paragraphStyle = {
                lineSpacing = line_spacing
            }
        }
    )
end

local function formatText()
    -- 加载所有绑定的快捷键
    local hotkeys = hs.hotkey.getHotkeys()

    local renderText = {}

    local keybindingsCheatsheet = {}
    table.insert(keybindingsCheatsheet, {msg = "[Cheatsheet]"})
    table.insert(keybindingsCheatsheet, {msg = keybindings_cheatsheet.description})

    local inputMethods = {}
    table.insert(inputMethods, {msg = "[Input Methods]"})

    local systemManagement = {}
    table.insert(systemManagement, {msg = "[System Management]"})

    local WebsiteOpen = {}
    table.insert(WebsiteOpen, {msg = "[Website Open]"})

    local applicationLaunch = {}
    table.insert(applicationLaunch, {msg = "[App Launch Or Hide]"})

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

    -- 快捷键分类
    for _, v in ipairs(hotkeys) do
        local _msg = trim(split(v.msg, ":")[2])

        -- Input methods
        for _, i in pairs(input_methods) do
            if _msg == i.message then
                table.insert(inputMethods, {msg = v.msg})
                goto continue
            end
        end

        -- System management
        for _, s in pairs(system) do
            if _msg == s.message then
                table.insert(systemManagement, {msg = v.msg})
                goto continue
            end
        end

        -- Open URL.
        for _, u in pairs(websites) do
            if _msg == u.message then
                table.insert(WebsiteOpen, {msg = v.msg})
                goto continue
            end
        end

        -- Application launch or switch
        for _, a in pairs(apps) do
            if _msg == a.message then
                table.insert(applicationLaunch, {msg = v.msg})
                goto continue
            end
        end

        -- Window position
        for _, wp in pairs(window_position) do
            if _msg == wp.message then
                table.insert(windowPosition, {msg = v.msg})
                goto continue
            end
        end

        -- Window movement
        for _, wm in pairs(window_movement) do
            if _msg == wm.message then
                table.insert(windowMovement, {msg = v.msg})
                goto continue
            end
        end

        -- Window resize
        for _, wr in pairs(window_resize) do
            if _msg == wr.message then
                table.insert(windowResize, {msg = v.msg})
                goto continue
            end
        end

        -- Window monitor
        for _, wm in pairs(window_monitor) do
            if _msg == wm.message then
                table.insert(windowMonitor, {msg = v.msg})
                goto continue
            end
        end

        -- Window batch
        for _, wb in pairs(window_batch) do
            if _msg == wb.message then
                table.insert(windowBatch, {msg = v.msg})
                goto continue
            end
        end

        ::continue::
    end

    hotkeys = {}

    for _, v in ipairs(keybindingsCheatsheet) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(inputMethods) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(systemManagement) do
        table.insert(hotkeys, {msg = v.msg})
    end

    table.insert(hotkeys, {msg = ""})

    for _, v in ipairs(WebsiteOpen) do
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

        -- 超过最大长度, 截断多余部分, 截断的部分作为新的一行.
        while len > max_line_length do
            local substr = utf8sub(msg, 1, max_line_length)
            table.insert(renderText, {line = substr})

            msg = utf8sub(msg, max_line_length + 1, len)
            len = utf8len(msg)
        end

        for _ = 1, max_line_length - utf8len(msg), 1 do
            msg = msg .. " "
        end

        table.insert(renderText, {line = msg})
    end

    return renderText
end

local function drawText(renderText)
    local w = 0
    local h = 0

    -- 每一列需要显示的文本
    local column = ""

    for k, v in ipairs(renderText) do
        local line = v.line
        if math.fmod(k, max_line_number) == 0 then
            column = column .. line .. "  "
        else
            column = column .. line .. "  \n"
        end

        -- k mod max_line_number
        if math.fmod(k, max_line_number) == 0 then
            local itemText = styleText(column)
            local size = canvas:minimumTextSize(itemText)

            w = w + size.w
            if k == max_line_number then
                h = size.h
            end

            canvas:appendElements(
                {
                    type = "text",
                    text = itemText,
                    frame = {
                        x = (k / max_line_number - 1) * size.w + seperator_spacing,
                        y = 0,
                        w = size.w + seperator_spacing,
                        h = size.h
                    }
                }
            )

            canvas:appendElements(
                {
                    type = "segments",
                    closed = false,
                    strokeColor = {hex = stroke_color},
                    action = "stroke",
                    strokeWidth = stroke_width,
                    coordinates = {
                        {x = (k / max_line_number) * size.w - seperator_spacing, y = 0},
                        {x = (k / max_line_number) * size.w - seperator_spacing, y = h}
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
                    x = math.ceil(num / max_line_number - 1) * size.w + seperator_spacing,
                    y = 0,
                    w = size.w + seperator_spacing,
                    h = size.h
                }
            }
        )
    end

    -- 居中显示
    canvas:frame({x = cooridnate_x - w / 2, y = cooridnate_y - h / 2, w = w, h = h})
end

-- 默认不显示
local show = false
local function toggleKeybindingsCheatsheet()
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
    toggleKeybindingsCheatsheet
)

return _M
