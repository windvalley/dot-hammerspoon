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

local log = hs.logger.new("snippet")

local items_settings_key = "snippet_center.items"
local default_max_items = math.max(10, math.floor(tonumber(snippets.max_items) or 200))
local default_max_content_length = math.max(200, math.floor(tonumber(snippets.max_content_length) or 20000))
local default_chooser_rows = math.max(6, math.floor(tonumber(snippets.chooser_rows) or 12))
local default_chooser_width = math.max(20, math.floor(tonumber(snippets.chooser_width) or 40))
local default_auto_paste = snippets.auto_paste ~= false
local default_restore_clipboard_after_paste = snippets.restore_clipboard_after_paste ~= false
local default_auto_title_length = math.max(12, math.floor(tonumber(snippets.auto_title_length) or 36))
local default_editor_width = math.max(420, math.floor(tonumber((snippets.editor or {}).width) or 620))
local default_editor_height = math.max(300, math.floor(tonumber((snippets.editor or {}).height) or 480))
local auto_paste_delay_seconds = 0.12
local clipboard_restore_delay_seconds = 0.35
local history_suspend_seconds = 2
local detail_preview_length = 72
local title_preview_length = 40
local editor_port_name = "snippetEditor"

local started = false
local item_id_counter = 0

local state = {
	items = {},
	chooser = nil,
	open_hotkey = nil,
	quick_save_hotkey = nil,
	target_application = nil,
	editor = nil,
	editor_controller = nil,
	editor_context = nil,
}

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
	if type(hs.settings) ~= "table" or type(hs.settings.set) ~= "function" then
		return
	end

	hs.settings.set(items_settings_key, clone_items(state.items))
end

