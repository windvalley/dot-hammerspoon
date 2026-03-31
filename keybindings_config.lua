local _M = {}

_M.name = "keybindings_config"
_M.description = "快捷键配置"

-- 快捷键备忘单展示
_M.keybindings_cheatsheet = {
	prefix = {
		"Option",
	},
	key = "/",
	message = "Toggle Keybindings Cheatsheet",
	description = "⌥/: Toggle Keybindings Cheatsheet",
}

-- 系统管理
_M.system = {
	lock_screen = {
		prefix = { "Option" },
		key = "Q",
		message = "Lock Screen",
	},
	screen_saver = {
		prefix = { "Option" },
		key = "S",
		message = "Start Screensaver",
	},
	keep_awake = {
		prefix = { "Option" },
		key = "A",
		message = "Toggle Prevent Sleep",
		-- 是否默认开启防休眠状态
		enabled = false,
		-- 是否显示菜单栏图标
		show_menubar = false,
		-- true 时同时阻止屏幕休眠; false 时仅阻止系统休眠, 屏幕仍可熄灭
		keep_display_awake = false,
	},
	restart = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "R",
		message = "Restart Computer",
	},
	shutdown = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "S",
		message = "Shutdown Computer",
	},
}

-- 调用默认浏览器快速打开URL
_M.websites = {
	{
		prefix = { "Option" },
		key = "8",
		message = "github.com",
		target = "https://github.com/windvalley",
	},
	{
		prefix = { "Option" },
		key = "9",
		message = "google.com",
		target = "https://www.google.com",
	},
	{
		prefix = { "Option" },
		key = "7",
		message = "bing.com",
		target = "https://www.bing.com",
	},
}

-- 简体拼音
local pinyin = "com.tencent.inputmethod.wetype"
-- ABC
local abc = "com.apple.keylayout.ABC"

-- 手动切换到目标输入法
_M.manual_input_methods = {
	-- NOTE: message的值不能是中文, 会导致快捷键列表面板显示错位.
	{ prefix = { "Option" }, key = "1", input_method = abc, message = "ABC" },
	{ prefix = { "Option" }, key = "2", input_method = pinyin, message = "Pinyin" },
}

-- 自动切换App所对应的输入法, 格式: 应用的bundleID = 输入法简称
-- NOTE: 获取某个App的bundleId的方法举例: osascript -e 'id of app "chrome"'
_M.auto_input_methods = {
	["org.hammerspoon.Hammerspoon"] = pinyin,
	["com.apple.finder"] = pinyin,
	["com.apple.Spotlight"] = pinyin,
	["com.google.Chrome"] = pinyin,
	["com.postmanlabs.mac"] = pinyin,
	["com.tencent.xinWeChat"] = pinyin,
	["com.apple.mail"] = pinyin,
	["com.microsoft.Excel"] = pinyin,
	["mac.im.qihoo.net"] = pinyin,
	["md.obsidian"] = pinyin,
	["com.openai.codex"] = pinyin,
	["com.microsoft.VSCode"] = pinyin,
	["com.google.antigravity"] = pinyin,
	["com.todesktop.230313mzl4w4u92"] = pinyin,
}

-- App启动或隐藏
-- NOTE: 获取某个App的bundleId的方法举例: osascript -e 'id of app "chrome"'
_M.apps = {
	{ prefix = { "Option" }, key = "H", message = "Hammerspoon Console", bundleId = "org.hammerspoon.Hammerspoon" },
	{ prefix = { "Option" }, key = "F", message = "Finder", bundleId = "com.apple.finder" },
	{ prefix = { "Option" }, key = "I", message = "Ghostty", bundleId = "com.mitchellh.ghostty" },
	{ prefix = { "Option" }, key = "C", message = "Chrome", bundleId = "com.google.Chrome" },
	{ prefix = { "Option" }, key = "D", message = "WPS", bundleId = "com.kingsoft.wpsoffice.mac" },
	{ prefix = { "Option" }, key = "O", message = "Obsidian", bundleId = "md.obsidian" },
	{ prefix = { "Option" }, key = "M", message = "Mail", bundleId = "com.apple.mail" },
	{ prefix = { "Option" }, key = "P", message = "Postman", bundleId = "com.postmanlabs.mac" },
	{ prefix = { "Option" }, key = "E", message = "Excel", bundleId = "com.microsoft.Excel" },
	{ prefix = { "Option" }, key = "X", message = "Codex", bundleId = "com.openai.codex" },
	{ prefix = { "Option" }, key = "N", message = "Antigravity", bundleId = "com.google.antigravity" },
	{ prefix = { "Option" }, key = "V", message = "VSCode", bundleId = "com.microsoft.VSCode" },
	{ prefix = { "Option" }, key = "K", message = "Cursor", bundleId = "com.todesktop.230313mzl4w4u92" },
	{ prefix = { "Option" }, key = "J", message = "Tuitui", bundleId = "mac.im.qihoo.net" },
	{ prefix = { "Option" }, key = "W", message = "WeChat", bundleId = "com.tencent.xinWeChat" },
}

