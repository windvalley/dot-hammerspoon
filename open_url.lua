local _M = {}

_M.name = "open_url"
_M.version = "0.1.0"
_M.description = "快速打开目标网站"

local urls = require "keybindings_config".urls

hs.fnutils.each(
    urls,
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
