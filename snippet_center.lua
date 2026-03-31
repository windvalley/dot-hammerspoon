local _M = {}

_M.name = "snippet_center"
_M.description = "文本片段管理"

local snippets = require("keybindings_config").snippets or {}
local hotkey_helper = require("hotkey_helper")
local utils_lib = require("utils_lib")
local trim = utils_lib.trim
local utf8len = utils_lib.utf8len
local utf8sub = utils_lib.utf8sub
local copy_list = utils_lib.copy_list
local prompt_text = utils_lib.prompt_text
local file_exists = utils_lib.file_exists
local ensure_directory = utils_lib.ensure_directory
local expand_home_path = utils_lib.expand_home_path
local normalize_hotkey_modifiers = hotkey_helper.normalize_hotkey_modifiers
local format_hotkey = hotkey_helper.format_hotkey
local modifier_prompt_names = hotkey_helper.modifier_prompt_names

local log = hs.logger.new("snippet")

local auto_paste_settings_key = "snippet_center.auto_paste"
local open_hotkey_modifiers_settings_key = "snippet_center.hotkey.open.modifiers"
local open_hotkey_key_settings_key = "snippet_center.hotkey.open.key"
local quick_save_hotkey_modifiers_settings_key = "snippet_center.hotkey.quick_save.modifiers"
local quick_save_hotkey_key_settings_key = "snippet_center.hotkey.quick_save.key"
local storage_file_version = 1
local default_max_items = math.max(10, math.floor(tonumber(snippets.max_items) or 200))
local default_max_content_length = math.max(200, math.floor(tonumber(snippets.max_content_length) or 20000))
local default_chooser_rows = math.max(6, math.floor(tonumber(snippets.chooser_rows) or 12))
local default_chooser_width = math.max(20, math.floor(tonumber(snippets.chooser_width) or 40))
local default_auto_paste = snippets.auto_paste ~= false
local default_restore_clipboard_after_paste = snippets.restore_clipboard_after_paste ~= false
local default_auto_title_length = math.max(12, math.floor(tonumber(snippets.auto_title_length) or 36))
local default_editor_width = math.max(420, math.floor(tonumber((snippets.editor or {}).width) or 620))
local default_editor_height = math.max(300, math.floor(tonumber((snippets.editor or {}).height) or 480))
local default_preview_enabled = snippets.preview_enabled ~= false
local default_preview_width = math.max(280, math.floor(tonumber(snippets.preview_width) or 420))
local default_preview_height = math.max(220, math.floor(tonumber(snippets.preview_height) or 320))
local default_preview_poll_interval = math.max(0.05, tonumber(snippets.preview_poll_interval) or 0.08)
local preview_body_max_chars = math.max(1000, math.floor(tonumber(snippets.preview_body_max_chars) or 6000))
local default_show_menubar = snippets.show_menubar == true
local default_menu_items = math.max(1, math.floor(tonumber(snippets.menu_items) or 8))
local auto_paste_delay_seconds = 0.12
local clipboard_restore_delay_seconds = 0.35
local history_suspend_seconds = 2
local detail_preview_length = 72
local title_preview_length = 40
local menu_title_preview_length = 24
local chooser_window_chrome_height = 94
local chooser_row_height = 42
local default_preview_gap = 24
local default_preview_margin = 28
local editor_port_name = "snippetEditor"
local menubar_title = "Snip"
local menubar_autosave_name = "dot-hammerspoon.snippet_center"
local default_storage_path = expand_home_path(trim(tostring(snippets.storage_path or "~/.hammerspoon/data/snippets.json")))
local default_open_hotkey_modifiers
local default_open_hotkey_key
local default_quick_save_hotkey_modifiers
local default_quick_save_hotkey_key
local open_hotkey_message = snippets.message or "Snippet Center"
local quick_save_hotkey_message = (snippets.quick_save or {}).message or "Quick Save Snippet"

local started = false
local item_id_counter = 0

local function same_list(left, right)
	if #left ~= #right then
		return false
	end

	for index, value in ipairs(left) do
		if right[index] ~= value then
			return false
		end
	end

	return true
end

local function normalize_hotkey_key(raw_key)
	if raw_key == nil then
		return nil
	end

	local normalized = string.lower(trim(tostring(raw_key)))

	if normalized == "" or normalized == "none" or normalized == "disabled" then
		return nil
	end

	return normalized
end

local function format_hotkey_for_prompt(modifiers, key)
	local modifier_names = {}

	for _, modifier in ipairs(modifiers or {}) do
		table.insert(modifier_names, modifier_prompt_names[modifier] or modifier)
	end

	return table.concat(modifier_names, "+"), key or ""
end

local state = {
	items = {},
	auto_paste = default_auto_paste,
	show_menubar = default_show_menubar,
	chooser = nil,
	chooser_screen_frame = nil,
	menubar = nil,
	open_hotkey = nil,
	open_hotkey_modifiers = {},
	open_hotkey_key = nil,
	quick_save_hotkey = nil,
	quick_save_hotkey_modifiers = {},
	quick_save_hotkey_key = nil,
	preview_canvas = nil,
	preview_timer = nil,
	preview_signature = nil,
	storage_path = default_storage_path,
	target_application = nil,
	editor = nil,
	editor_controller = nil,
	editor_context = nil,
}

local refresh_menubar

do
	local configured_open_modifiers, invalid_open_modifier = normalize_hotkey_modifiers(snippets.prefix or {})

	if configured_open_modifiers == nil then
		log.e("invalid snippet center hotkey modifier in config: " .. tostring(invalid_open_modifier))
		configured_open_modifiers = {}
	end

	local quick_save_config = snippets.quick_save or {}
	local configured_quick_save_modifiers, invalid_quick_save_modifier =
		normalize_hotkey_modifiers(quick_save_config.prefix or {})

	if configured_quick_save_modifiers == nil then
		log.e("invalid snippet quick save hotkey modifier in config: " .. tostring(invalid_quick_save_modifier))
		configured_quick_save_modifiers = {}
	end

	default_open_hotkey_modifiers = configured_open_modifiers
	default_open_hotkey_key = normalize_hotkey_key(snippets.key)
	default_quick_save_hotkey_modifiers = configured_quick_save_modifiers
	default_quick_save_hotkey_key = normalize_hotkey_key(quick_save_config.key)

	state.open_hotkey_modifiers = copy_list(default_open_hotkey_modifiers)
	state.open_hotkey_key = default_open_hotkey_key
	state.quick_save_hotkey_modifiers = copy_list(default_quick_save_hotkey_modifiers)
	state.quick_save_hotkey_key = default_quick_save_hotkey_key
end

local function persist_auto_paste_state()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" then
		return
	end

	if state.auto_paste == default_auto_paste then
		if type(hs.settings.clear) == "function" then
			hs.settings.clear(auto_paste_settings_key)
		end
		return
	end

	if type(hs.settings.set) == "function" then
		hs.settings.set(auto_paste_settings_key, state.auto_paste == true)
	end
end

local function load_persisted_auto_paste_state()
	if type(hs) ~= "table" or type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return
	end

	local persisted_auto_paste = hs.settings.get(auto_paste_settings_key)

	if persisted_auto_paste == nil then
		return
	end

	if type(persisted_auto_paste) ~= "boolean" then
		log.w("ignore invalid persisted snippet auto_paste state: " .. tostring(persisted_auto_paste))

		if type(hs.settings.clear) == "function" then
			hs.settings.clear(auto_paste_settings_key)
		end

		return
	end

	state.auto_paste = persisted_auto_paste
end

load_persisted_auto_paste_state()

local function load_persisted_hotkey_state(
	modifiers_settings_key,
	key_settings_key,
	default_modifiers,
	default_key,
	modifiers_state_field,
	key_state_field,
	label
)
	if type(hs) ~= "table" or type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return
	end

	local persisted_modifiers = hs.settings.get(modifiers_settings_key)
	local persisted_key = hs.settings.get(key_settings_key)

	if persisted_modifiers == nil and persisted_key == nil then
		return
	end

	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(persisted_modifiers)
	local normalized_key = normalize_hotkey_key(persisted_key)

	if normalized_modifiers == nil then
		log.w(string.format("ignore invalid persisted %s hotkey modifier: %s", label, tostring(invalid_modifier)))

		if type(hs.settings.clear) == "function" then
			hs.settings.clear(modifiers_settings_key)
			hs.settings.clear(key_settings_key)
		end

		state[modifiers_state_field] = copy_list(default_modifiers)
		state[key_state_field] = default_key
		return
	end

	state[modifiers_state_field] = normalized_modifiers
	state[key_state_field] = normalized_key
end

local function persist_hotkey_state(
	modifiers_settings_key,
	key_settings_key,
	default_modifiers,
	default_key,
	modifiers,
	key
)
	if type(hs) ~= "table" or type(hs.settings) ~= "table" then
		return
	end

	if same_list(modifiers, default_modifiers) and key == default_key then
		if type(hs.settings.clear) == "function" then
			hs.settings.clear(modifiers_settings_key)
			hs.settings.clear(key_settings_key)
		end

		return
	end

	if type(hs.settings.set) == "function" then
		hs.settings.set(modifiers_settings_key, copy_list(modifiers))
		hs.settings.set(key_settings_key, key or "")
	end
end

load_persisted_hotkey_state(
	open_hotkey_modifiers_settings_key,
	open_hotkey_key_settings_key,
	default_open_hotkey_modifiers,
	default_open_hotkey_key,
	"open_hotkey_modifiers",
	"open_hotkey_key",
	"snippet center"
)
load_persisted_hotkey_state(
	quick_save_hotkey_modifiers_settings_key,
	quick_save_hotkey_key_settings_key,
	default_quick_save_hotkey_modifiers,
	default_quick_save_hotkey_key,
	"quick_save_hotkey_modifiers",
	"quick_save_hotkey_key",
	"snippet quick save"
)

