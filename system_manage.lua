local _M = {}

_M.name = "system_manage"
_M.description = "系统管理, 比如: 锁屏, 启动屏保, 重启等"

local system = require("keybindings_config").system
local hotkey_helper = require("hotkey_helper")

local log = hs.logger.new("system")
local state = {
	started = false,
	bindings = {},
	binding_failures = 0,
}

local function bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
	local binding = hotkey_helper.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, { logger = log })

	if binding ~= nil then
		table.insert(state.bindings, binding)
	else
		state.binding_failures = state.binding_failures + 1
	end

	return binding
end

local function clearBindings()
	for _, binding in ipairs(state.bindings) do
		binding:delete()
	end

	state.bindings = {}
end

function _M.start()
	if state.started == true then
		return true
	end

	state.started = true
	state.binding_failures = 0

	-- 锁屏.
	bind(system.lock_screen.prefix, system.lock_screen.key, system.lock_screen.message, function()
		log.d("lock screen")
		hs.caffeinate.lockScreen()
	end)

	-- 启动屏保.
	bind(system.screen_saver.prefix, system.screen_saver.key, system.screen_saver.message, function()
		log.d("start screensaver")
		hs.caffeinate.startScreensaver()
	end)

	-- 重启.
	bind(system.restart.prefix, system.restart.key, system.restart.message, function()
		local button =
			hs.dialog.blockAlert("确认重启", "确定要重启电脑吗？未保存的工作可能会丢失。", "重启", "取消")
		if button == "重启" then
			log.i("restart system confirmed")
			hs.caffeinate.restartSystem()
		end
	end)

	-- 关机.
	bind(system.shutdown.prefix, system.shutdown.key, system.shutdown.message, function()
		local button =
			hs.dialog.blockAlert("确认关机", "确定要关闭电脑吗？未保存的工作可能会丢失。", "关机", "取消")
		if button == "关机" then
			log.i("shutdown system confirmed")
			hs.caffeinate.shutdownSystem()
		end
	end)

	return state.binding_failures == 0
end

function _M.stop()
	clearBindings()
	state.binding_failures = 0
	state.started = false

	return true
end

return _M