-- 窗口管理: 改变窗口位置
_M.window_position = {
	-- **************************************
	-- 居中
	center = { prefix = { "Ctrl", "Option" }, key = "C", message = "Center Window" },
	-- **************************************
	-- 左半屏
	left = { prefix = { "Ctrl", "Option" }, key = "H", message = "Left Half of Screen" },
	-- 右半屏
	right = { prefix = { "Ctrl", "Option" }, key = "L", message = "Right Half of Screen" },
	-- 上半屏
	up = { prefix = { "Ctrl", "Option" }, key = "K", message = "Up Half of Screen" },
	-- 下半屏
	down = { prefix = { "Ctrl", "Option" }, key = "J", message = "Down Half of Screen" },
	-- **************************************
	-- 左上角
	top_left = { prefix = { "Ctrl", "Option" }, key = "Y", message = "Top Left Corner" },
	-- 右上角
	top_right = { prefix = { "Ctrl", "Option" }, key = "O", message = "Top Right Corner" },
	-- 左下角
	bottom_left = { prefix = { "Ctrl", "Option" }, key = "U", message = "Bottom Left Corner" },
	-- 右下角
	bottom_right = { prefix = { "Ctrl", "Option" }, key = "I", message = "Bottom Right Corner" },
	-- **********************************
	-- 左 1/3（横屏）或上 1/3（竖屏）
	left_1_3 = {
		prefix = { "Ctrl", "Option" },
		key = "Q",
		message = "Left or Top 1/3",
	},
	-- 右 1/3（横屏）或下 1/3（竖屏）
	right_1_3 = {
		prefix = { "Ctrl", "Option" },
		key = "W",
		message = "Right or Bottom 1/3",
	},
	-- 左 2/3（横屏）或上 2/3（竖屏）
	left_2_3 = {
		prefix = { "Ctrl", "Option" },
		key = "E",
		message = "Left or Top 2/3",
	},
	-- 右 2/3（横屏）或下 2/3（竖屏）
	right_2_3 = {
		prefix = { "Ctrl", "Option" },
		key = "R",
		message = "Right or Bottom 2/3",
	},
}

-- 窗口操作: 移动窗口.
_M.window_movement = {
	-- 向上移动窗口
	to_up = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "K",
		message = "Move Upward",
	},
	-- 向下移动窗口
	to_down = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "J",
		message = "Move Downward",
	},
	-- 向左移动窗口
	to_left = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "H",
		message = "Move Leftward",
	},
	-- 向右移动窗口
	to_right = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "L",
		message = "Move Rightward",
	},
}

-- 窗口操作: 改变窗口大小
_M.window_resize = {
	-- 最大化
	max = { prefix = { "Ctrl", "Option" }, key = "M", message = "Max Window" },
	-- 等比例放大窗口
	stretch = { prefix = { "Ctrl", "Option" }, key = "=", message = "Stretch Outward" },
	-- 等比例缩小窗口
	shrink = { prefix = { "Ctrl", "Option" }, key = "-", message = "Shrink Inward" },
	-- 底边向上伸展窗口
	stretch_up = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "K",
		message = "Bottom Side Stretch Upward",
	},
	-- 底边向下伸展窗口
	stretch_down = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "J",
		message = "Bottom Side Stretch Downward",
	},
	-- 右边向左伸展窗口
	stretch_left = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "H",
		message = "Right Side Stretch Leftward",
	},
	-- 右边向右伸展窗口
	stretch_right = {
		prefix = { "Ctrl", "Option", "Command", "Shift" },
		key = "L",
		message = "Right Side Stretch Rightward",
	},
}

