local _M = {}

_M.name = "bing_daily_wallpaper"
_M.description = "使用 Bing Daily Picture 作为屏幕壁纸"

local wallpaper = require("keybindings_config").bing_daily_wallpaper or {}
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local file_exists = utils_lib.file_exists
local ensure_directory = utils_lib.ensure_directory

local log = hs.logger.new("wallpaper")

local settings_key_last_picture_name = "bing_daily_wallpaper.last_picture_name"
local wallpaper_file_prefix = "bing_"
local default_user_agent =
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/603.2.4 (KHTML, like Gecko) Version/10.1.1 Safari/603.2.4"

local state = {
	started = false,
	timer = nil,
	task = nil,
	download_temp_path = nil,
	cache_dir = nil,
	last_picture_name = "",
	request_id = 0,
	request_inflight = false,
}

local function normalize_integer(value, fallback, minimum, maximum)
	local number = tonumber(value)

	if number == nil then
		number = fallback
	end

	number = math.floor(number)

	if minimum ~= nil then
		number = math.max(minimum, number)
	end

	if maximum ~= nil then
		number = math.min(maximum, number)
	end

	return number
end

local function normalize_url_base(value, fallback)
	local url = trim(tostring(value or fallback or ""))

	if url == "" then
		url = fallback or ""
	end

	return (url:gsub("/+$", ""))
end

local function resolve_cache_dir()
	local raw = trim(tostring(wallpaper.cache_dir or ""))
	local home = os.getenv("HOME") or ""

	if raw == "" then
		local bundle_id = trim(tostring(hs.settings.bundleID or ""))

		if bundle_id == "" then
			bundle_id = "org.hammerspoon.Hammerspoon"
		end

		return string.format("%s/Library/Caches/%s/bing_daily_wallpaper", home, bundle_id)
	end

	if raw:sub(1, 2) == "~/" then
		return home .. raw:sub(2)
	end

	if raw:sub(1, 1) == "/" then
		return raw
	end

	return hs.configdir .. "/" .. raw
end

local function load_last_picture_name()
	return trim(tostring(hs.settings.get(settings_key_last_picture_name) or ""))
end

local function persist_last_picture_name(name)
	name = trim(tostring(name or ""))

	if name == "" then
		hs.settings.clear(settings_key_last_picture_name)
		return
	end

	hs.settings.set(settings_key_last_picture_name, name)
end

local function refresh_interval_seconds()
	return normalize_integer(wallpaper.refresh_interval_seconds, 60 * 60, 60, 24 * 60 * 60)
end

local function picture_width()
	return normalize_integer(wallpaper.picture_width, 3072, 512, 8192)
end

local function picture_height()
	return normalize_integer(wallpaper.picture_height, 1920, 512, 8192)
end

local function history_count()
	return normalize_integer(wallpaper.history_count, 1, 1, 8)
end

local function metadata_base_url()
	return normalize_url_base(wallpaper.metadata_base_url, "https://cn.bing.com")
end

local function image_base_url()
	return normalize_url_base(wallpaper.image_base_url, "https://www.bing.com")
end

local function metadata_url()
	return string.format(
		"%s/HPImageArchive.aspx?format=js&idx=0&n=%d&pid=hp&uhd=1&uhdwidth=%d&uhdheight=%d",
		metadata_base_url(),
		history_count(),
		picture_width(),
		picture_height()
	)
end

local function relative_image_url(image)
	if type(image) ~= "table" then
		return nil
	end

	local url = trim(tostring(image.url or ""))

	if url == "" then
		return nil
	end

	return url
end

local function absolute_image_url(relative_url)
	if relative_url:match("^https?://") ~= nil then
		return relative_url
	end

	if relative_url:sub(1, 1) ~= "/" then
		relative_url = "/" .. relative_url
	end

	return image_base_url() .. relative_url
end

local function picture_name_from_url(relative_url)
	local identifier = relative_url:match("[?&]id=([^&]+)")

	if identifier ~= nil and trim(identifier) ~= "" then
		return wallpaper_file_prefix .. trim(identifier):gsub("[^%w%._%-]", "_")
	end

	local extension = relative_url:match("%.([A-Za-z0-9]+)")

	if extension ~= nil then
		extension = "." .. extension
	else
		extension = ".jpg"
	end

	return wallpaper_file_prefix .. hs.hash.SHA256(relative_url) .. extension
end

