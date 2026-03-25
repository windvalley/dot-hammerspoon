local _M = {}

_M.name = "utils_lib"
_M.description = "通用函数工具库"

local log = hs.logger.new("utils")

local charsize = function(ch)
    if not ch then
        return 0
    elseif ch >= 252 then
        return 6
    elseif ch >= 248 and ch < 252 then
        return 5
    elseif ch >= 240 and ch < 248 then
        return 4
    elseif ch >= 224 and ch < 240 then
        return 3
    elseif ch >= 192 and ch < 224 then
        return 2
    elseif ch < 192 then
        return 1
    end
end

_M.utf8len = function(str)
    local len = 0
    local aNum = 0 -- 字母个数
    local hNum = 0 -- 汉字个数
    local currentIndex = 1

    while currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        local cs = charsize(char)

        currentIndex = currentIndex + cs
        len = len + 1
        if cs == 1 then
            aNum = aNum + 1
        elseif cs >= 2 then
            hNum = hNum + 1
        end
    end

    return len, aNum, hNum
end

_M.utf8sub = function(str, startChar, numChars)
    local startIndex = 1
    while startChar > 1 do
        local char = string.byte(str, startIndex)
        startIndex = startIndex + charsize(char)
        startChar = startChar - 1
    end

    local currentIndex = startIndex

    while numChars > 0 and currentIndex <= #str do
        local char = string.byte(str, currentIndex)
        currentIndex = currentIndex + charsize(char)
        numChars = numChars - 1
    end

    return str:sub(startIndex, currentIndex - 1)
end

_M.split = function(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if delimiter == "" then
        return false
    end

    local pos, arr = 0, {}
    -- for each divider found
    for st, sp in function()
        return string.find(input, delimiter, pos, true)
    end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end

    table.insert(arr, string.sub(input, pos))

    return arr
end

_M.trim = function(s)
    if s == nil then
        return ""
    end

    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 浅拷贝表
_M.shallow_copy = function(table_value)
    local copy = {}

    for key, value in pairs(table_value or {}) do
        copy[key] = value
    end

    return copy
end

-- 拷贝数组
_M.copy_list = function(items)
    local copied = {}

    for _, item in ipairs(items or {}) do
        table.insert(copied, item)
    end

    return copied
end

-- 检查文件是否存在
_M.file_exists = function(path)
    return type(path) == "string" and path ~= "" and hs.fs.attributes(path) ~= nil
end

-- 递归创建目录
_M.ensure_directory = function(path)
    if type(path) ~= "string" or path == "" then
        return false
    end

    if hs.fs.attributes(path) ~= nil then
        return true
    end

    local parent = string.match(path, "^(.*)/[^/]+/?$")

    if parent ~= nil and parent ~= "" and parent ~= path then
        if _M.ensure_directory(parent) ~= true then
            return false
        end
    end

    local ok, err = hs.fs.mkdir(path)

    if ok == true or hs.fs.attributes(path) ~= nil then
        return true
    end

    log.e(string.format("failed to create directory: %s (%s)", path, tostring(err)))

    return false
end

-- 展开 ~/ 为 HOME 目录
_M.expand_home_path = function(path)
    if type(path) ~= "string" or path == "" then
        return path
    end

    if path == "~" then
        return os.getenv("HOME") or path
    end

    if string.sub(path, 1, 2) == "~/" then
        local home = os.getenv("HOME")

        if type(home) == "string" and home ~= "" then
            return home .. string.sub(path, 2)
        end
    end

    return path
end

-- 通用文本输入对话框
_M.prompt_text = function(message, informative_text, default_value)
    local button, value = hs.dialog.textPrompt(
        message,
        informative_text,
        default_value or "",
        "保存",
        "取消",
        false
    )

    if button ~= "保存" then
        return nil
    end

    return value
end

return _M