local function load_items()
	if type(hs.settings) ~= "table" or type(hs.settings.get) ~= "function" then
		return {}
	end

	local stored_items = hs.settings.get(items_settings_key)
	local items = {}
	local seen_ids = {}

	for _, raw_item in ipairs(stored_items or {}) do
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
		},
		{
			id = "new_from_clipboard",
			text = "从当前剪贴板新建",
			subText = "直接保存当前剪贴板文本为 snippet，标题将自动生成",
		},
	}

	for _, action in ipairs(actions) do
		if action_matches(query, action.text, action.subText) == true then
			table.insert(choices, {
				text = action.text,
				subText = action.subText,
				source = "action",
				action = action.id,
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
	persist_items()
	refresh_chooser_choices(true)

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

	item.title = next_title
	item.content = next_content
	item.updated_at = current_timestamp()

	state.items[index] = item
	persist_items()
	refresh_chooser_choices(true)

	return true, item
end

local function delete_item(item_id)
	local index = find_item_index_by_id(item_id)

	if index == nil then
		return false
	end

	table.remove(state.items, index)
	persist_items()
	refresh_chooser_choices(true, index)

	return true
end

local function mark_item_used(item_id)
	local item = find_item_by_id(item_id)

	if item == nil then
		return
	end

	item.last_used_at = current_timestamp()
	item.use_count = math.max(0, math.floor(tonumber(item.use_count) or 0)) + 1
	persist_items()
end

local function set_item_pinned(item_id, pinned)
	local item = find_item_by_id(item_id)

	if item == nil then
		return false
	end

	item.pinned = pinned == true
	item.updated_at = current_timestamp()
	persist_items()
	refresh_chooser_choices(true)

	return true
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

	item.title = trim(next_title)
	item.updated_at = current_timestamp()
	persist_items()
	refresh_chooser_choices(true)
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

	if type(hs.webview.newBrowser) == "function" then
		editor = hs.webview.newBrowser(frame, {
			developerExtrasEnabled = false,
		}, controller)
	elseif type(hs.webview.new) == "function" then
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

	if type(editor.closeOnEscape) == "function" then
		editor:closeOnEscape(true)
	end

	if type(editor.deleteOnClose) == "function" then
		editor:deleteOnClose(true)
	end

	if type(editor.windowCallback) == "function" then
		editor:windowCallback(function(action)
			if action ~= "closing" then
				return
			end

			local context = state.editor_context

			state.editor = nil
			state.editor_controller = nil
			state.editor_context = nil

			schedule_reopen_chooser(context)
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

	if type(editor.bringToFront) == "function" then
		pcall(editor.bringToFront, editor, true)
	end

	return true
end

local function activate_item(item_id)
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

	if default_auto_paste ~= true then
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
				local next_pinned = item.pinned ~= true
				set_item_pinned(item.id, next_pinned)
				hs.alert.show(next_pinned == true and "已置顶" or "已取消置顶")
			end,
		},
		{
			title = "复制到剪贴板",
			fn = function()
				if write_text_to_clipboard(item.content) == true then
					hs.alert.show("已复制到剪贴板")
				else
					hs.alert.show("写入剪贴板失败")
				end
			end,
		},
		{ title = "-" },
		{
			title = "删除",
			fn = function()
				if delete_item(item.id) == true then
					hs.alert.show("已删除 snippet")
				else
					hs.alert.show("删除 snippet 失败")
				end
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
	end)
	state.chooser:queryChangedCallback(function()
		local selected_row = state.chooser:selectedRow() or 0
		refresh_chooser_choices(true, selected_row)
	end)
	state.chooser:rightClickCallback(function(row)
		show_chooser_context_menu(row)
	end)

	return true
end

local function destroy_chooser()
	if state.chooser == nil then
		return
	end

	if type(state.chooser.hide) == "function" then
		pcall(state.chooser.hide, state.chooser)
	end

	if type(state.chooser.delete) == "function" then
		pcall(state.chooser.delete, state.chooser)
	end

	state.chooser = nil
end

local function bind_hotkey(hotkey_config, fallback_message, fn)
	local key = hotkey_config and hotkey_config.key or nil

	if key == nil then
		return true, nil
	end

	local binding = hotkey_helper.bind(
		copy_list(hotkey_config.prefix or {}),
		key,
		hotkey_config.message or fallback_message,
		fn,
		nil,
		nil,
		{ logger = log }
	)

	if binding == nil then
		return false, "bind failed"
	end

	return true, binding
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

show_chooser = function()
	if started ~= true then
		if _M.start() ~= true then
			return
		end
	end

	if state.chooser == nil then
		return
	end

	state.target_application = current_frontmost_application()
	state.chooser:choices(build_choices())
	state.chooser:query(nil)

	local screen_frame = resolve_target_screen_frame()

	if screen_frame ~= nil and type(hs.geometry) == "table" and type(hs.geometry.point) == "function" then
		local chooser_width = math.floor(screen_frame.w * default_chooser_width / 100)
		local chooser_height = 94 + (42 * default_chooser_rows)
		local point = hs.geometry.point(
			screen_frame.x + math.floor((screen_frame.w - chooser_width) / 2),
			screen_frame.y + math.floor((screen_frame.h - chooser_height) / 2)
		)

		state.chooser:show(point)
	else
		state.chooser:show()
	end
end

function _M.start()
	if started == true then
		return true
	end

	started = true
	state.items = load_items()

	if snippets.enabled == false then
		return true
	end

	if setup_chooser() ~= true then
		started = false
		return false
	end

	local open_ok, open_binding = bind_hotkey(snippets, "Snippet Center", function()
		show_chooser()
	end)

	if open_ok ~= true then
		destroy_chooser()
		started = false
		return false
	end

	local quick_save_ok, quick_save_binding = bind_hotkey(snippets.quick_save or {}, "Quick Save Snippet", function()
		quick_save_current_clipboard(true)
	end)

	if quick_save_ok ~= true then
		if open_binding ~= nil then
			open_binding:delete()
		end

		destroy_chooser()
		started = false
		return false
	end

	state.open_hotkey = open_binding
	state.quick_save_hotkey = quick_save_binding

	return true
end

function _M.stop()
	delete_bindings()
	destroy_chooser()
	close_editor()
	state.items = {}
	state.target_application = nil
	started = false

	return true
end

_M.show_chooser = show_chooser
_M.quick_save_clipboard = function()
	return quick_save_current_clipboard(true)
end
_M.get_state = function()
	return {
		started = started,
		item_count = #state.items,
		items = clone_items(state.items),
		chooser_exists = state.chooser ~= nil,
		editor_exists = state.editor ~= nil,
	}
end

return _M
