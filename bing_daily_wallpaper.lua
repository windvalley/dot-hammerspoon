local _M = {}

_M.name = "bing_daily_wallpaper"
_M.version = "0.1.0"
_M.description = "使用Bing Daily Picture作为屏幕壁纸"

-- 每隔多少秒触发一次bing请求进行壁纸更新.
local do_every_seconds = 1 * 60 * 60

local function curl_callback(exitCode, stdOut, stdErr)
    if exitCode == 0 then
        _M.task = nil
        _M.last_pic = hs.http.urlParts(_M.full_url).lastPathComponent

        local localpath = os.getenv("HOME") .. "/.Trash/" .. hs.http.urlParts(_M.full_url).lastPathComponent

        -- 为每个显示器都设置壁纸(注意不是macOS新建的其他桌面, 而是扩展显示器)
        local screens = hs.screen.allScreens()
        for _, screen in ipairs(screens) do
            print("[INFO] set wallpaper for ", screen)
            screen:desktopImageURL("file://" .. localpath)
        end
    else
        print(stdOut, stdErr)
    end
end

local function bing_request()
    local user_agent_str =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/603.2.4 (KHTML, like Gecko) Version/10.1.1 Safari/603.2.4"
    local json_req_url = "http://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1"

    hs.http.asyncGet(
        json_req_url,
        {["User-Agent"] = user_agent_str},
        function(stat, body, _)
            if stat == 200 then
                if
                    pcall(
                        function()
                            hs.json.decode(body)
                        end
                    )
                 then
                    local decode_data = hs.json.decode(body)
                    local pic_url = decode_data.images[1].url
                    local pic_name = hs.http.urlParts(pic_url).lastPathComponent

                    -- 只有在本次和上次获取的图片不同时才去设置屏幕壁纸.
                    if _M.last_pic ~= pic_name then
                        _M.full_url = "https://www.bing.com" .. pic_url
                        if _M.task then
                            _M.task:terminate()
                            _M.task = nil
                        end

                        local localpath =
                            os.getenv("HOME") .. "/.Trash/" .. hs.http.urlParts(_M.full_url).lastPathComponent
                        _M.task =
                            hs.task.new(
                            "/usr/bin/curl",
                            curl_callback,
                            {"-A", user_agent_str, _M.full_url, "-o", localpath}
                        )

                        _M.task:start()
                    end
                end
            else
                print("Bing URL request failed!")
            end
        end
    )
end

-- 每次reload配置都触发更新.
bing_request()

-- 定期自动更新.
if _M.timer == nil then
    _M.timer =
        hs.timer.doEvery(
        do_every_seconds,
        function()
            bing_request()
        end
    )

    _M.timer:setNextTrigger(5)
else
    _M.timer:start()
end

return _M
