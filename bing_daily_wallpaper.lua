local _M = {}

_M.name = "bing_daily_wallpaper"
_M.version = "0.1.0"
_M.description = "使用Bing Daily Picture作为屏幕壁纸"

-- 每隔多少秒触发一次bing请求进行壁纸更新:
--   2分钟: 2 * 60
--   2小时: 2 * 60 * 60
local do_every_seconds = 1 * 60 * 60

-- 最好根据自己的电脑屏幕分辨率设置.
local pic_width, pic_height = 3072, 1920

-- 获取Bing最近多少天的壁纸列表(每天有一张壁纸图片):
--   设置成1, 代表壁纸保持和Bing当天的壁纸一样;
--   设置成大于1, 则每次触发更新壁纸, 会随机从中选择一张壁纸图片.
local pic_count = 1

local pic_save_path = os.getenv("HOME") .. "/.Trash/"

-- 获取图片url json列表的接口.
local bing_pictures_url =
    "https://cn.bing.com/HPImageArchive.aspx?format=js&idx=0&n=" ..
    pic_count .. "&nc=1612409408851&pid=hp&FORM=BEHPTB&uhd=1&uhdwidth=" .. pic_width .. "&uhdheight=" .. pic_height

local user_agent_str =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/603.2.4 (KHTML, like Gecko) Version/10.1.1 Safari/603.2.4"

local function curl_callback(exitCode, stdOut, stdErr)
    if exitCode == 0 then
        _M.task = nil
        _M.last_pic = hs.http.urlParts(_M.full_url).query

        local localpath = pic_save_path .. hs.http.urlParts(_M.full_url).query

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
    hs.http.asyncGet(
        bing_pictures_url,
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
                    local image_urls = decode_data.images
                    local pic_url = image_urls[math.random(1, #image_urls)].url
                    local pic_name = hs.http.urlParts(pic_url).query

                    -- 只有在本次和上次获取的图片不同时才去设置屏幕壁纸.
                    if _M.last_pic ~= pic_name then
                        _M.full_url = "https://www.bing.com" .. pic_url

                        if _M.task then
                            _M.task:terminate()
                            _M.task = nil
                        end

                        local localpath = pic_save_path .. hs.http.urlParts(_M.full_url).query

                        -- 这里真正触发下载壁纸图片.
                        _M.task =
                            hs.task.new(
                            "/usr/bin/curl",
                            curl_callback,
                            {"-A", user_agent_str, _M.full_url, "-o", localpath}
                        )

                        _M.task:start()

                        print("[INFO] wallpaper changed, current picture: ", pic_name, " last picture: ", _M.last_pic)
                    else
                        print("[INFO] current picture is same as last picture: ", pic_name)
                    end
                end
            else
                print("[ERROR] Bing URL request failed!")
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
else
    _M.timer:start()
end

return _M