local function current_timestamp()
	return os.time()
end

local function normalize_search_text(text)
	if type(text) ~= "string" then
		return ""
	end

	text = text:gsub("\r\n", "\n")
	text = text:gsub("\r", "\n")
	text = text:gsub("%s+", " ")
	text = trim(text)

	if text == "" then
		return ""
	end

	return string.lower(text)
end

local function search_tokens(query)
	local normalized = normalize_search_text(query)

	if normalized == "" then
		return {}
	end

	local tokens = {}

	for token in string.gmatch(normalized, "%S+") do
		table.insert(tokens, token)
	end

	return tokens
end

local function safe_utf8len(text)
	local ok, length = pcall(utf8len, tostring(text or ""))

	if ok == true and type(length) == "number" then
		return length
	end

	return #tostring(text or "")
end

local function safe_utf8sub(text, start_char, num_chars)
	local ok, value = pcall(utf8sub, tostring(text or ""), start_char, num_chars)

	if ok == true and type(value) == "string" then
		return value
	end

	return tostring(text or ""):sub(start_char, start_char + num_chars - 1)
end

local function line_count(text)
	local _, count = string.gsub(tostring(text or ""), "\n", "\n")

	return count + 1
end

local function truncate_text(text, max_chars)
	local normalized = tostring(text or "")

	if safe_utf8len(normalized) <= max_chars then
		return normalized
	end

	return safe_utf8sub(normalized, 1, max_chars) .. "…"
end

local function compact_preview(text, max_chars)
	local preview = tostring(text or "")

	preview = preview:gsub("\r\n", "\n")
	preview = preview:gsub("\r", "\n")
	preview = preview:gsub("[ \t]+", " ")
	preview = preview:gsub("\n+", " ↩ ")
	preview = trim(preview)

	if preview == "" then
		preview = "(空白)"
	end

	return truncate_text(preview, max_chars)
end

local function truncate_preview_body(text)
	local normalized = tostring(text or "")

	if safe_utf8len(normalized) <= preview_body_max_chars then
		return normalized
	end

	return truncate_text(normalized, preview_body_max_chars) .. "\n\n..."
end

local function first_nonempty_line(text)
	for line in tostring(text or ""):gmatch("[^\n]+") do
		local normalized = trim(line)

		if normalized ~= "" then
			return normalized
		end
	end

	return ""
end

local function auto_title_for_content(content)
	local first_line = first_nonempty_line(content)

	if first_line == "" then
		return "未命名片段"
	end

	return truncate_text(first_line, default_auto_title_length)
end

local function display_title(item)
	local title = trim(tostring(item.title or ""))

	if title ~= "" then
		return truncate_text(title, title_preview_length)
	end

	return auto_title_for_content(item.content)
end

local function raw_title(item)
	local title = trim(tostring(item.title or ""))

	if title ~= "" then
		return title
	end

	return ""
end

local function snippet_detail(item)
	local detail = {
		string.format("%d 行", line_count(item.content)),
		string.format("%d 字符", safe_utf8len(item.content)),
	}

	if item.pinned == true then
		table.insert(detail, 1, "置顶")
	end

	if tonumber(item.last_used_at) and tonumber(item.last_used_at) > 0 then
		table.insert(detail, string.format("最近使用 %s", os.date("%m-%d %H:%M", item.last_used_at)))
	elseif tonumber(item.updated_at) and tonumber(item.updated_at) > 0 then
		table.insert(detail, string.format("更新于 %s", os.date("%m-%d %H:%M", item.updated_at)))
	end

	return table.concat(detail, " · ")
end

local function snippet_preview(item)
	return compact_preview(item.content, detail_preview_length)
end

local function build_search_text(item)
	return normalize_search_text(table.concat({
		raw_title(item),
		auto_title_for_content(item.content),
		item.content or "",
	}, "\n"))
end

local function next_item_id()
	item_id_counter = item_id_counter + 1

	return string.format("snippet_%d_%d", current_timestamp(), item_id_counter)
end

local function serialize_item(item)
	return {
		id = item.id,
		title = raw_title(item),
		content = item.content,
		pinned = item.pinned == true,
		created_at = tonumber(item.created_at) or current_timestamp(),
		updated_at = tonumber(item.updated_at) or current_timestamp(),
		last_used_at = tonumber(item.last_used_at) or 0,
		use_count = math.max(0, math.floor(tonumber(item.use_count) or 0)),
	}
end

local function clone_items(items)
	local cloned = {}

	for _, item in ipairs(items or {}) do
		table.insert(cloned, serialize_item(item))
	end

	return cloned
end

local function normalize_storage_path(path)
	local normalized = trim(tostring(path or ""))

	if normalized == "" then
		normalized = "~/.hammerspoon/data/snippets.json"
	end

	return expand_home_path(normalized)
end

local function storage_directory(path)
	return string.match(tostring(path or ""), "^(.*)/[^/]+/?$")
end

local function temp_storage_path(path)
	return tostring(path or "") .. ".tmp"
end

local function read_text_file(path)
	local file, open_error = io.open(path, "r")

	if file == nil then
		return nil, open_error
	end

	local content = file:read("*a")
	local closed, close_error = file:close()

	if closed ~= true and close_error ~= nil then
		return nil, close_error
	end

	return content
end

local function write_text_file(path, content)
	local file, open_error = io.open(path, "w")

	if file == nil then
		return false, open_error
	end

	local wrote, write_error = file:write(content)
	local closed, close_error = file:close()

	if wrote == nil then
		return false, write_error
	end

	if closed ~= true and close_error ~= nil then
		return false, close_error
	end

	return true
end

local function sanitize_item(raw_item)
	if type(raw_item) ~= "table" then
		return nil
	end

	local content = raw_item.content

	if type(content) ~= "string" then
		return nil
	end

	if trim(content) == "" then
		return nil
	end

	if #content > default_max_content_length then
		log.w("ignore persisted snippet whose content exceeds max_content_length")
		return nil
	end

	local item = {
		id = trim(tostring(raw_item.id or "")),
		title = trim(tostring(raw_item.title or "")),
		content = content,
		pinned = raw_item.pinned == true,
		created_at = tonumber(raw_item.created_at) or current_timestamp(),
		updated_at = tonumber(raw_item.updated_at) or current_timestamp(),
		last_used_at = tonumber(raw_item.last_used_at) or 0,
		use_count = math.max(0, math.floor(tonumber(raw_item.use_count) or 0)),
	}

	if item.id == "" then
		item.id = next_item_id()
	end

	return item
end

local function persist_items()
	if type(hs.json) ~= "table" or type(hs.json.encode) ~= "function" then
		return false, "当前环境不支持 JSON 编码"
	end

	local target_path = normalize_storage_path(state.storage_path)
	local parent_directory = storage_directory(target_path)

	if parent_directory ~= nil and parent_directory ~= "" and ensure_directory(parent_directory) ~= true then
		return false, "存储目录创建失败"
	end

	local encoded_ok, encoded_payload = pcall(hs.json.encode, {
		version = storage_file_version,
		items = clone_items(state.items),
	})

	if encoded_ok ~= true or type(encoded_payload) ~= "string" or encoded_payload == "" then
		return false, "snippet 数据编码失败"
	end

	local temp_path = temp_storage_path(target_path)

	pcall(os.remove, temp_path)

	local wrote_ok, write_error = write_text_file(temp_path, encoded_payload)

	if wrote_ok ~= true then
		pcall(os.remove, temp_path)
		return false, string.format("写入临时文件失败: %s", tostring(write_error))
	end

	local renamed, rename_error = os.rename(temp_path, target_path)

	if renamed ~= true then
		pcall(os.remove, temp_path)
		return false, string.format("原子替换失败: %s", tostring(rename_error))
	end

	state.storage_path = target_path

	return true
end

local function load_items()
	local target_path = normalize_storage_path(state.storage_path)

	state.storage_path = target_path

	if file_exists(target_path) ~= true then
		return {}
	end

	local body, read_error = read_text_file(target_path)

	if type(body) ~= "string" then
		return nil, string.format("读取 snippet 存储文件失败: %s", tostring(read_error))
	end

	if trim(body) == "" then
		return nil, "snippet 存储文件为空，请删除该文件后重试"
	end

	if type(hs.json) ~= "table" or type(hs.json.decode) ~= "function" then
		return nil, "当前环境不支持 JSON 解码"
	end

	local decoded_ok, payload = pcall(hs.json.decode, body)

	if decoded_ok ~= true or type(payload) ~= "table" then
		return nil, "snippet 存储文件解析失败"
	end

	if type(payload.items) ~= "table" then
		return nil, "snippet 存储文件格式无效"
	end

	local items = {}
	local seen_ids = {}

	for _, raw_item in ipairs(payload.items) do
		local item = sanitize_item(raw_item)

		if item ~= nil and seen_ids[item.id] ~= true then
			seen_ids[item.id] = true
			table.insert(items, item)
		end
	end

	return items
end

local function find_item_index_by_id(item_id)
	local normalized_id = trim(tostring(item_id or ""))

	if normalized_id == "" then
		return nil
	end

	for index, item in ipairs(state.items) do
		if item.id == normalized_id then
			return index
		end
	end

	return nil
end

local function find_item_by_id(item_id)
	local index = find_item_index_by_id(item_id)

	if index == nil then
		return nil, nil
	end

	return state.items[index], index
end

local function find_item_by_content(content)
	local target = tostring(content or "")

	for index, item in ipairs(state.items) do
		if item.content == target then
			return item, index
		end
	end

	return nil, nil
end

local function item_match_rank(item, normalized_query)
	if normalized_query == "" then
		return 9
	end

	local title_text = normalize_search_text(display_title(item))
	local content_text = normalize_search_text(item.content)

	if title_text:find(normalized_query, 1, true) == 1 then
		return 0
	end

	if title_text:find(normalized_query, 1, true) ~= nil then
		return 1
	end

	if content_text:find(normalized_query, 1, true) ~= nil then
		return 2
	end

	return 3
