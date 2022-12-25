local _M = {}

_M.name = "open_url"
_M.version = "0.1.0"
_M.description = "快速打开目标网站"

local urls = require "keybindings_config".urls

hs.hotkey.bind(
    urls.github.prefix,
    urls.github.key,
    urls.github.message,
    function()
        hs.urlevent.openURL("https://github.com/windvalley")
    end
)

hs.hotkey.bind(
    urls.google.prefix,
    urls.google.key,
    urls.google.message,
    function()
        hs.urlevent.openURL("https://www.google.com")
    end
)

hs.hotkey.bind(
    urls.bing.prefix,
    urls.bing.key,
    urls.bing.message,
    function()
        hs.urlevent.openURL("https://www.bing.com")
    end
)

return _M