-- 窗口管理: 批量处理
_M.window_batch = {
	-- 最小化所有窗口.
	minimize_all_windows = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "M",
		message = "Minimize All Windows",
	},
	-- 恢复所有最小化的窗口.
	un_minimize_all_windows = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "U",
		message = "Unminimize All Windows",
	},
	-- 关闭所有窗口.
	close_all_windows = {
		prefix = { "Ctrl", "Option", "Command" },
		key = "Q",
		message = "Close All Windows",
	},
}

-- 窗口操作: 移动到上下左右或下一个显示器
_M.window_monitor = {
	to_above_screen = {
		prefix = { "Ctrl", "Option" },
		key = "up",
		message = "Move to Above Monitor",
	},
	to_below_screen = {
		prefix = { "Ctrl", "Option" },
		key = "down",
		message = "Move to Below Monitor",
	},
	to_left_screen = {
		prefix = { "Ctrl", "Option" },
		key = "left",
		message = "Move to Left Monitor",
	},
	to_right_screen = {
		prefix = { "Ctrl", "Option" },
		key = "right",
		message = "Move to Right Monitor",
	},
	to_next_screen = {
		prefix = { "Ctrl", "Option" },
		key = "space", -- 扩展显示器比较少的情况只用这个就可以.
		message = "Move to Next Monitor",
	},
}

-- 剪贴板历史
_M.clipboard = {
	enabled = true,
	-- 是否显示菜单栏图标
	show_menubar = true,
	-- 历史记录保留条数
	history_size = 80,
	-- 菜单栏主菜单里直接显示多少条最近历史，也可在菜单栏里运行时修改
	menu_history_size = 12,
	-- 超过该字节数的文本不纳入历史，避免把超大块内容塞进 hs.settings
	max_item_length = 30000,
	-- 是否同时记录图片剪贴板历史
	capture_images = true,
	-- 图片历史缓存目录，支持 ~/ 开头、绝对路径，或相对 hs.configdir 的路径
	-- 留空时自动使用 ~/Library/Caches/<当前 Hammerspoon bundle id>/clipboard_center_images
	image_cache_dir = "",
	-- 菜单栏历史项中图片缩略图边长
	image_menu_thumbnail_size = 80,
	-- chooser 打开时是否显示预览面板，兼容旧键名 image_preview_enabled
	preview_enabled = true,
	-- 预览面板宽高，兼容旧键名 image_preview_width / image_preview_height
	preview_width = 420,
	preview_height = 320,
	-- 选择 chooser 行数
	chooser_rows = 12,
	-- chooser 宽度，单位是屏幕宽度的百分比
	chooser_width = 40,
	-- 选择历史条目后是否自动执行一次 Command+V
	auto_paste = false,
	-- NOTE: message 的值建议保持英文，避免快捷键面板错位
	prefix = { "Option", "Shift" },
	key = "C",
	message = "Clipboard Center",
}

-- 文本片段管理
_M.snippets = {
	enabled = true,
	-- snippet 主存储文件路径，支持自定义，写入时使用原子替换;
	-- 建议填写 icloud 同步路径，方便更换电脑时数据也不丢失
	storage_path = "~/Documents/Hammerspoon/data/snippets.json",
	-- 最多保存多少条 snippet
	max_items = 200,
	-- 单条 snippet 正文最大字节数，避免把超大文本写进存储文件并影响使用体验
	max_content_length = 20000,
	-- 选择 chooser 行数
	chooser_rows = 12,
	-- chooser 宽度，单位是屏幕宽度的百分比
	chooser_width = 40,
	-- 选中 snippet 后是否自动粘贴到之前的前台应用
	auto_paste = true,
	-- 自动粘贴完成后是否恢复用户原来的剪贴板内容
	restore_clipboard_after_paste = true,
	-- chooser 打开时是否显示当前选中项的预览面板
	preview_enabled = true,
	-- 预览面板宽高
	preview_width = 420,
	preview_height = 320,
	-- 预览刷新轮询间隔，越小越跟手
	preview_poll_interval = 0.08,
	-- 预览中最多显示多少字符，避免超长文本导致卡顿
	preview_body_max_chars = 6000,
	-- 是否显示轻量菜单栏入口，便于快速打开 chooser 和管理常用 snippet
	show_menubar = true,
	-- 菜单栏里直接显示多少条常用 snippet（按置顶、最近使用、使用次数排序）
	menu_items = 8,
	-- 自动标题最大字符数，标题为空时取正文首行生成
	auto_title_length = 36,
	-- 内置编辑器尺寸
	editor = {
		width = 620,
		height = 480,
	},
	-- NOTE: message 的值建议保持英文，避免快捷键面板错位
	prefix = { "Option", "Shift" },
	key = "S",
	message = "Snippet Center",
	quick_save = {
		prefix = { "Option", "Shift", "Command" },
		key = "S",
		message = "Quick Save Snippet",
	},
}

