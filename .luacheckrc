-- $ luacheck .

std = {
    -- 忽略对以下自带的全部变量的检查
	    globals = {
	        "hs",
	        "spoon",
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
	        "error",
	        "debug",
	        "configWatcher",
	        "appWatcher"
	    }
	}

-- 忽略检查的错误类型.
ignore = {
    -- 忽略检查代码每行长度.
    "631"
}
