local _M = {}

_M.name = "auto_input_method"
_M.description = "切换应用时自动切换输入法"

local auto_input_methods = require "keybindings_config".auto_input_methods

local log = hs.logger.new("input")
local started = false
local pop_msg = false

local function applicationWatcher(appName, eventType, appObject)
    if eventType ~= hs.application.watcher.activated then
        return
    end

    if appObject == nil then
        log.d("skip input method switch because appObject is nil")
        return
    end

    local bundleID = appObject:bundleID()

    if bundleID == nil then
        log.d(string.format("skip input method switch because bundleID is nil for '%s'", tostring(appName)))
        return
    end

    local input_method = auto_input_methods[bundleID]

    if input_method ~= nil then
        hs.keycodes.currentSourceID(input_method)

        if pop_msg then
            hs.alert.show(input_method, 0.5)
        end

        log.d(string.format("app '%s' switched to '%s'", tostring(appName or bundleID), input_method))
    end
end

function _M.start()
    if started == true then
        return true
    end

    if _M.watcher == nil then
        _M.watcher = hs.application.watcher.new(applicationWatcher)
    end

    _M.watcher:start()
    started = true

    return true
end

function _M.stop()
    if _M.watcher ~= nil then
        _M.watcher:stop()
    end

    started = false

    return true
end

return _M
