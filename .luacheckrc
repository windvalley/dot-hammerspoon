-- $ luacheck .

lua_version = "54"

std = {
    globals = {
        "hs",
        "spoon",
        "configWatcher",
        "appWatcher",
    },
    read_globals = {
        "io",
        "math",
        "os",
        "package",
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
        "xpcall",
        "assert",
        "type",
        "select",
        "load",
        "loadfile",
        "error",
        "debug",
        "rawget",
        "rawset",
    },
}

-- 忽略检查的错误类型.
ignore = {
    -- 忽略检查代码每行长度.
    "631"
}