-- 翻译当前选中的文本
_M.selected_text_translate = {
	enabled = true,
	-- 显示菜单栏入口，可直接在菜单中调整常用配置并持久化
	show_menubar = true,
	-- NOTE: message 的值建议保持英文，避免快捷键面板错位
	prefix = { "Option" },
	key = "R",
	message = "Translate Selection",
	-- 自动双向翻译:
	-- auto: 包含中文时翻译成 chinese_target_language，否则翻译成 target_language
	-- to_target: 始终翻译成 target_language
	translation_direction = "auto",
	-- 非中文文本默认翻译目标语言
	target_language = "简体中文",
	-- 中文文本默认翻译目标语言
	chinese_target_language = "英文",
	-- 翻译结果悬浮窗默认停留秒数；设为 0 表示不自动关闭
	popup_duration_seconds = 5,
	-- 悬浮窗主题预设，可选：
	-- paper / mist / graphite / slate / ocean
	-- forest / amber / rose / cocoa / mint
	popup_theme = "slate",
	-- 悬浮窗透明度，单独控制；0 为全透明，1 为不透明
	popup_background_alpha = 0.88,
	-- 兼容旧写法：popup_background 或 popup_background_color
	-- popup_background = "#FAFAFA",
	-- 选区无法直接读取时，模拟复制后等待剪贴板更新的轮询参数
	clipboard_poll_interval_seconds = 0.05,
	clipboard_max_wait_seconds = 0.4,
	-- 某些终端（例如 Ghostty / zellij）选中文本后会自动写入剪贴板，可直接读取当前剪贴板
	selection_auto_copy_by_bundle_id = {
		["com.mitchellh.ghostty"] = true,
	},
	-- 如果某个应用不是自动复制，而是使用特殊复制键，可在这里按 bundle id 指定
	-- copy_shortcuts_by_bundle_id = {
	-- 	["com.example.Terminal"] = {
	-- 		modifiers = { "Command", "Shift" },
	-- 		key = "c",
	-- 	},
	-- },
	-- 模型服务配置
	model_service = {
		-- 可选: ollama / openai_compatible / gemini / anthropic
		provider = "ollama",
		-- 请求超时秒数
		request_timeout_seconds = 20,
		ollama = {
			api_url = "http://localhost:11434/api/chat",
			model = "qwen3.5:35b",
			-- 启动后静默预热一次本地模型，减少首次翻译冷启动延迟
			enable_warmup = true,
			-- 表示模型在最后一次请求后尽量保活 30 分钟
			keep_alive = "30m",
			-- 对支持 thinking 的本地模型，默认关闭 thinking 以提升响应速度
			disable_thinking = true,
		},
		openai_compatible = {
			api_url = "https://api.openai.com/v1/chat/completions",
			model = "gpt-4o-mini",
			-- 优先从这个环境变量读取 API Key；也可以留空后在菜单栏里直接填写并持久化
			api_key_env = "OPENAI_API_KEY",
			api_key = "",
		},
		gemini = {
			-- 支持写成基础 models 路径，模块会自动拼上 /{model}:generateContent
			api_url = "https://generativelanguage.googleapis.com/v1beta/models",
			model = "gemini-3-flash-preview",
			api_key_env = "GEMINI_API_KEY",
			api_key = "",
		},
		anthropic = {
			api_url = "https://api.anthropic.com/v1/messages",
			model = "claude-3-5-haiku-latest",
			api_key_env = "ANTHROPIC_API_KEY",
			api_key = "",
		},
	},
}

