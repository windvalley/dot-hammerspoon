local _M = {}

_M.name = "auto_switch_input_method"
_M.description = "切换应用时自动切换输入法"

local auto_input_methods = require "keybindings_config".auto_input_methods
local input_method_lib = require "input_method_lib"

local show_switch_info = false

local function applicationWatcher(appName, eventType, appObject)
    local bundleID = appObject:bundleID()

    if eventType == hs.application.watcher.activated then
        local input_method = auto_input_methods[bundleID]

        if input_method ~= nil then
            input_method_lib.switch_input_method(input_method)

            if show_switch_info then
                hs.alert.show(input_method, 0.5)
            end

            print("[INFO] ", appName, "switched to", input_method)
        end
    end
end

appWatcher = hs.application.watcher.new(applicationWatcher)

appWatcher:start()

return _M