local function cleanup_cache(retained_names)
	if state.cache_dir == nil or retained_names == nil or type(hs.fs.dir) ~= "function" then
		return
	end

	for entry in hs.fs.dir(state.cache_dir) do
		if
			entry ~= "."
			and entry ~= ".."
			and entry:sub(1, #wallpaper_file_prefix) == wallpaper_file_prefix
			and retained_names[entry] ~= true
		then
			local full_path = state.cache_dir .. "/" .. entry
			local attributes = hs.fs.attributes(full_path)

			if attributes ~= nil and attributes.mode == "file" then
				local ok, err = os.remove(full_path)

				if ok ~= true then
					log.w(string.format("failed to remove cached wallpaper: %s (%s)", full_path, tostring(err)))
				end
			end
		end
	end
end

local function apply_wallpaper(local_path, picture_name)
	if file_exists(local_path) ~= true then
		log.e("wallpaper file does not exist: " .. tostring(local_path))
		return false
	end

	local file_url = "file://" .. local_path
	local applied = false

	for _, screen in ipairs(hs.screen.allScreens()) do
		local ok, err = pcall(function()
			screen:desktopImageURL(file_url)
		end)

		if ok ~= true then
			log.e(string.format("failed to set wallpaper for %s: %s", tostring(screen), tostring(err)))
		else
			applied = true
		end
	end

	if applied == true then
		state.last_picture_name = picture_name
		persist_last_picture_name(picture_name)
		log.i("wallpaper updated: " .. picture_name)
	end

	return applied
end

local function stop_download_task()
	if state.task == nil then
		return
	end

	local task = state.task

	state.task = nil
	local temp_path = state.download_temp_path
	state.download_temp_path = nil
	task:terminate()

	if temp_path ~= nil and temp_path ~= "" then
		local ok, err = os.remove(temp_path)

		if ok ~= true and file_exists(temp_path) == true then
			log.w(string.format("failed to remove partial wallpaper download: %s (%s)", temp_path, tostring(err)))
		end
	end
end

local function download_picture(full_url, local_path, picture_name, retained_names)
	stop_download_task()

	local task
	local temp_path = local_path .. ".part"
	local _, remove_err = os.remove(temp_path)

	if file_exists(temp_path) == true then
		log.w(string.format("failed to clear stale partial wallpaper download: %s (%s)", temp_path, tostring(remove_err)))
	end

	task = hs.task.new("/usr/bin/curl", function(exit_code, _, std_err)
		if state.task ~= task then
			os.remove(temp_path)
			return
		end

		state.task = nil
		state.download_temp_path = nil

		if exit_code ~= 0 then
			os.remove(temp_path)
			log.e(string.format("failed to download Bing wallpaper: %s (%s)", picture_name, trim(std_err)))
			return
		end

		local renamed, rename_err = os.rename(temp_path, local_path)

		if renamed ~= true then
			os.remove(temp_path)
			log.e(string.format("failed to finalize Bing wallpaper download: %s (%s)", picture_name, tostring(rename_err)))
			return
		end

		if apply_wallpaper(local_path, picture_name) == true then
			cleanup_cache(retained_names)
		end
	end, {
		"--fail",
		"--location",
		"--silent",
		"--show-error",
		"-A",
		default_user_agent,
		full_url,
		"-o",
		temp_path,
	})

	if task == nil then
		log.e("failed to create wallpaper download task")
		return false
	end

	state.task = task
	state.download_temp_path = temp_path

	if task:start() == false then
		state.task = nil
		state.download_temp_path = nil
		os.remove(temp_path)
		log.e("failed to start wallpaper download task")
		return false
	end

	return true
end

local function pick_image(images)
	if #images == 1 then
		return images[1]
	end

	return images[math.random(1, #images)]
end

local function build_retained_names(images)
	local retained = {}

	for _, image in ipairs(images) do
		local relative_url = relative_image_url(image)

		if relative_url ~= nil then
			retained[picture_name_from_url(relative_url)] = true
		end
	end

	return retained
end

local function refresh_now(reason)
	if wallpaper.enabled == false then
		return false
	end

	if state.request_inflight == true then
		log.d("skip wallpaper refresh because a previous metadata request is still running")
		return false
	end

	if state.cache_dir == nil then
		state.cache_dir = resolve_cache_dir()
	end

	if ensure_directory(state.cache_dir) ~= true then
		return false
	end

	state.request_id = state.request_id + 1
	state.request_inflight = true

	local request_id = state.request_id
	local url = metadata_url()

	hs.http.asyncGet(url, { ["User-Agent"] = default_user_agent }, function(status, body, _)
		if request_id ~= state.request_id then
			return
		end

		state.request_inflight = false

		if status ~= 200 then
			log.e(string.format("failed to request Bing wallpaper metadata: status=%s, reason=%s", tostring(status), tostring(reason)))
			return
		end

		local ok, payload = pcall(hs.json.decode, body)

		if ok ~= true or type(payload) ~= "table" then
			log.e("failed to decode Bing wallpaper metadata response")
			return
		end

		local images = payload.images

		if type(images) ~= "table" or #images == 0 then
			log.e("Bing wallpaper metadata response does not contain any image")
			return
		end

		local selected = pick_image(images)
		local relative_url = relative_image_url(selected)

		if relative_url == nil then
			log.e("selected Bing wallpaper item does not contain a valid image url")
			return
		end

		local picture_name = picture_name_from_url(relative_url)
		local local_path = state.cache_dir .. "/" .. picture_name
		local retained_names = build_retained_names(images)

		if file_exists(local_path) == true then
			apply_wallpaper(local_path, picture_name)
			cleanup_cache(retained_names)
			return
		end

		if download_picture(absolute_image_url(relative_url), local_path, picture_name, retained_names) ~= true then
			log.e("failed to refresh wallpaper: " .. picture_name)
			return
		end

		log.i(string.format("wallpaper refresh scheduled (%s): %s", tostring(reason or "unknown"), picture_name))
	end)

	return true
end

function _M.start()
	if wallpaper.enabled == false then
		log.i("bing daily wallpaper disabled by config")
		return true
	end

	if state.started == true then
		return true
	end

	state.started = true
	state.cache_dir = resolve_cache_dir()
	state.last_picture_name = load_last_picture_name()

	if ensure_directory(state.cache_dir) ~= true then
		state.started = false
		return false
	end

	refresh_now("startup")

	state.timer = hs.timer.doEvery(refresh_interval_seconds(), function()
		refresh_now("scheduled refresh")
	end)

	return true
end

function _M.stop()
	state.started = false
	state.request_id = state.request_id + 1
	state.request_inflight = false

	if state.timer ~= nil then
		state.timer:stop()
		state.timer = nil
	end

	stop_download_task()

	return true
end

function _M.refresh_now()
	if state.started ~= true then
		return _M.start()
	end

	return refresh_now("manual refresh")
end

_M.current_cache_dir = function()
	if state.cache_dir == nil then
		state.cache_dir = resolve_cache_dir()
	end

	return state.cache_dir
end

return _M
