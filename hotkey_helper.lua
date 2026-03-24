local _M = {}

_M.name = "hotkey_helper"
_M.description = "统一管理快捷键绑定与冲突日志"

local default_log = hs.logger.new("hotkey")

local modifier_symbols = {
	ctrl = "⌃",
	control = "⌃",
	["⌃"] = "⌃",
	alt = "⌥",
	option = "⌥",
	opt = "⌥",
	["⌥"] = "⌥",
	cmd = "⌘",
	command = "⌘",
	["⌘"] = "⌘",
	shift = "⇧",
	["⇧"] = "⇧",
	fn = "fn",
	["function"] = "fn",
}

local function format_hotkey(modifiers, key)
	local parts = {}

	for _, modifier in ipairs(modifiers or {}) do
		local symbol = modifier_symbols[string.lower(tostring(modifier))] or tostring(modifier)
		table.insert(parts, symbol)
	end

	table.insert(parts, string.upper(tostring(key or "")))

	return table.concat(parts, " ")
end

local function system_assigned_description(details)
	if type(details) ~= "table" then
		return "unknown"
	end

	local parts = {}

	if details.source ~= nil then
		table.insert(parts, tostring(details.source))
	end

	if details.enabled ~= nil then
		table.insert(parts, details.enabled == true and "enabled" or "disabled")
	end

	if #parts == 0 then
		return "unknown"
	end

	return table.concat(parts, ", ")
end

function _M.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn, options)
	options = options or {}

	local log = options.logger or default_log
	local hotkey_label = format_hotkey(modifiers, key)

	if type(hs.hotkey.systemAssigned) == "function" then
		local ok, system_assigned = pcall(hs.hotkey.systemAssigned, modifiers, key)

		if ok == true and system_assigned ~= false and system_assigned ~= nil then
			log.w(
				string.format(
					"hotkey may conflict with macOS shortcut: %s (%s)",
					hotkey_label,
					system_assigned_description(system_assigned)
				)
			)
		end
	end

	if type(hs.hotkey.assignable) == "function" then
		local ok, assignable = pcall(hs.hotkey.assignable, modifiers, key)

		if ok == true and assignable == false then
			log.w("hotkey is not assignable: " .. hotkey_label)
		end
	end

	local ok, binding_or_error = pcall(
		function()
			return hs.hotkey.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
		end
	)

	if ok ~= true or binding_or_error == nil then
		if binding_or_error ~= nil then
			log.e("failed to bind hotkey: " .. hotkey_label .. " (" .. tostring(binding_or_error) .. ")")
		else
			log.e("failed to bind hotkey: " .. hotkey_label)
		end

		return nil, binding_or_error
	end

	return binding_or_error
end

return _M