end

local function sorted_items(query)
	local tokens = search_tokens(query)
	local normalized_query = normalize_search_text(query)
	local matched = {}

	for _, item in ipairs(state.items) do
		local search_text = build_search_text(item)
		local include = true

		for _, token in ipairs(tokens) do
			if search_text:find(token, 1, true) == nil then
				include = false
				break
			end
		end

		if include == true then
			table.insert(matched, {
				item = item,
				match_rank = item_match_rank(item, normalized_query),
			})
		end
	end

	table.sort(matched, function(left, right)
		if left.item.pinned ~= right.item.pinned then
			return left.item.pinned == true
		end

		if left.match_rank ~= right.match_rank then
			return left.match_rank < right.match_rank
		end

		if left.item.last_used_at ~= right.item.last_used_at then
			return left.item.last_used_at > right.item.last_used_at
		end

		if left.item.use_count ~= right.item.use_count then
			return left.item.use_count > right.item.use_count
		end

		if left.item.updated_at ~= right.item.updated_at then
			return left.item.updated_at > right.item.updated_at
		end

		if left.item.created_at ~= right.item.created_at then
			return left.item.created_at > right.item.created_at
		end

		return display_title(left.item) < display_title(right.item)
	end)

	local items = {}

	for _, entry in ipairs(matched) do
		table.insert(items, entry.item)
	end

	return items
end

local function choice_for_item(item)
	return {
		text = display_title(item),
		subText = string.format("%s · %s", snippet_preview(item), snippet_detail(item)),
		source = "snippet",
		snippet_id = item.id,
		preview_title = display_title(item),
		preview_detail = snippet_detail(item),
		preview_body = item.content,
	}
end

local function action_matches(query, title, subtext)
	local normalized_query = normalize_search_text(query)

	if normalized_query == "" then
		return true
	end

	local search_text = normalize_search_text(string.format("%s %s", title or "", subtext or ""))

	return search_text:find(normalized_query, 1, true) ~= nil
end

local function build_action_choices(query)
	local choices = {}
	local actions = {
		{
			id = "new_empty",
			text = "新建空白片段",
			subText = "打开内置编辑器，标题可选，正文支持多行输入",
			preview_detail = "快捷操作",
			preview_body = "创建一个新的多行 snippet。标题可留空，列表会自动使用正文第一行作为显示标题。",
		},
		{
			id = "new_from_clipboard",
			text = "从当前剪贴板新建",
			subText = "直接保存当前剪贴板文本为 snippet，标题将自动生成",
			preview_detail = "快捷操作",
			preview_body = "直接把当前剪贴板里的文本保存为 snippet。若内容重复，会拒绝保存。",
		},
	}

	for _, action in ipairs(actions) do
		if action_matches(query, action.text, action.subText) == true then
			table.insert(choices, {
				text = action.text,
				subText = action.subText,
				source = "action",
				action = action.id,
				preview_title = action.text,
				preview_detail = action.preview_detail,
				preview_body = action.preview_body,
			})
		end
	end

	return choices
end

local function build_choices(query)
	local choices = build_action_choices(query)

	for _, item in ipairs(sorted_items(query)) do
		table.insert(choices, choice_for_item(item))
	end

	return choices
end

local function current_frontmost_application()
	if type(hs.application) ~= "table" or type(hs.application.frontmostApplication) ~= "function" then
		return nil
	end

	local ok, application = pcall(hs.application.frontmostApplication)

	if ok ~= true then
		return nil
	end

	return application
end

local function resolve_target_screen_frame()
	local target_screen = nil
	local focused_window = nil

	if type(hs.window) == "table" and type(hs.window.focusedWindow) == "function" then
		focused_window = hs.window.focusedWindow()
	end

	if focused_window ~= nil and type(focused_window.screen) == "function" then
		target_screen = focused_window:screen()
	end

	if target_screen == nil and type(hs.screen) == "table" and type(hs.screen.mainScreen) == "function" then
		target_screen = hs.screen.mainScreen()
	end

	if target_screen == nil or type(target_screen.frame) ~= "function" then
		return nil
	end

	return target_screen:frame()
end

local function chooser_window_height()
	return chooser_window_chrome_height + (chooser_row_height * default_chooser_rows)
end

local function chooser_layout(screen_frame)
	if screen_frame == nil then
		return nil
	end

	local chooser_width = math.floor(screen_frame.w * default_chooser_width / 100)
	local chooser_height = chooser_window_height()
	local chooser_x = screen_frame.x + math.floor((screen_frame.w - chooser_width) / 2)
	local chooser_y = screen_frame.y + math.floor((screen_frame.h - chooser_height) / 2)
	local preview_width = math.min(default_preview_width, math.floor(screen_frame.w * 0.34))
	local preview_height = math.min(default_preview_height, math.floor(screen_frame.h * 0.56))
	local preview_x = screen_frame.x + screen_frame.w - preview_width - default_preview_margin
	local preview_y = screen_frame.y + math.floor((screen_frame.h - preview_height) / 2)

	if default_preview_enabled == true then
		local total_width = chooser_width + default_preview_gap + preview_width + (default_preview_margin * 2)

		if total_width <= screen_frame.w then
			chooser_x = screen_frame.x + math.floor((screen_frame.w - (chooser_width + default_preview_gap + preview_width)) / 2)
			preview_x = chooser_x + chooser_width + default_preview_gap
		end
	end

	return {
		chooser_point = hs.geometry.point(chooser_x, chooser_y),
		preview_frame = {
			x = preview_x,
			y = preview_y,
			w = preview_width,
			h = preview_height,
		},
	}
end

local function preview_colors()
	if type(hs.host) == "table" and type(hs.host.interfaceStyle) == "function" and hs.host.interfaceStyle() == "Dark" then
		return {
			background = { red = 0.13, green = 0.14, blue = 0.17, alpha = 0.97 },
			border = { white = 1, alpha = 0.12 },
			title = { white = 1, alpha = 0.96 },
			detail = { white = 1, alpha = 0.56 },
			body = { white = 1, alpha = 0.9 },
			body_background = { white = 1, alpha = 0.04 },
			shadow = { alpha = 0.28, white = 0 },
		}
	end

	return {
		background = { white = 1, alpha = 0.98 },
		border = { white = 0, alpha = 0.1 },
		title = { white = 0.08, alpha = 1 },
		detail = { white = 0.22, alpha = 0.74 },
		body = { white = 0.08, alpha = 0.96 },
		body_background = { white = 0, alpha = 0.04 },
		shadow = { alpha = 0.18, white = 0 },
	}
end

local function snapshot_clipboard()
	local snapshot = {
		kind = "empty",
	}

	if type(hs.pasteboard) ~= "table" then
		return snapshot
	end

	if type(hs.pasteboard.readAllData) == "function" then
		local ok, raw_data = pcall(hs.pasteboard.readAllData)

		if ok == true and type(raw_data) == "table" then
			snapshot.has_raw_data = true
			snapshot.raw_data = raw_data
		end
	end

	if type(hs.pasteboard.getContents) == "function" then
		local ok, text = pcall(hs.pasteboard.getContents)

		if ok == true and text ~= nil then
			snapshot.kind = "text"
			snapshot.text = text
			return snapshot
		end
	end

	if type(hs.pasteboard.readImage) == "function" then
		local ok, image = pcall(hs.pasteboard.readImage)

		if ok == true and image ~= nil then
			snapshot.kind = "image"
			snapshot.image = image
		end
	end

	return snapshot
end

local function restore_clipboard(snapshot)
	if snapshot == nil or type(hs.pasteboard) ~= "table" then
		return
	end

	if snapshot.has_raw_data == true and type(snapshot.raw_data) == "table" and type(hs.pasteboard.writeAllData) == "function" then
		local ok, restored = pcall(hs.pasteboard.writeAllData, snapshot.raw_data)

		if ok == true and restored == true then
			return
		end
	end

	if snapshot.kind == "text" and type(hs.pasteboard.setContents) == "function" then
		pcall(hs.pasteboard.setContents, snapshot.text)
		return
	end

	if snapshot.kind == "image" and type(hs.pasteboard.writeObjects) == "function" then
		pcall(hs.pasteboard.writeObjects, snapshot.image)
		return
	end

	if snapshot.kind == "empty" and type(hs.pasteboard.clearContents) == "function" then
		pcall(hs.pasteboard.clearContents)
	end
end

local function suspend_clipboard_history(seconds)
	local clipboard_center = package.loaded["clipboard_center"]

	if type(clipboard_center) ~= "table" or type(clipboard_center.suspend_capture) ~= "function" then
		return
	end

	pcall(clipboard_center.suspend_capture, seconds)
end

local function write_text_to_clipboard(text)
	if type(hs.pasteboard) ~= "table" or type(hs.pasteboard.setContents) ~= "function" then
		return false
	end

	suspend_clipboard_history(history_suspend_seconds)

	local ok, result = pcall(hs.pasteboard.setContents, text)

	return ok == true and result == true
end

local function auto_paste_status_text()
	return state.auto_paste == true and "开启" or "关闭"
end

local function open_hotkey_label()
	if state.open_hotkey_key == nil then
		return "已禁用"
	end

	return format_hotkey(state.open_hotkey_modifiers, state.open_hotkey_key)
end

local function quick_save_hotkey_label()
	if state.quick_save_hotkey_key == nil then
		return "已禁用"
	end

	return format_hotkey(state.quick_save_hotkey_modifiers, state.quick_save_hotkey_key)
end

local function tooltip_text()
	return string.format(
		"Snippet Center · %d 条 · 自动粘贴%s · 打开%s · 快速保存%s",
		#state.items,
		auto_paste_status_text(),
		open_hotkey_label(),
		quick_save_hotkey_label()
	)