-- 录屏/演示场景下的按键可视化
_M.key_caster = {
	-- 默认关闭，按需启用，避免日常输入时持续显示按键浮层
	enabled = false,
	-- auto: 启用时自动显示图标，关闭时自动隐藏
	-- true: 始终显示图标
	-- false: 始终隐藏图标
	show_menubar = "auto",
	position = {
		anchor = "bottom_center",
		offset_x = 0,
		offset_y = 140,
	},
	toggle_hotkey = {
		prefix = { "Command", "Ctrl" },
		key = "K",
		message = "Toggle Key Caster",
	},
	font = {
		name = "Menlo Bold",
		size = 44,
	},
	text_color = {
		hex = "#F8FAFC",
		alpha = 1,
	},
	background_color = {
		hex = "#111827",
		alpha = 0.78,
	},
	-- single: 每次只显示当前按键
	-- sequence: 短时间连续输入字母时拼接显示
	display_mode = "sequence",
	-- sequence 模式下，连续输入字母会在该时间窗口内拼接
	sequence_window_seconds = 0.5,
	duration_seconds = 1.2,
}

-- Bing Daily Picture 壁纸
_M.bing_daily_wallpaper = {
	enabled = true,
	-- 定时检查 Bing 当日壁纸的周期，单位秒
	refresh_interval_seconds = 60 * 60,
	-- 请求壁纸尺寸
	picture_width = 3072,
	picture_height = 1920,
	-- 拉取最近多少天的 Bing 壁纸元数据
	-- 为 1 时始终使用当天壁纸；大于 1 时会从最近几天里随机选一张
	history_count = 1,
	-- 元数据接口和图片下载的基础地址
	metadata_base_url = "https://cn.bing.com",
	image_base_url = "https://www.bing.com",
	-- 缓存目录，支持 ~/ 开头、绝对路径，或相对 hs.configdir 的路径
	-- 留空时自动使用 ~/Library/Caches/<当前 Hammerspoon bundle id>/bing_daily_wallpaper
	cache_dir = "",
}

-- 强制休息提醒
-- 说明:
-- 1. 锁屏期间不计入工作时长
-- 2. 锁屏、熄屏或系统睡眠恢复后会重新开始新一轮工作计时
_M.break_reminder = {
	enabled = true,
	-- 是否显示菜单栏图标, 可通过菜单直接调整提醒配置
	show_menubar = true,
	-- 菜单栏图标皮肤: coffee / hourglass / bars
	menubar_skin = "hourglass",
	-- 休息结束后如何开始下一轮工作计时
	-- auto: 休息结束立即开始
	-- on_input: 等待首次键盘或鼠标输入后开始
	start_next_cycle = "on_input",
	-- 可选: "soft" 或 "hard"
	-- soft: 显示半透明遮罩但不抢占鼠标和键盘
	-- hard: 显示遮罩并明确拦截鼠标和键盘
	mode = "soft",
	-- 遮罩透明度, 范围 0~1
	-- 默认值: soft=0.32, hard=0.96
	overlay_opacity = 0.32,
	-- true 时仅显示简洁图标，不显示倒计时和说明文字
	minimal_display = true,
	-- 每日专注目标, 达到后计入连续达标天数
	focus_goal_minutes = 240,
	-- 每日完成多少次休息算达到休息目标; 0 表示禁用
	break_goal_count = 8,
	-- 当日跳过休息达到该次数后, 自动切换为硬性提醒; 0 表示禁用
	strict_mode_after_skips = 2,
	-- 每跳过一次休息, 为后续每次休息额外增加的惩罚秒数
	rest_penalty_seconds_per_skip = 30,
	-- 跳过惩罚累计上限, 单位为秒
	max_rest_penalty_seconds = 300,
	-- 友好提示文案模板
	-- 可用占位符: {{remaining}} {{remaining_seconds}} {{remaining_mmss}} {{rest}} {{rest_seconds}} {{rest_mmss}}
	friendly_reminder_message = "还有 {{remaining}} 开始休息",
	-- 友好提示默认停留秒数, 0 表示不自动关闭, 只允许手动点 x 关闭
	friendly_reminder_duration_seconds = 10,
	-- 距离休息还有多少秒时做一次友好提示, 0 为禁用
	friendly_reminder_seconds = 120,
	-- 单位: 分钟
	work_minutes = 28,
	-- 单位: 秒
	rest_seconds = 120,
}

return _M
