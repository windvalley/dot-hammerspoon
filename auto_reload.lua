local _M = {}

_M.name = "auto_reload"
_M.description = "lua文件变动自动reload, 使实时生效"

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

configWatcher = hs.pathwatcher.new(hs.configdir, reload)

configWatcher:start()

hs.alert.show("hammerspoon reloaded")

return _M