end

local function set_show_menubar(show_menubar)
	state.show_menubar = show_menubar == true

	if refresh_menubar ~= nil then
		refresh_menubar()
	end
end

local function set_auto_paste(enabled, options)
	options = options or {}

	local normalized = enabled == true

	if state.auto_paste == normalized then
		persist_auto_paste_state()

		if refresh_menubar ~= nil then
			refresh_menubar()
		end

		return true
	end

	state.auto_paste = normalized
	persist_auto_paste_state()

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	if options.show_alert ~= false then
		hs.alert.show(normalized == true and "已开启 snippet 自动粘贴" or "已关闭 snippet 自动粘贴")
	end

	return true
end

local function ensure_preview_canvas(frame)
	if type(hs.canvas) ~= "table" or type(hs.canvas.new) ~= "function" then
		return nil
	end

	if state.preview_canvas == nil then
		state.preview_canvas = hs.canvas.new(frame)

		if state.preview_canvas == nil then
			return nil
		end

		pcall(function()
			state.preview_canvas:level(hs.canvas.windowLevels.modalPanel)
		end)
		pcall(function()
			state.preview_canvas:clickActivating(false)
		end)
	end

	if type(state.preview_canvas.frame) == "function" then
		state.preview_canvas:frame(frame)
	end

	return state.preview_canvas
end

local function hide_preview()
	state.preview_signature = nil

	if state.preview_canvas ~= nil and type(state.preview_canvas.hide) == "function" then
		pcall(state.preview_canvas.hide, state.preview_canvas, 0.1)
	end
end

local function build_choice_preview(choice)
	if type(choice) ~= "table" then
		return nil
	end

	local title = trim(tostring(choice.preview_title or choice.text or ""))
	local detail = trim(tostring(choice.preview_detail or choice.subText or ""))
	local body = tostring(choice.preview_body or "")

	if body == "" then
		if choice.source == "snippet" then
			local item = find_item_by_id(choice.snippet_id)

			if item ~= nil then
				body = tostring(item.content or "")
			end
		else
			body = detail
		end
	end

	if trim(title) == "" and trim(detail) == "" and trim(body) == "" then
		return nil
	end

	if trim(title) == "" then
		title = "Snippet Preview"
	end

	return {
		signature = table.concat({
			tostring(choice.source or ""),
			tostring(choice.action or choice.snippet_id or ""),
			tostring(body),
		}, ":"),
		title = title,
		detail = detail,
		body = truncate_preview_body(body ~= "" and body or "(空白)"),
	}
end

local function build_text_preview_elements(frame, preview)
	local colors = preview_colors()
	local outer_radius = 16
	local inner_radius = 12
	local horizontal_padding = 18
	local top_padding = 16
	local title_height = 24
	local detail_height = preview.detail ~= "" and 18 or 0
	local body_top = top_padding + title_height + detail_height + 12
	local body_frame = {
		x = horizontal_padding,
		y = body_top,
		w = frame.w - (horizontal_padding * 2),
		h = frame.h - body_top - horizontal_padding,
	}

	return {
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.background,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			withShadow = true,
			shadow = {
				blurRadius = 18,
				color = colors.shadow,
				offset = { h = 0, w = 0 },
			},
			frame = { x = 0, y = 0, w = frame.w, h = frame.h },
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = outer_radius, yRadius = outer_radius },
			frame = { x = 0.5, y = 0.5, w = frame.w - 1, h = frame.h - 1 },
		},
		{
			type = "text",
			text = preview.title,
			textSize = 17,
			textColor = colors.title,
			frame = {
				x = horizontal_padding,
				y = top_padding,
				w = frame.w - (horizontal_padding * 2),
				h = title_height,
			},
		},
		{
			type = "text",
			text = preview.detail,
			textSize = 12,
			textColor = colors.detail,
			frame = {
				x = horizontal_padding,
				y = top_padding + title_height,
				w = frame.w - (horizontal_padding * 2),
				h = detail_height,
			},
		},
		{
			type = "rectangle",
			action = "fill",
			fillColor = colors.body_background,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = body_frame,
		},
		{
			type = "rectangle",
			action = "stroke",
			strokeColor = colors.border,
			strokeWidth = 1,
			roundedRectRadii = { xRadius = inner_radius, yRadius = inner_radius },
			frame = body_frame,
		},
		{
			type = "text",
			text = preview.body,
			textSize = 13,
			textColor = colors.body,
			frame = {
				x = body_frame.x + 12,
				y = body_frame.y + 10,
				w = body_frame.w - 24,
				h = body_frame.h - 20,
			},
		},
	}
end

local function update_preview()
	if default_preview_enabled ~= true or state.chooser == nil then
		return
	end

	local choice = state.chooser:selectedRowContents()

	if type(choice) ~= "table" then
		hide_preview()
		return
	end

	local preview = build_choice_preview(choice)

	if preview == nil then
		hide_preview()
		return
	end

	local screen_frame = state.chooser_screen_frame or resolve_target_screen_frame()
	local layout = chooser_layout(screen_frame)

	if layout == nil or layout.preview_frame == nil then
		hide_preview()
		return
	end

	local canvas = ensure_preview_canvas(layout.preview_frame)

	if canvas == nil then
		return
	end

	local canvas_showing = type(canvas.isShowing) == "function" and canvas:isShowing() == true or false

	if state.preview_signature ~= preview.signature or canvas_showing ~= true then
		if type(canvas.replaceElements) == "function" then
			canvas:replaceElements(table.unpack(build_text_preview_elements(layout.preview_frame, preview)))
		end

		if type(canvas.show) == "function" then
			canvas:show(0.08)
		end
	end

	state.preview_signature = preview.signature
end

local function stop_preview_timer()
	if state.preview_timer ~= nil and type(state.preview_timer.stop) == "function" then
		pcall(state.preview_timer.stop, state.preview_timer)
	end

	state.preview_timer = nil
end

local function start_preview_timer()
	if default_preview_enabled ~= true then
		return
	end

	stop_preview_timer()

	if type(hs.timer) == "table" and type(hs.timer.doEvery) == "function" then
		state.preview_timer = hs.timer.doEvery(default_preview_poll_interval, update_preview)
	end

	update_preview()
end

local function destroy_preview_canvas()
	stop_preview_timer()
	hide_preview()

	if state.preview_canvas ~= nil and type(state.preview_canvas.delete) == "function" then
		pcall(state.preview_canvas.delete, state.preview_canvas)
	end

	state.preview_canvas = nil
end

