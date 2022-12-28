local _M = {}

_M.name = "website_open"
_M.description = "快速打开目标网站"

local websites = require "keybindings_config".websites

local log = hs.logger.new("website")

hs.fnutils.each(
    websites,
    function(item)
        hs.hotkey.bind(
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
