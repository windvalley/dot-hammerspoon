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
		show_menubar = true,
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
	["org.alacritty"] = pinyin,
	["dev.warp.Warp-Stable"] = pinyin,
	["com.google.Chrome"] = pinyin,
	["org.virtualbox.app.VirtualBox"] = pinyin,
	["com.postmanlabs.mac"] = pinyin,
	["com.tencent.xinWeChat"] = pinyin,
	["com.apple.mail"] = pinyin,
	["com.microsoft.Excel"] = pinyin,
	["mac.im.qihoo.net"] = pinyin,
	["ynote-desktop"] = pinyin,
	["md.obsidian"] = pinyin,
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
	{ prefix = { "Option" }, key = "N", message = "Antigravity", bundleId = "com.google.antigravity" },
	{ prefix = { "Option" }, key = "D", message = "WPS", bundleId = "com.kingsoft.wpsoffice.mac" },
	{ prefix = { "Option" }, key = "O", message = "Obsidian", bundleId = "md.obsidian" },
	{ prefix = { "Option" }, key = "M", message = "Mail", bundleId = "com.apple.mail" },
	{ prefix = { "Option" }, key = "P", message = "Postman", bundleId = "com.postmanlabs.mac" },
	{ prefix = { "Option" }, key = "E", message = "Excel", bundleId = "com.microsoft.Excel" },
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

-- 剪贴板历史 + Snippets
_M.clipboard = {
	enabled = true,
	-- 是否显示菜单栏图标
	show_menubar = true,
	-- 历史记录保留条数
	history_size = 80,
	-- 菜单栏里显示多少条最近历史
	menu_history_size = 12,
	-- 超过该字节数的文本不纳入历史，避免把超大块内容塞进 hs.settings
	max_item_length = 30000,
	-- 是否同时记录图片剪贴板历史
	capture_images = true,
	-- 图片历史缓存目录，支持 ~/ 开头、绝对路径，或相对 hs.configdir 的路径
	-- 留空时自动使用 ~/Library/Caches/<当前 Hammerspoon bundle id>/clipboard_center_images
	image_cache_dir = "",
	-- 菜单历史子菜单中图片缩略图边长
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
	-- NOTE: message 的值建议保持英文，避免快捷键面板错位
	prefix = { "Option", "Shift" },
	key = "V",
	message = "Clipboard Center",
	snippets = {
		{
			group = "常用文本",
			title = "日报同步",
			description = "简短同步当前进度",
			content = "进展同步：当前已完成核心部分，剩余收尾和验证，预计今天内交付。",
		},
		{
			group = "常用 Prompt",
			title = "代码评审",
			description = "让模型按风险优先级做 review",
			content = [[请以代码评审视角回答，优先指出：
1. 明确的 bug
2. 行为回归风险
3. 边界条件遗漏
4. 缺失的测试

如果没有明显问题，请直接说明 residual risk 和 testing gap。]],
		},
		{
			group = "常用 Prompt",
			title = "需求拆解",
			description = "先澄清边界再给方案",
			content = [[请先拆解目标、约束、输入输出和边界条件，再给出实现方案。
如果存在关键不确定项，请先列出需要确认的问题。]],
		},
	},
}

-- 强制休息提醒
-- 说明:
-- 1. 锁屏期间不计入工作时长
-- 2. 解锁屏幕后会重新开始新一轮工作计时
_M.break_reminder = {
	enabled = true,
	-- 是否显示菜单栏图标, 可通过菜单直接调整提醒配置
	show_menubar = true,
	-- 是否在菜单栏图标中直接显示当前进度
	-- 关闭后切换为更简洁的纯图标版, 不显示外环
	-- 开启后工作阶段显示进度环, 休息阶段显示剩余倒计时环
	show_progress_in_menubar = true,
	-- 菜单栏图标皮肤: coffee / hourglass / bars
	menubar_skin = "coffee",
	-- 休息结束后如何开始下一轮工作计时
	-- auto: 休息结束立即开始
	-- on_input: 等待首次键盘或鼠标输入后开始
	start_next_cycle = "auto",
	-- 可选: "soft" 或 "hard"
	-- soft: 显示半透明遮罩但不抢占鼠标和键盘
	-- hard: 显示遮罩并明确拦截鼠标和键盘
	mode = "hard",
	-- 遮罩透明度, 范围 0~1
	-- 默认值: soft=0.32, hard=0.96
	overlay_opacity = 0.96,
	-- true 时仅显示简洁图标，不显示倒计时和说明文字
	minimal_display = true,
	-- 每日专注目标, 达到后计入连续达标天数
	focus_goal_minutes = 120,
	-- 每日完成多少次休息算达到休息目标; 0 表示禁用
	break_goal_count = 4,
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
