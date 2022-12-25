local _M = {}

_M.name = "website_open"
_M.version = "0.1.0"
_M.description = "快速打开目标网站"

local websites = require "keybindings_config".websites

hs.fnutils.each(
    websites,
    function(item)
        hs.hotkey.bind(
            item.prefix,
            item.key,
            item.message,
            function()
                hs.urlevent.openURL(item.target)
            end
        )
    end
)

return _M
