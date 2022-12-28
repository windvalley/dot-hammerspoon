local _M = {}

_M.name = "auto_input_method"
_M.description = "切换应用时自动切换输入法"

local auto_input_methods = require "keybindings_config".auto_input_methods

local log = hs.logger.new("input")

local pop_msg = false

local function applicationWatcher(appName, eventType, appObject)
    local bundleID = appObject:bundleID()

    if eventType == hs.application.watcher.activated then
        local input_method = auto_input_methods[bundleID]

        if input_method ~= nil then
            hs.keycodes.currentSourceID(input_method)

            if pop_msg then
                hs.alert.show(input_method, 0.5)
            end

            log.d(string.format("app '%s' switched to '%s'", appName, input_method))
        end
    end
end

appWatcher = hs.application.watcher.new(applicationWatcher)

appWatcher:start()

return _M
