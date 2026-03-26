local _M = {}

_M.name = "input_method_helper"
_M.description = "统一切换输入法、布局与常见别名"

local alias_candidates = {
	["com.tencent.inputmethod.wetype"] = {
		{ kind = "method", value = "微信输入法" },
	},
	["com.apple.keylayout.ABC"] = {
		{ kind = "layout", value = "ABC" },
	},
}

local function add_candidate(candidates, seen, kind, value)
	local normalized_kind = tostring(kind or "")
	local normalized_value = tostring(value or "")

	if normalized_kind == "" or normalized_value == "" then
		return
	end

	local candidate_key = normalized_kind .. ":" .. normalized_value

	if seen[candidate_key] == true then
		return
	end

	seen[candidate_key] = true
	table.insert(candidates, {
		kind = normalized_kind,
		value = normalized_value,
	})
end

local function build_candidates(target)
	local normalized_target = tostring(target or "")
	local candidates = {}
	local seen = {}
	local source_id_like = normalized_target:find(".", 1, true) ~= nil

	add_candidate(candidates, seen, "source_id", normalized_target)

	if source_id_like ~= true then
		add_candidate(candidates, seen, "layout", normalized_target)
		add_candidate(candidates, seen, "method", normalized_target)
	end

	for _, candidate in ipairs(alias_candidates[normalized_target] or {}) do
		add_candidate(candidates, seen, candidate.kind, candidate.value)
	end

	return candidates
end

local function try_switch_candidate(candidate)
	if type(hs) ~= "table" or type(hs.keycodes) ~= "table" then
		return false
	end

	if candidate.kind == "source_id" and type(hs.keycodes.currentSourceID) == "function" then
		return hs.keycodes.currentSourceID(candidate.value) == true
	end

	if candidate.kind == "layout" and type(hs.keycodes.setLayout) == "function" then
		return hs.keycodes.setLayout(candidate.value) == true
	end

	if candidate.kind == "method" and type(hs.keycodes.setMethod) == "function" then
		return hs.keycodes.setMethod(candidate.value) == true
	end

	return false
end

function _M.switch(target)
	for _, candidate in ipairs(build_candidates(target)) do
		local ok, switched = pcall(try_switch_candidate, candidate)

		if ok == true and switched == true then
			return true, candidate
		end
	end

	return false, nil
end

return _M
