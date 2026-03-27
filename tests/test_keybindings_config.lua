local _M = {}
local loaded_modules = rawget(package, "loaded")

local function assert_equal(actual, expected, message)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", message or "assert_equal failed", tostring(expected), tostring(actual)))
	end
end

local function assert_true(value, message)
	if value ~= true then
		error(message or "expected true")
	end
end

local function reset_modules()
	loaded_modules["keybindings_config"] = nil
end

function _M.run()
	reset_modules()

	local config = require("keybindings_config")
	local break_reminder = config.break_reminder or {}
	local key_caster = config.key_caster or {}
	local selected_text_translate = config.selected_text_translate or {}

	assert_equal(break_reminder.mode, "soft", "default break reminder mode should remain soft")
	assert_equal(break_reminder.overlay_opacity, 0.32, "soft mode default opacity should stay translucent")
	assert_equal(break_reminder.start_next_cycle, "on_input", "default next cycle mode should wait for input")
	assert_equal(break_reminder.menubar_skin, "hourglass", "default menubar skin should match documented example")
	assert_equal(key_caster.enabled, false, "key caster should stay disabled by default")
	assert_true(
		key_caster.show_menubar == true
			or key_caster.show_menubar == false
			or key_caster.show_menubar == "auto"
			or key_caster.show_menubar == "always"
			or key_caster.show_menubar == "never",
		"key caster show_menubar should use a supported mode"
	)
	assert_true(type(key_caster.position) == "table", "key caster position should be configurable")
	assert_equal(key_caster.position.anchor, "bottom_center", "key caster default anchor should fit recording scenarios")
	assert_true(type(key_caster.toggle_hotkey) == "table", "key caster should expose a toggle_hotkey table")
	assert_equal(key_caster.toggle_hotkey.key, "K", "key caster should expose a default toggle hotkey")
	assert_true(key_caster.display_mode == "single" or key_caster.display_mode == "sequence", "key caster display_mode should use a supported mode")
	assert_true(
		type(key_caster.sequence_window_seconds) == "number" and key_caster.sequence_window_seconds >= 0.05,
		"key caster sequence window should stay configurable with a sensible lower bound"
	)
	assert_equal(selected_text_translate.enabled, true, "selected_text_translate should stay enabled by default")
	assert_equal(selected_text_translate.key, "R", "selected_text_translate should expose a default hotkey")
	assert_equal(
		selected_text_translate.target_language,
		"简体中文",
		"selected_text_translate should default to translating into Simplified Chinese"
	)
	assert_equal(
		selected_text_translate.model_service.provider,
		"ollama",
		"selected_text_translate should default to the local Ollama provider"
	)
	assert_equal(
		selected_text_translate.model_service.ollama.disable_thinking,
		true,
		"selected_text_translate should disable thinking by default for Ollama"
	)
	assert_equal(
		selected_text_translate.model_service.openai_compatible.api_key_env,
		"OPENAI_API_KEY",
		"selected_text_translate should expose the default OpenAI-compatible API key env name"
	)

	reset_modules()
end

return _M
