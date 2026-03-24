local _M = {}

_M.name = "website_open"
_M.description = "快速打开目标网站"

local websites = require "keybindings_config".websites
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("website")

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
    return hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })
end

hs.fnutils.each(
    websites,
    function(item)
        bind(
            item.prefix,
            item.key,
            item.message,
            function()
                log.d(string.format("open website: %s", item.target))
                hs.urlevent.openURL(item.target)
            end
        )
    end
)

return _M
