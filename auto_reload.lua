local _M = {}

_M.name = "auto_reload"
_M.version = "0.1.0"
_M.description = "lua文件变动自动reload, 使实时生效"

local hammerspoon_path = os.getenv("HOME") .. "/.hammerspoon/"

local function reload(files)
    local doReload = false
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end

    if doReload then
        hs.console.clearConsole()
        hs.reload()
    end
end

hs.pathwatcher.new(hammerspoon_path, reload):start()

hs.alert.show("hammerspoon reloaded")

return _M
