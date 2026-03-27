local _M = {}

_M.__index = _M

_M.name = "init"
_M.author = "XG <levinwang6@gmail.com>"
_M.license = "MIT"
_M.homepage = "https://github.com/windvalley/dot-hammerspoon"

local log = hs.logger.new("init")
local startup_notices = {}
local loaded_modules = {}
local loaded_module_order = {}

local module_specs = {
	{ name = "app_launch", description = "app快速启动或切换" },
	{ name = "window_manipulation", description = "app窗口操作" },
	{ name = "system_manage", description = "系统管理" },
	{ name = "keep_awake", description = "持续工作/防休眠" },
	{ name = "website_open", description = "网站快捷访问" },
	{ name = "clipboard_center", description = "剪贴板历史" },
	{ name = "selected_text_translate", description = "翻译当前选中的文本" },
	{ name = "manual_input_method", description = "切换到指定输入法" },
	{ name = "auto_input_method", description = "根据应用不同自动切换输入法" },
	{ name = "bing_daily_wallpaper", description = "同步 Bing Daily Picture 壁纸" },
	{ name = "break_reminder", description = "每隔一段时间强制休息" },
	{ name = "key_caster", description = "录屏/演示时显示按下的键" },
	{ name = "keybindings_cheatsheet", description = "显示快捷键备忘面板" },
	{ name = "auto_reload", description = "lua文件变动自动reload" },
}

local function push_startup_notice(level, message)
	table.insert(startup_notices, {
		level = level,
		message = message,
	})

	if level == "error" then
		log.e(message)
	elseif level == "warning" then
		log.w(message)
	else
		log.i(message)
	end
end

local function check_accessibility_permission()
	if type(hs.accessibilityState) ~= "function" then
		return nil
	end

	local ok, enabled = pcall(hs.accessibilityState, false)

	if ok ~= true then
		push_startup_notice("warning", "无法检查辅助功能权限，已继续加载配置")
		return nil
	end

	if enabled ~= true then
		push_startup_notice(
			"warning",
			"未授予 Hammerspoon 辅助功能权限，窗口操作、输入监听等模块可能无法正常工作"
		)
		return false
	end

	return true
end

local function invoke_module_hook(module_name, module, hook_name)
	if type(module) ~= "table" then
		return true
	end

	local hook = module[hook_name]
	local hook_result = nil

	if type(hook) ~= "function" then
		return true
	end

	local ok, err = xpcall(function()
		hook_result = hook(module)
	end, debug.traceback)

	if ok ~= true then
		push_startup_notice("error", string.format("模块 %s 的 %s() 执行失败，详见 Console", module_name, hook_name))
		log.e(err)
		return false
	end

	if hook_name == "start" and hook_result == false then
		push_startup_notice("warning", string.format("模块 %s 的 start() 返回 false，功能可能未正常启用", module_name))
		return false
	end

	if hook_name == "stop" and hook_result == false then
		log.w(string.format("模块 %s 的 stop() 返回 false", module_name))
		return false
	end

	return true
end

local function safe_require(spec)
	local module_label = spec.description or spec.name
	local ok, module_or_err = xpcall(function()
		return require(spec.name)
	end, debug.traceback)

	if ok ~= true then
		push_startup_notice("error", string.format("模块加载失败: %s (%s)，详见 Console", spec.name, module_label))
		log.e(module_or_err)
		return nil
	end

	loaded_modules[spec.name] = module_or_err
	table.insert(loaded_module_order, spec.name)
	invoke_module_hook(spec.name, module_or_err, "start")

	return module_or_err
end

local function stop_loaded_modules()
	for index = #loaded_module_order, 1, -1 do
		local module_name = loaded_module_order[index]
		local module = loaded_modules[module_name]
		invoke_module_hook(module_name, module, "stop")
	end
end

local function flush_startup_notices()
	local error_count = 0
	local warning_count = 0
	local first_warning = nil

	for _, notice in ipairs(startup_notices) do
		if notice.level == "error" then
			error_count = error_count + 1
		elseif notice.level == "warning" then
			warning_count = warning_count + 1

			if first_warning == nil then
				first_warning = notice.message
			end
		end
	end

	if error_count > 0 then
		hs.alert.show(string.format("Hammerspoon 启动时有 %d 个模块加载失败，请查看 Console", error_count), 4)
		return
	end

	if warning_count > 0 and first_warning ~= nil then
		hs.alert.show(first_warning, 4)
	end
end

local previous_shutdown_callback = hs.shutdownCallback

hs.shutdownCallback = function(...)
	local shutdown_args = { ... }

	stop_loaded_modules()

	if type(previous_shutdown_callback) == "function" then
		local ok, err = xpcall(function()
			previous_shutdown_callback(table.unpack(shutdown_args))
		end, debug.traceback)

		if ok ~= true then
			log.e(err)
		end
	end
end

-- Hammerspoon Preferences
hs.autoLaunch(true)
hs.automaticallyCheckForUpdates(false)
hs.consoleOnTop(false)
hs.dockIcon(false)
hs.menuIcon(true)
hs.uploadCrashData(false)

-- 每次按快捷键时显示快捷键alert消息持续的秒数, 0 为禁用.
hs.hotkey.alertDuration = 0

-- 窗口动画持续时间, 0为关闭动画效果.
hs.window.animationDuration = 0

-- Hammerspoon Console 上打印的日志级别.
-- 可选: verbose, debug, info, warning, error, nothing
-- 默认: warning
hs.logger.defaultLogLevel = "warning"

pcall(require, "hs.ipc")

check_accessibility_permission()

for _, spec in ipairs(module_specs) do
	safe_require(spec)
end

if #startup_notices > 0 then
	hs.timer.doAfter(0, function()
		flush_startup_notices()
	end)
end

return _M
