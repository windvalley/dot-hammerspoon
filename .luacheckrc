-- $ luacheck .

std = {
    -- 忽略对以下自带的全部变量的检查
    globals = {
        "hs",
        "spoon",
        "io",
        "math",
        "os",
        "require",
        "print",
        "pairs",
        "ipairs",
        "table",
        "next",
        "getmetatable",
        "setmetatable",
        "string",
        "tonumber",
        "tostring",
        "pcall",
        "assert",
        "type",
        "load",
        "error"
    }
}

-- 忽略检查的错误类型, 比如忽略检查每行长度:
-- ignore = {"631"}
ignore = {}