local function refresh_chooser_choices(preserve_query, selected_row)
	if state.chooser == nil then
		return
	end

	local chooser_visible = state.chooser:isVisible() == true
	local query = nil

	if preserve_query == true then
		query = state.chooser:query()
	end

	local choices = build_choices(query)

	state.chooser:choices(choices)

	if preserve_query ~= true then
		state.chooser:query(nil)
	end

	if chooser_visible ~= true then
		pcall(function()
			state.chooser:selectedRow(0)
		end)
		return
	end

	if #choices == 0 then
		pcall(function()
			state.chooser:selectedRow(0)
		end)
		return
	end

	local target_row = 1

	if type(selected_row) == "number" and selected_row > 0 then
		target_row = math.min(selected_row, #choices)
	end

	pcall(function()
		state.chooser:selectedRow(target_row)
	end)

	update_preview()
end

local function create_item(title, content, options)
	options = options or {}

	local normalized_title = trim(tostring(title or ""))
	local normalized_content = tostring(content or "")

	if trim(normalized_content) == "" then
		return false, "正文不能为空"
	end

	if #normalized_content > default_max_content_length then
		return false, string.format("正文不能超过 %d 字节", default_max_content_length)
	end

	if options.reject_duplicates == true then
		local duplicated_item = find_item_by_content(normalized_content)

		if duplicated_item ~= nil then
			return false, "已存在相同内容的 snippet"
		end
	end

	if #state.items >= default_max_items then
		return false, string.format("已达到 snippet 上限（%d）", default_max_items)
	end

	local timestamp = current_timestamp()
	local item = {
		id = next_item_id(),
		title = normalized_title,
		content = normalized_content,
		pinned = options.pinned == true,
		created_at = timestamp,
		updated_at = timestamp,
		last_used_at = 0,
		use_count = 0,
	}

	table.insert(state.items, item)
	local persisted_ok, persist_error = persist_items()

	if persisted_ok ~= true then
		table.remove(state.items, #state.items)
		log.e("failed to persist created snippet: " .. tostring(persist_error))
		return false, "保存 snippet 失败"
	end

	refresh_chooser_choices(true)

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true, item
end

local function update_item(item_id, fields)
	local item, index = find_item_by_id(item_id)

	if item == nil or index == nil then
		return false, "找不到对应的 snippet"
	end

	local next_title = trim(tostring(fields.title or ""))
	local next_content = tostring(fields.content or "")

	if trim(next_content) == "" then
		return false, "正文不能为空"
	end

	if #next_content > default_max_content_length then
		return false, string.format("正文不能超过 %d 字节", default_max_content_length)
	end

	local previous_item = serialize_item(state.items[index])
	item.title = next_title
	item.content = next_content
	item.updated_at = current_timestamp()

	state.items[index] = item
	local persisted_ok, persist_error = persist_items()

	if persisted_ok ~= true then
		state.items[index] = previous_item
		log.e("failed to persist updated snippet: " .. tostring(persist_error))
		return false, "保存 snippet 失败"
	end

	refresh_chooser_choices(true)

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true, item
end

local function delete_item(item_id)
	local index = find_item_index_by_id(item_id)

	if index == nil then
		return false
	end

	local removed_item = state.items[index]

	table.remove(state.items, index)

	local persisted_ok, persist_error = persist_items()

	if persisted_ok ~= true then
		table.insert(state.items, index, removed_item)
		log.e("failed to persist deleted snippet: " .. tostring(persist_error))
		return false
	end

	refresh_chooser_choices(true, index)

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true
end

local function mark_item_used(item_id)
	local item = find_item_by_id(item_id)

	if item == nil then
		return
	end

	local previous_last_used_at = item.last_used_at
	local previous_use_count = item.use_count
	item.last_used_at = current_timestamp()
	item.use_count = math.max(0, math.floor(tonumber(item.use_count) or 0)) + 1
	local persisted_ok, persist_error = persist_items()

	if persisted_ok ~= true then
		item.last_used_at = previous_last_used_at
		item.use_count = previous_use_count
		log.e("failed to persist snippet usage stats: " .. tostring(persist_error))
		return
	end

	if refresh_menubar ~= nil then
		refresh_menubar()
	end
end

local function set_item_pinned(item_id, pinned)
	local item = find_item_by_id(item_id)

	if item == nil then
		return false
	end

	local previous_item = serialize_item(item)
	item.pinned = pinned == true
	item.updated_at = current_timestamp()
	local persisted_ok, persist_error = persist_items()

	if persisted_ok ~= true then
		item.pinned = previous_item.pinned
		item.updated_at = previous_item.updated_at
		log.e("failed to persist snippet pin state: " .. tostring(persist_error))
		return false
	end

	refresh_chooser_choices(true)

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true
end

local function copy_item_to_clipboard(item)
	if item == nil then
		return false
	end

	if write_text_to_clipboard(item.content) == true then
		hs.alert.show("已复制到剪贴板")
		return true
	end

	hs.alert.show("写入剪贴板失败")
	return false
end

local function toggle_item_pinned_with_alert(item_id)
	local item = find_item_by_id(item_id)

	if item == nil then
		hs.alert.show("找不到对应的 snippet")
		return false
	end

	local next_pinned = item.pinned ~= true

	if set_item_pinned(item.id, next_pinned) ~= true then
		hs.alert.show("更新置顶状态失败")
		return false
	end

	hs.alert.show(next_pinned == true and "已置顶" or "已取消置顶")
	return true
end

local function delete_item_with_alert(item_id)
	if delete_item(item_id) == true then
		hs.alert.show("已删除 snippet")
		return true
	end

	hs.alert.show("删除 snippet 失败")
	return false
end

local function popup_context_menu(menu, point)
	if type(menu) ~= "table" or #menu == 0 then
		return
	end

	if type(hs.menubar) ~= "table" or type(hs.menubar.new) ~= "function" then
		return
	end

	local popup = hs.menubar.new(false)

	if popup == nil then
		return
	end

	popup:setMenu(menu)

	if type(popup.popupMenu) == "function" then
		popup:popupMenu(point or hs.mouse.absolutePosition())
	end

	popup:delete()
end

local show_chooser
local open_editor
local activate_item
local prompt_open_hotkey_configuration
local prompt_quick_save_hotkey_configuration
local restore_default_open_hotkey
local restore_default_quick_save_hotkey

local function menu_title_for_item(item)
	local title = raw_title(item)

	if title ~= "" then
		title = truncate_text(title, menu_title_preview_length)
	else
		title = truncate_text(first_nonempty_line(item.content), menu_title_preview_length)
	end

	if title == "" then
		title = "未命名片段"
	end

	if item.pinned == true then
		return "置顶 · " .. title
	end

	return title
end

local function menu_detail_for_item(item)
	local detail = {
		string.format("%d行", line_count(item.content)),
		string.format("%d字", safe_utf8len(item.content)),
	}

	if item.pinned == true then
		table.insert(detail, 1, "置顶")
	end

	if tonumber(item.last_used_at) and tonumber(item.last_used_at) > 0 then
		table.insert(detail, os.date("%m-%d %H:%M", item.last_used_at))
	elseif tonumber(item.updated_at) and tonumber(item.updated_at) > 0 then
		table.insert(detail, os.date("%m-%d %H:%M", item.updated_at))
	end

	return table.concat(detail, " · ")
end

local function menu_tooltip_for_item(item)
	return string.format("%s\n%s", snippet_preview(item), snippet_detail(item))
end

local function rename_item(item_id)
	local item = find_item_by_id(item_id)

	if item == nil then
		hs.alert.show("找不到对应的 snippet")
		return
	end

	local next_title = prompt_text(
		"重命名 Snippet",
		"标题可留空，留空时会自动取正文第一行作为显示标题。",
		raw_title(item)
	)

	if next_title == nil then
		return
	end

	local updated_ok = update_item(item_id, {
		title = trim(next_title),
		content = item.content,
	})

	if updated_ok ~= true then
		hs.alert.show("保存 snippet 失败")
		return
	end

	hs.alert.show("Snippet 标题已更新")
end

local function quick_save_current_clipboard(show_success_alert)
	if type(hs.pasteboard) ~= "table" or type(hs.pasteboard.getContents) ~= "function" then
		hs.alert.show("当前环境无法读取剪贴板文本")
		return false
	end

	local ok, text = pcall(hs.pasteboard.getContents)

	if ok ~= true or type(text) ~= "string" or trim(text) == "" then
		hs.alert.show("当前剪贴板没有可保存的文本")
		return false
	end

	local created, item_or_message = create_item("", text, {
		reject_duplicates = true,
	})

	if created ~= true then
		hs.alert.show(tostring(item_or_message))
		return false
	end

	if show_success_alert ~= false then
		hs.alert.show("已保存当前剪贴板为 snippet")
	end

	return true, item_or_message
end

local function build_item_management_menu(item)
	return {
		{ title = menu_title_for_item(item), disabled = true },
		{ title = menu_detail_for_item(item), disabled = true },
		{ title = "-" },
		{
			title = state.auto_paste == true and "插入 snippet" or "复制并准备粘贴",
			fn = function()
				activate_item(item.id)
			end,
		},
		{
			title = "复制到剪贴板",
			fn = function()
				copy_item_to_clipboard(find_item_by_id(item.id))
			end,
		},
		{
			title = "编辑...",
			fn = function()
				local current_item = find_item_by_id(item.id)

				if current_item == nil then
					hs.alert.show("找不到对应的 snippet")
					return
				end

				open_editor({
					mode = "edit",
					item_id = current_item.id,
					title = raw_title(current_item),
					content = current_item.content,
					reopen_after_close = false,
				})
			end,
		},
		{
			title = "重命名...",
			fn = function()
				rename_item(item.id)
			end,
		},
		{
			title = item.pinned == true and "取消置顶" or "置顶",
			fn = function()
				toggle_item_pinned_with_alert(item.id)
			end,
		},
		{ title = "-" },
		{
			title = "删除",
			fn = function()
				delete_item_with_alert(item.id)
			end,
		},
	}
end

local function build_hotkey_menu()
	return {
		{ title = "快捷键信息", disabled = true },
		{ title = "打开: " .. open_hotkey_label(), disabled = true },
		{ title = "保存: " .. quick_save_hotkey_label(), disabled = true },
		{ title = "-" },
		{
			title = "设置打开快捷键",
			fn = prompt_open_hotkey_configuration,
		},
		{
			title = "恢复默认打开",
			disabled = same_list(state.open_hotkey_modifiers, default_open_hotkey_modifiers)
					and state.open_hotkey_key == default_open_hotkey_key,
			fn = restore_default_open_hotkey,
		},
		{ title = "-" },
		{
			title = "设置快速保存快捷键",
			fn = prompt_quick_save_hotkey_configuration,
		},
		{
			title = "恢复默认保存",
			disabled = same_list(state.quick_save_hotkey_modifiers, default_quick_save_hotkey_modifiers)
					and state.quick_save_hotkey_key == default_quick_save_hotkey_key,
			fn = restore_default_quick_save_hotkey,
		},
	}
end

local function append_menu_items(menu)
	local items = sorted_items(nil)
	local count = math.min(#items, default_menu_items)

	table.insert(menu, {
		title = string.format("常用片段 (%d/%d)", count, #items),
		disabled = true,
	})

	if count == 0 then
		table.insert(menu, { title = "暂无 snippet", disabled = true })
		return
	end

	for index = 1, count do
		local item = items[index]

		table.insert(menu, {
			title = menu_title_for_item(item),
			tooltip = menu_tooltip_for_item(item),
			menu = build_item_management_menu(item),
		})
	end
end

local function build_menubar_menu()
	local menu = {
		{ title = "Snippet Center", disabled = true },
		{ title = string.format("总数: %d", #state.items), disabled = true },
		{ title = "自动粘贴: " .. auto_paste_status_text(), disabled = true },
		{ title = "打开: " .. open_hotkey_label(), disabled = true },
		{ title = "保存: " .. quick_save_hotkey_label(), disabled = true },
		{ title = "-" },
		{
			title = "打开 Chooser",
			fn = function()
				show_chooser({ preserve_target_application = true })
			end,
		},
		{
			title = "新建空白片段",
			fn = function()
				open_editor({
					mode = "create",
					reopen_after_close = false,
				})
			end,
		},
		{
			title = "从当前剪贴板新建",
			fn = function()
				quick_save_current_clipboard(true)
			end,
		},
		{
			title = "自动粘贴",
			checked = state.auto_paste == true,
			fn = function()
				set_auto_paste(state.auto_paste ~= true)
			end,
		},
		{
			title = "快捷键",
			menu = build_hotkey_menu(),
		},
		{
			title = "隐藏图标",
			fn = function()
				set_show_menubar(false)
			end,
		},
		{ title = "-" },
	}

	append_menu_items(menu)

	return menu
end

refresh_menubar = function()
	if state.show_menubar ~= true then
		if state.menubar ~= nil and type(state.menubar.delete) == "function" then
			pcall(state.menubar.delete, state.menubar)
		end

		state.menubar = nil
		return
	end

	if type(hs.menubar) ~= "table" or type(hs.menubar.new) ~= "function" then
		log.w("hs.menubar is unavailable")
		return
	end

	if state.menubar == nil then
		state.menubar = hs.menubar.new(true, menubar_autosave_name)

		if state.menubar == nil then
			log.e("failed to create snippet menubar item")
			return
		end
	end

	if type(state.menubar.autosaveName) == "function" then
		pcall(state.menubar.autosaveName, state.menubar, menubar_autosave_name)
	end

	if type(state.menubar.setTitle) == "function" then
		state.menubar:setTitle(menubar_title)
	end

	if type(state.menubar.setTooltip) == "function" then
		state.menubar:setTooltip(tooltip_text())
	end

	if type(state.menubar.setMenu) == "function" then
		state.menubar:setMenu(function()
			state.target_application = current_frontmost_application()
			return build_menubar_menu()
		end)
	end
end

local function js_string_literal(value)
	local escaped = tostring(value or "")

	escaped = escaped:gsub("\\", "\\\\")
	escaped = escaped:gsub("\r", "\\r")
	escaped = escaped:gsub("\n", "\\n")
	escaped = escaped:gsub("\"", "\\\"")
	escaped = escaped:gsub("</", "<\\/")

	return "\"" .. escaped .. "\""
end

local function editor_html(context)
	local title = js_string_literal(context.title or "")
	local content = js_string_literal(context.content or "")
	local header = context.mode == "edit" and "编辑文本片段" or "新建文本片段"
	local subtitle = "标题可选；如果留空，列表中会自动使用正文第一行作为显示标题。"

	return string.format(
		[[
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
  :root {
    color-scheme: light dark;
    --bg: #f4efe6;
    --panel: rgba(255,255,255,0.86);
    --text: #221c15;
    --muted: #6d6257;
    --line: rgba(34,28,21,0.12);
    --accent: #18644e;
    --accent-soft: rgba(24,100,78,0.14);
    --danger: #8e2d2d;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #171b1f;
      --panel: rgba(24,29,34,0.9);
      --text: #eef2f4;
      --muted: #9ea9b2;
      --line: rgba(255,255,255,0.10);
      --accent: #5cc3a1;
      --accent-soft: rgba(92,195,161,0.16);
      --danger: #f08a8a;
    }
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; height: 100%%; font-family: "SF Pro Text", "PingFang SC", sans-serif; background:
    radial-gradient(circle at top left, rgba(24,100,78,0.15), transparent 34%%),
    linear-gradient(180deg, var(--bg), color-mix(in srgb, var(--bg) 70%%, #000 8%%)); color: var(--text); }
  body { padding: 22px; }
  .panel {
    height: 100%%;
    border: 1px solid var(--line);
    border-radius: 18px;
    background: var(--panel);
    backdrop-filter: blur(18px);
    box-shadow: 0 18px 48px rgba(0,0,0,0.16);
    display: grid;
    grid-template-rows: auto auto 1fr auto;
    gap: 16px;
    padding: 22px;
  }
  h1 { margin: 0; font-size: 24px; line-height: 1.2; }
  .sub { color: var(--muted); font-size: 13px; line-height: 1.5; }
  label { display: block; font-size: 13px; color: var(--muted); margin-bottom: 8px; }
  input, textarea {
    width: 100%%;
    border-radius: 14px;
    border: 1px solid var(--line);
    background: rgba(255,255,255,0.62);
    color: var(--text);
    padding: 12px 14px;
    font-size: 14px;
    outline: none;
  }
  @media (prefers-color-scheme: dark) {
    input, textarea { background: rgba(255,255,255,0.04); }
  }
  input:focus, textarea:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px var(--accent-soft);
  }
  textarea {
    resize: none;
    min-height: 100%%;
    line-height: 1.55;
    font-family: "SF Mono", "JetBrains Mono", "Menlo", monospace;
  }
  .editor {
    display: grid;
    grid-template-rows: auto 1fr;
    min-height: 0;
  }
  .footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
  }
  .hint { color: var(--muted); font-size: 12px; }
  .actions { display: flex; gap: 10px; }
  button {
    border: 0;
    border-radius: 999px;
    padding: 10px 16px;
    font-size: 13px;
    cursor: pointer;
  }
  .ghost {
    background: transparent;
    color: var(--muted);
    border: 1px solid var(--line);
  }
  .primary {
    background: var(--accent);
    color: white;
  }
</style>
</head>
<body>
  <div class="panel">
    <div>
      <h1>%s</h1>
      <div class="sub">%s</div>
    </div>
    <div>
      <label for="title">标题（可选）</label>
      <input id="title" type="text" placeholder="例如：日报模板 / 常用签名" />
    </div>
    <div class="editor">
      <label for="content">正文</label>
      <textarea id="content" placeholder="在这里输入 snippet 正文，支持多行。"></textarea>
    </div>
    <div class="footer">
      <div class="hint">快捷键：Command+S 保存，Escape 关闭窗口</div>
      <div class="actions">
        <button class="ghost" id="cancel">取消</button>
        <button class="primary" id="save">保存</button>
      </div>
    </div>
  </div>
<script>
  const titleInput = document.getElementById("title");
  const contentInput = document.getElementById("content");
  titleInput.value = %s;
  contentInput.value = %s;
  function post(action) {
    try {
      webkit.messageHandlers.%s.postMessage({
        action,
        title: titleInput.value,
        content: contentInput.value,
      });
    } catch (error) {
      console.error(error);
    }
  }
  document.getElementById("save").addEventListener("click", () => post("save"));
  document.getElementById("cancel").addEventListener("click", () => post("cancel"));
  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s") {
      event.preventDefault();
      post("save");
      return;
    }
    if (event.key === "Escape") {
      post("cancel");
    }
  });
  if (contentInput.value === "") {
    contentInput.focus();
  } else {
    titleInput.focus();
    titleInput.select();
  }
</script>
</body>
</html>
]],
		header,
		header,
		subtitle,
		title,
		content,
		editor_port_name
	)
end

local function schedule_reopen_chooser(context)
	if context == nil or context.reopen_after_close ~= true then
		return
	end

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		show_chooser()
		return
	end

	hs.timer.doAfter(0, function()
		show_chooser()
	end)
end

local function focus_editor_window(editor)
	if editor == nil then
		return
	end

	if type(editor.bringToFront) == "function" then
		pcall(editor.bringToFront, editor, false)
	end

	if type(editor.hswindow) ~= "function" then
		return
	end

	local ok, editor_window = pcall(editor.hswindow, editor)

	if ok ~= true or type(editor_window) ~= "table" then
		return
	end

	if type(editor_window.focus) == "function" then
		pcall(editor_window.focus, editor_window)
	end
end

local function focus_editor_textarea(editor)
	if editor == nil or type(editor.evaluateJavaScript) ~= "function" then
		return
	end

	editor:evaluateJavaScript([[
		(function() {
			var content = document.getElementById("content");
			if (!content) {
				return false;
			}
			content.focus();
			if (typeof content.setSelectionRange === "function") {
				var end = content.value.length;
				content.setSelectionRange(end, end);
			}
			return document.activeElement && document.activeElement.id;
		})()
	]])
end

local function click_editor_content(editor)
	if editor == nil then
		return
	end

	if type(hs.mouse) ~= "table" or type(hs.mouse.absolutePosition) ~= "function" then
		return
	end

	if type(hs.eventtap) ~= "table" or type(hs.eventtap.leftClick) ~= "function" then
		return
	end

	if type(editor.frame) ~= "function" then
		return
	end

	local ok, frame = pcall(editor.frame, editor)

	if ok ~= true or type(frame) ~= "table" then
		return
	end

	local original_mouse_position = hs.mouse.absolutePosition()
	local click_point = {
		x = frame.x + math.floor(frame.w / 2),
		y = frame.y + math.min(math.floor(frame.h / 2), 170),
	}

	pcall(hs.eventtap.leftClick, click_point, 120000)
	hs.mouse.absolutePosition(original_mouse_position)
end

local function close_editor(options)
	options = options or {}

	if state.editor == nil then
		state.editor_controller = nil
		state.editor_context = nil
		return
	end

	local context = state.editor_context
	state.editor_context = nil
	state.editor_controller = nil

	local editor = state.editor
	state.editor = nil

	if context ~= nil and options.reopen_after_close == true then
		schedule_reopen_chooser(context)
	end

	if type(editor.delete) == "function" then
		pcall(editor.delete, editor)
	elseif type(editor.hide) == "function" then
		pcall(editor.hide, editor)
	end
end

local function handle_editor_message(message)
	local payload = message

	if type(message) == "table" and type(message.body) == "table" then
		payload = message.body
	end

	if type(payload) ~= "table" then
		return
	end

	if payload.action == "cancel" then
		close_editor({ reopen_after_close = true })
		return
	end

	if payload.action ~= "save" then
		return
	end

	local context = state.editor_context or {}
	local success
	local result

	if context.mode == "edit" then
		success, result = update_item(context.item_id, {
			title = payload.title,
			content = payload.content,
		})
	else
		success, result = create_item(payload.title, payload.content, {
			reject_duplicates = false,
		})
	end

	if success ~= true then
		hs.alert.show(tostring(result))
		return
	end

	close_editor({ reopen_after_close = true })

	if context.mode == "edit" then
		hs.alert.show("Snippet 已更新")
	else
		hs.alert.show("Snippet 已创建")
	end
end

open_editor = function(options)
	options = options or {}

	if type(hs.webview) ~= "table" or type(hs.webview.usercontent) ~= "table" then
		hs.alert.show("当前环境不支持内置 snippet 编辑器")
		return false
	end

	if type(hs.webview.usercontent.new) ~= "function" then
		hs.alert.show("当前环境不支持内置 snippet 编辑器")
		return false
	end

	if state.chooser ~= nil and type(state.chooser.isVisible) == "function" and state.chooser:isVisible() == true then
		if type(state.chooser.hide) == "function" then
			pcall(state.chooser.hide, state.chooser)
		end

		stop_preview_timer()
		hide_preview()
	end

	close_editor()

	local screen_frame = resolve_target_screen_frame()

	if screen_frame == nil then
		hs.alert.show("无法确定编辑器窗口位置")
		return false
	end

	local width = math.min(default_editor_width, screen_frame.w - 32)
	local height = math.min(default_editor_height, screen_frame.h - 32)
	local frame = {
		x = screen_frame.x + math.floor((screen_frame.w - width) / 2),
		y = screen_frame.y + math.floor((screen_frame.h - height) / 2),
		w = width,
		h = height,
	}

	local controller = hs.webview.usercontent.new(editor_port_name)

	if controller == nil or type(controller.setCallback) ~= "function" then
		hs.alert.show("内置 snippet 编辑器初始化失败")
		return false
	end

	controller:setCallback(handle_editor_message)

	local editor = nil

	if type(hs.webview.new) == "function" then
		editor = hs.webview.new(frame, {
			developerExtrasEnabled = false,
		}, controller)

		if editor ~= nil and type(editor.allowTextEntry) == "function" then
			editor:allowTextEntry(true)
		end
	end

	if editor == nil then
		hs.alert.show("内置 snippet 编辑器创建失败")
		return false
	end

	state.editor = editor
	state.editor_controller = controller
	state.editor_context = {
		mode = options.mode or "create",
		item_id = options.item_id,
		reopen_after_close = options.reopen_after_close == true,
	}

	if type(editor.windowTitle) == "function" then
		editor:windowTitle(options.mode == "edit" and "编辑 Snippet" or "新建 Snippet")
	end

	if type(editor.allowTextEntry) == "function" then
		editor:allowTextEntry(true)
	end

	if type(editor.allowNewWindows) == "function" then
		editor:allowNewWindows(false)
	end

	if type(editor.allowGestures) == "function" then
		editor:allowGestures(true)
	end

	if type(editor.closeOnEscape) == "function" then
		editor:closeOnEscape(true)
	end

	if type(editor.deleteOnClose) == "function" then
		editor:deleteOnClose(true)
	end

	if type(editor.shadow) == "function" then
		editor:shadow(true)
	end

	if type(editor.transparent) == "function" then
		editor:transparent(false)
	end

	if type(editor.windowStyle) == "function" then
		editor:windowStyle(31)
	end

	if type(editor.behaviorAsLabels) == "function" then
		editor:behaviorAsLabels({
			"ignoresCycle",
			"moveToActiveSpace",
		})
	end

	if type(editor.windowCallback) == "function" then
		editor:windowCallback(function(action)
			if action == "closing" then
				local context = state.editor_context

				state.editor = nil
				state.editor_controller = nil
				state.editor_context = nil

				schedule_reopen_chooser(context)
				return
			end

			if action == "focusChange" then
				focus_editor_textarea(editor)
			end
		end)
	end

	if type(editor.navigationCallback) == "function" then
		editor:navigationCallback(function(_, action)
			if action == "didFinishNavigation" then
				focus_editor_textarea(editor)
			end
		end)
	end

	if type(editor.html) == "function" then
		editor:html(editor_html({
			mode = options.mode or "create",
			title = options.title or "",
			content = options.content or "",
		}))
	end

	if type(editor.show) == "function" then
		editor:show()
	end

	if type(hs.timer) == "table" and type(hs.timer.doAfter) == "function" then
		for _, delay in ipairs({ 0, 0.08, 0.18 }) do
			hs.timer.doAfter(delay, function()
				if state.editor == editor then
					focus_editor_window(editor)
					focus_editor_textarea(editor)
				end
			end)
		end

		hs.timer.doAfter(0.14, function()
			if state.editor == editor then
				click_editor_content(editor)
				focus_editor_textarea(editor)
			end
		end)
	else
		focus_editor_window(editor)
		focus_editor_textarea(editor)
	end

	return true
end

activate_item = function(item_id)
	local item = find_item_by_id(item_id)
	local snapshot = nil

	if item == nil then
		hs.alert.show("找不到对应的 snippet")
		return
	end

	if default_restore_clipboard_after_paste == true then
		snapshot = snapshot_clipboard()
	end

	if write_text_to_clipboard(item.content) ~= true then
		hs.alert.show("写入剪贴板失败")
		return
	end

	mark_item_used(item.id)

	if state.auto_paste ~= true then
		hs.alert.show("已复制 snippet 到剪贴板")
		return
	end

	if type(hs.eventtap) ~= "table" or type(hs.eventtap.keyStroke) ~= "function" then
		hs.alert.show("已复制 snippet 到剪贴板，当前环境不支持自动粘贴")
		return
	end

	if type(hs.timer) ~= "table" or type(hs.timer.doAfter) ~= "function" then
		hs.alert.show("已复制 snippet 到剪贴板，当前环境不支持自动粘贴")
		return
	end

	local target_application = state.target_application or current_frontmost_application()

	hs.timer.doAfter(auto_paste_delay_seconds, function()
		if target_application ~= nil and type(target_application.activate) == "function" then
			pcall(target_application.activate, target_application)
		end

		hs.eventtap.keyStroke({ "cmd" }, "v", 0)

		if snapshot ~= nil and default_restore_clipboard_after_paste == true then
			hs.timer.doAfter(clipboard_restore_delay_seconds, function()
				suspend_clipboard_history(1)
				restore_clipboard(snapshot)
			end)
		end
	end)

	if snapshot ~= nil and default_restore_clipboard_after_paste == true then
		hs.alert.show("已插入 snippet，并恢复原剪贴板")
	else
		hs.alert.show("已插入 snippet")
	end
end

local function handle_choice(choice)
	if type(choice) ~= "table" then
		return
	end

	if choice.source == "action" then
		if choice.action == "new_empty" then
			open_editor({
				mode = "create",
				reopen_after_close = true,
			})
			return
		end

		if choice.action == "new_from_clipboard" then
			quick_save_current_clipboard(true)
			return
		end

		return
	end

	if choice.source == "snippet" then
		activate_item(choice.snippet_id)
	end
end

local function show_chooser_context_menu(row)
	if state.chooser == nil or type(row) ~= "number" or row < 1 then
		return
	end

	pcall(function()
		state.chooser:selectedRow(row)
	end)

	local choice = state.chooser:selectedRowContents(row)

	if type(choice) ~= "table" or choice.source ~= "snippet" then
		popup_context_menu({
			{ title = "该项不支持右键操作", disabled = true },
		})
		return
	end

	local item = find_item_by_id(choice.snippet_id)

	if item == nil then
		popup_context_menu({
			{ title = "找不到对应的 snippet", disabled = true },
		})
		return
	end

	popup_context_menu({
		{
			title = "编辑...",
			fn = function()
				open_editor({
					mode = "edit",
					item_id = item.id,
					title = raw_title(item),
					content = item.content,
					reopen_after_close = true,
				})
			end,
		},
		{
			title = "重命名...",
			fn = function()
				rename_item(item.id)
			end,
		},
		{
			title = item.pinned == true and "取消置顶" or "置顶",
			fn = function()
				toggle_item_pinned_with_alert(item.id)
			end,
		},
		{
			title = "复制到剪贴板",
			fn = function()
				copy_item_to_clipboard(item)
			end,
		},
		{ title = "-" },
		{
			title = "删除",
			fn = function()
				delete_item_with_alert(item.id)
			end,
		},
	})
end

local function setup_chooser()
	if type(hs.chooser) ~= "table" or type(hs.chooser.new) ~= "function" then
		log.e("hs.chooser is unavailable")
		return false
	end

	state.chooser = hs.chooser.new(function(choice)
		handle_choice(choice)
	end)

	state.chooser:searchSubText(true)
	state.chooser:rows(default_chooser_rows)
	state.chooser:width(default_chooser_width)
	state.chooser:placeholderText("搜索 snippet，回车插入，右键可编辑/删除")
	state.chooser:showCallback(function()
		local selected_row = state.chooser:selectedRow() or 0

		if selected_row < 1 then
			pcall(function()
				state.chooser:selectedRow(1)
			end)
		end

		start_preview_timer()
	end)
	if type(state.chooser.hideCallback) == "function" then
		state.chooser:hideCallback(function()
			stop_preview_timer()
			hide_preview()
		end)
	end
	state.chooser:queryChangedCallback(function()
		local selected_row = state.chooser:selectedRow() or 0
		refresh_chooser_choices(true, selected_row)
		update_preview()
	end)
	state.chooser:rightClickCallback(function(row)
		show_chooser_context_menu(row)
	end)

	return true
end

local function destroy_chooser()
	if state.chooser == nil then
		destroy_preview_canvas()
		return
	end

	if type(state.chooser.hide) == "function" then
		pcall(state.chooser.hide, state.chooser)
	end

	stop_preview_timer()
	hide_preview()

	if type(state.chooser.delete) == "function" then
		pcall(state.chooser.delete, state.chooser)
	end

	state.chooser = nil
	state.chooser_screen_frame = nil
	destroy_preview_canvas()
end

local function create_open_hotkey_binding(modifiers, key)
	if key == nil then
		return true, nil
	end

	local binding = hotkey_helper.bind(
		copy_list(modifiers),
		key,
		open_hotkey_message,
		function()
			show_chooser()
		end,
		nil,
		nil,
		{ logger = log }
	)

	if binding == nil then
		return false, "bind failed"
	end

	return true, binding
end

local function create_quick_save_hotkey_binding(modifiers, key)
	if key == nil then
		return true, nil
	end

	local binding = hotkey_helper.bind(
		copy_list(modifiers),
		key,
		quick_save_hotkey_message,
		function()
			quick_save_current_clipboard(true)
		end,
		nil,
		nil,
		{ logger = log }
	)

	if binding == nil then
		return false, "bind failed"
	end

	return true, binding
end

local function apply_open_hotkey_binding(reason)
	local ok, binding_or_error = create_open_hotkey_binding(state.open_hotkey_modifiers, state.open_hotkey_key)

	if ok ~= true then
		log.e(string.format("failed to bind snippet open hotkey (%s): %s", reason or "unknown", tostring(binding_or_error)))
		return false
	end

	if state.open_hotkey ~= nil then
		state.open_hotkey:delete()
	end

	state.open_hotkey = binding_or_error

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true
end

local function apply_quick_save_hotkey_binding(reason)
	local ok, binding_or_error =
		create_quick_save_hotkey_binding(state.quick_save_hotkey_modifiers, state.quick_save_hotkey_key)

	if ok ~= true then
		log.e(
			string.format(
				"failed to bind snippet quick save hotkey (%s): %s",
				reason or "unknown",
				tostring(binding_or_error)
			)
		)
		return false
	end

	if state.quick_save_hotkey ~= nil then
		state.quick_save_hotkey:delete()
	end

	state.quick_save_hotkey = binding_or_error

	if refresh_menubar ~= nil then
		refresh_menubar()
	end

	return true
end

local function set_open_hotkey(modifiers, key, reason)
	if same_list(state.open_hotkey_modifiers, modifiers) and state.open_hotkey_key == key then
		return true
	end

	local previous_modifiers = copy_list(state.open_hotkey_modifiers)
	local previous_key = state.open_hotkey_key
	local previous_binding = state.open_hotkey

	state.open_hotkey_modifiers = copy_list(modifiers)
	state.open_hotkey_key = key
	state.open_hotkey = nil

	if previous_binding ~= nil then
		previous_binding:delete()
	end

	if apply_open_hotkey_binding(reason) ~= true then
		state.open_hotkey_modifiers = previous_modifiers
		state.open_hotkey_key = previous_key
		state.open_hotkey = nil
		apply_open_hotkey_binding("restore previous snippet open hotkey")
		hs.alert.show("Snippet 打开快捷键设置失败")
		return false
	end

	persist_hotkey_state(
		open_hotkey_modifiers_settings_key,
		open_hotkey_key_settings_key,
		default_open_hotkey_modifiers,
		default_open_hotkey_key,
		state.open_hotkey_modifiers,
		state.open_hotkey_key
	)

	if state.open_hotkey_key == nil then
		hs.alert.show("已禁用 Snippet 打开快捷键")
	else
		hs.alert.show("Snippet 打开快捷键已更新: " .. open_hotkey_label())
	end

	return true
end

local function set_quick_save_hotkey(modifiers, key, reason)
	if same_list(state.quick_save_hotkey_modifiers, modifiers) and state.quick_save_hotkey_key == key then
		return true
	end

	local previous_modifiers = copy_list(state.quick_save_hotkey_modifiers)
	local previous_key = state.quick_save_hotkey_key
	local previous_binding = state.quick_save_hotkey

	state.quick_save_hotkey_modifiers = copy_list(modifiers)
	state.quick_save_hotkey_key = key
	state.quick_save_hotkey = nil

	if previous_binding ~= nil then
		previous_binding:delete()
	end

	if apply_quick_save_hotkey_binding(reason) ~= true then
		state.quick_save_hotkey_modifiers = previous_modifiers
		state.quick_save_hotkey_key = previous_key
		state.quick_save_hotkey = nil
		apply_quick_save_hotkey_binding("restore previous snippet quick save hotkey")
		hs.alert.show("Snippet 快速保存快捷键设置失败")
		return false
	end

	persist_hotkey_state(
		quick_save_hotkey_modifiers_settings_key,
		quick_save_hotkey_key_settings_key,
		default_quick_save_hotkey_modifiers,
		default_quick_save_hotkey_key,
		state.quick_save_hotkey_modifiers,
		state.quick_save_hotkey_key
	)

	if state.quick_save_hotkey_key == nil then
		hs.alert.show("已禁用 Snippet 快速保存快捷键")
	else
		hs.alert.show("Snippet 快速保存快捷键已更新: " .. quick_save_hotkey_label())
	end

	return true
end

prompt_open_hotkey_configuration = function()
	local current_modifiers, current_key = format_hotkey_for_prompt(state.open_hotkey_modifiers, state.open_hotkey_key)
	local modifier_text = prompt_text(
		"设置 Snippet 打开快捷键",
		"请输入修饰键, 多个值用 + 分隔。\n可用: ctrl option command shift fn\n留空表示无修饰键。",
		current_modifiers
	)

	if modifier_text == nil then
		return
	end

	local key_text = prompt_text(
		"设置 Snippet 打开快捷键",
		"请输入主键, 例如 s、space、return、f18。\n留空表示禁用快捷键。",
		current_key
	)

	if key_text == nil then
		return
	end

	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(modifier_text)
	local normalized_key = normalize_hotkey_key(key_text)

	if normalized_modifiers == nil then
		hs.alert.show("无效修饰键: " .. tostring(invalid_modifier))
		return
	end

	set_open_hotkey(normalized_modifiers, normalized_key, "menubar update snippet open hotkey")
end

prompt_quick_save_hotkey_configuration = function()
	local current_modifiers, current_key =
		format_hotkey_for_prompt(state.quick_save_hotkey_modifiers, state.quick_save_hotkey_key)
	local modifier_text = prompt_text(
		"设置 Snippet 快速保存快捷键",
		"请输入修饰键, 多个值用 + 分隔。\n可用: ctrl option command shift fn\n留空表示无修饰键。",
		current_modifiers
	)

	if modifier_text == nil then
		return
	end

	local key_text = prompt_text(
		"设置 Snippet 快速保存快捷键",
		"请输入主键, 例如 s、space、return、f18。\n留空表示禁用快捷键。",
		current_key
	)

	if key_text == nil then
		return
	end

	local normalized_modifiers, invalid_modifier = normalize_hotkey_modifiers(modifier_text)
	local normalized_key = normalize_hotkey_key(key_text)

	if normalized_modifiers == nil then
		hs.alert.show("无效修饰键: " .. tostring(invalid_modifier))
		return
	end

	set_quick_save_hotkey(normalized_modifiers, normalized_key, "menubar update snippet quick save hotkey")
end

restore_default_open_hotkey = function()
	set_open_hotkey(default_open_hotkey_modifiers, default_open_hotkey_key, "restore default snippet open hotkey")
end

restore_default_quick_save_hotkey = function()
	set_quick_save_hotkey(
		default_quick_save_hotkey_modifiers,
		default_quick_save_hotkey_key,
		"restore default snippet quick save hotkey"
	)
end

local function delete_bindings()
	if state.open_hotkey ~= nil then
		state.open_hotkey:delete()
		state.open_hotkey = nil
	end

	if state.quick_save_hotkey ~= nil then
		state.quick_save_hotkey:delete()
		state.quick_save_hotkey = nil
	end
end

show_chooser = function(options)
	options = options or {}

	if started ~= true then
		if _M.start() ~= true then
			return
		end
	end

	if state.chooser == nil then
		return
	end

	if options.preserve_target_application ~= true or state.target_application == nil then
		state.target_application = current_frontmost_application()
	end

	state.chooser_screen_frame = resolve_target_screen_frame()
	state.chooser:choices(build_choices())
	state.chooser:query(nil)
	local layout = chooser_layout(state.chooser_screen_frame)

	if layout ~= nil and layout.chooser_point ~= nil then
		state.chooser:show(layout.chooser_point)
	else
		state.chooser:show()
	end
end

function _M.start()
	if started == true then
		return true
	end

	started = true
	local loaded_items, load_error = load_items()

	if loaded_items == nil then
		log.e("failed to load snippet storage: " .. tostring(load_error))
		started = false
		return false
	end

	state.items = loaded_items

	if snippets.enabled == false then
		return true
	end

	if setup_chooser() ~= true then
		started = false
		return false
	end

	if apply_open_hotkey_binding("startup") ~= true then
		destroy_chooser()
		started = false
		return false
	end

	if apply_quick_save_hotkey_binding("startup") ~= true then
		if state.open_hotkey ~= nil then
			state.open_hotkey:delete()
			state.open_hotkey = nil
		end

		destroy_chooser()
		started = false
		return false
	end

	refresh_menubar()

	return true
end

function _M.stop()
	delete_bindings()
	destroy_chooser()
	close_editor()

	if state.menubar ~= nil and type(state.menubar.delete) == "function" then
		pcall(state.menubar.delete, state.menubar)
	end

	state.menubar = nil
	state.items = {}
	state.target_application = nil
	started = false

	return true
end

_M.show_chooser = show_chooser
_M.new_empty_snippet = function()
	return open_editor({
		mode = "create",
		reopen_after_close = false,
	})
end
_M.quick_save_clipboard = function()
	return quick_save_current_clipboard(true)
end
_M.show_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(true)
end
_M.hide_menubar = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(false)
end
_M.toggle_menubar_visibility = function()
	if started ~= true then
		_M.start()
	end

	set_show_menubar(state.show_menubar ~= true)
end
_M.refresh_menubar = function()
	if started ~= true then
		_M.start()
	end

	if refresh_menubar ~= nil then
		refresh_menubar()
	end
end
_M.get_state = function()
	return {
		started = started,
		item_count = #state.items,
		items = clone_items(state.items),
		storage_path = state.storage_path,
		auto_paste = state.auto_paste == true,
		show_menubar = state.show_menubar == true,
		open_hotkey_label = open_hotkey_label(),
		quick_save_hotkey_label = quick_save_hotkey_label(),
		chooser_exists = state.chooser ~= nil,
		preview_exists = state.preview_canvas ~= nil,
		menubar_exists = state.menubar ~= nil,
		editor_exists = state.editor ~= nil,
	}
end

return _M
