local _M = {}

_M.name = "hotkey_helper"
_M.description = "统一管理快捷键绑定与冲突日志"

local trim = require("utils_lib").trim

local default_log = hs.logger.new("hotkey")

_M.modifier_aliases = {
	ctrl = "ctrl",
	control = "ctrl",
	["⌃"] = "ctrl",
	alt = "alt",
	option = "alt",
	opt = "alt",
	["⌥"] = "alt",
	cmd = "cmd",
	command = "cmd",
	["⌘"] = "cmd",
	shift = "shift",
	["⇧"] = "shift",
	fn = "fn",
	["function"] = "fn",
}

_M.modifier_order = {
	ctrl = 1,
	alt = 2,
	cmd = 3,
	shift = 4,
	fn = 5,
}

_M.modifier_symbols = {
	ctrl = "⌃",
	alt = "⌥",
	cmd = "⌘",
	shift = "⇧",
	fn = "fn",
}

_M.modifier_prompt_names = {
	ctrl = "ctrl",
	alt = "option",
	cmd = "command",
	shift = "shift",
	fn = "fn",
}

function _M.format_hotkey(modifiers, key)
	local parts = {}

	for _, modifier in ipairs(modifiers or {}) do
		local symbol = _M.modifier_symbols[string.lower(tostring(modifier))] or tostring(modifier)
		table.insert(parts, symbol)
	end

	table.insert(parts, string.upper(tostring(key or "")))

	return table.concat(parts, " ")
end

function _M.normalize_hotkey_modifiers(raw_modifiers)
	local normalized = {}
	local seen = {}
	local values = {}

	if raw_modifiers == nil then
		return normalized
	end

	if type(raw_modifiers) == "table" then
		values = raw_modifiers
	else
		local text = tostring(raw_modifiers)
		text = text:gsub("，", ",")
		text = text:gsub("＋", "+")

		for token in string.gmatch(text, "[^,%+%s]+") do
			table.insert(values, token)
		end
	end

	for _, raw_value in ipairs(values) do
		local token = string.lower(trim(tostring(raw_value)))

		if token ~= "" then
			local modifier = _M.modifier_aliases[token]

			if modifier == nil then
				return nil, raw_value
			end

			if seen[modifier] ~= true then
				seen[modifier] = true
				table.insert(normalized, modifier)
			end
		end
	end

	table.sort(normalized, function(left, right)
		return _M.modifier_order[left] < _M.modifier_order[right]
	end)

	return normalized
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
	local hotkey_label = _M.format_hotkey(modifiers, key)

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

	local ok, binding_or_error = pcall(function()
		if message == nil then
			return hs.hotkey.bind(modifiers, key, pressedfn, releasedfn, repeatfn)
		end

		return hs.hotkey.bind(modifiers, key, message, pressedfn, releasedfn, repeatfn)
	end)

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
