# dot-hammerspoon

[English](README.md) | [简体中文](README.zh.md)

![Language](https://img.shields.io/badge/language-Lua-orange)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
[![Version](https://img.shields.io/github/v/release/windvalley/dot-hammerspoon?include_prereleases)](https://github.com/windvalley/dot-hammerspoon/releases)
[![LICENSE](https://img.shields.io/github/license/windvalley/dot-hammerspoon)](LICENSE)
![Page Views](https://views.whatilearened.today/views/github/windvalley/dot-hammerspoon.svg)

`dot-hammerspoon` 是我个人使用的 [Hammerspoon](http://www.hammerspoon.org/) 配置，你可以按自己的习惯继续修改和扩展。

## 功能特性

- 应用快速启动或隐藏。
- 应用窗口管理，包括移动、缩放、调整位置等。
- 系统管理，例如锁屏、重启、关机等。
- 通过菜单栏状态图标让 Mac 保持唤醒，适合长时间工作。
- 根据应用自动切换输入法。
- 快速切换到指定输入法。
- 直接打开指定网站。
- 带菜单栏和选择器界面的剪贴板历史。
- 使用兼容 OpenAI 的模型翻译选中文本，并用弹窗展示结果。
- 一键显示快捷键速查表。
- 将桌面壁纸同步为必应每日图片。
- 可配置的强制休息提醒，支持软提醒和硬提醒。
- 通过每日专注统计、连续达标、跳过惩罚和可换肤菜单栏图标，让休息提醒更有反馈感。
- 在录屏或演示时用屏幕浮层显示按键。
- Lua 文件变化后自动重载配置。
- 代码结构清晰，便于裁剪成你自己的配置。

## 安装

1. 先安装 [Hammerspoon](http://www.hammerspoon.org/)：`brew install hammerspoon --cask`

2. 运行 `Hammerspoon.app`，根据提示为应用开启辅助功能权限。

如果没有授予辅助功能权限，启动时会出现警告提示，而且依赖输入或窗口控制的模块可能无法正常工作，例如窗口管理、休息提醒硬模式和 Key Caster。

3. `git clone --depth 1 https://github.com/windvalley/dot-hammerspoon.git ~/.hammerspoon`

保持更新：

```sh
cd ~/.hammerspoon && git pull
```

## 使用

### 打开快捷键速查表

![toggle-keybindings-cheatsheet](https://user-images.githubusercontent.com/6139938/213378139-2d005ac0-bce3-4798-a8b5-e2c23fd5817c.gif)

<kbd>⌥</kbd> + <kbd>/</kbd>

### 切换到指定输入法

- <kbd>⌥</kbd> + <kbd>1</kbd>: ABC
- <kbd>⌥</kbd> + <kbd>2</kbd>: Pinyin

### 系统管理

- <kbd>⌥</kbd> + <kbd>A</kbd>: 切换防止休眠
- <kbd>⌥</kbd> + <kbd>Q</kbd>: 锁屏
- <kbd>⌥</kbd> + <kbd>S</kbd>: 启动屏保
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>R</kbd>: 重启电脑
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>S</kbd>: 关机

### 防止休眠

使用菜单栏图标或 <kbd>⌥</kbd> + <kbd>A</kbd>，可以在长时间任务期间阻止空闲休眠。

- `enabled`：防止休眠模式默认是否开启。
- `show_menubar`：是否显示菜单栏图标，便于查看状态和快速切换。
- `keep_display_awake`：为 `true` 时同时阻止系统休眠和显示器休眠；为 `false` 时仅阻止系统空闲休眠，显示器仍可关闭。
- 菜单栏菜单可以在运行时切换 `keep_display_awake`。
- 菜单栏菜单也可以在运行时修改切换快捷键。
- 菜单栏菜单可以临时隐藏当前 Hammerspoon 会话中的菜单栏图标；执行 `hs.reload()` 后会恢复为配置文件默认值。
- 也可以在 Hammerspoon Console 中调用 `package.loaded.keep_awake.show_menubar()` 或 `package.loaded.keep_awake.toggle_menubar_visibility()` 来恢复或切换菜单栏图标。
- 当前开关状态会在 Hammerspoon 重载后恢复为配置默认值。
- `keep_display_awake` 模式和切换快捷键会通过 `hs.settings` 在重载后继续保留。

### 网站直达

- <kbd>⌥</kbd> + <kbd>8</kbd>: github.com
- <kbd>⌥</kbd> + <kbd>9</kbd>: google.com
- <kbd>⌥</kbd> + <kbd>7</kbd>: bing.com

### 必应每日壁纸

壁纸模块会定期拉取必应每日图片元数据，并把所选图片应用到所有屏幕。

可以在 `~/.hammerspoon/keybindings_config.lua` 中这样配置：

```lua
_M.bing_daily_wallpaper = {
	enabled = true,
	refresh_interval_seconds = 60 * 60,
	picture_width = 3072,
	picture_height = 1920,
	history_count = 1,
	metadata_base_url = "https://cn.bing.com",
	image_base_url = "https://www.bing.com",
	cache_dir = "",
}
```

当 `cache_dir` 为空时，Bing Daily Wallpaper 会自动使用：

`~/Library/Caches/<current Hammerspoon bundle id>/bing_daily_wallpaper`

当 `history_count` 大于 `1` 时，模块会从元数据 API 返回的最近几张必应壁纸中随机挑选一张。

### Clipboard Center

![clipboard-center](docs/screenshots/clipboard-center.png)

使用菜单栏项或 <kbd>⌥</kbd><kbd>⇧</kbd> + <kbd>C</kbd> 打开一个可搜索的选择器，用来查看：

- 剪贴板历史
- 剪贴板图片

可以在 `~/.hammerspoon/keybindings_config.lua` 中这样配置：

```lua
_M.clipboard = {
	enabled = true,
	show_menubar = true,
	history_size = 80,
	menu_history_size = 12,
	max_item_length = 30000,
	capture_images = true,
	image_cache_dir = "",
	preview_enabled = true,
	preview_width = 420,
	preview_height = 320,
	image_menu_thumbnail_size = 80,
	chooser_rows = 12,
	chooser_width = 40,
	auto_paste = false,
	prefix = { "Option", "Shift" },
	key = "C",
	message = "Clipboard Center",
}
```

当 `image_cache_dir` 为空时，Clipboard Center 会自动使用：

`~/Library/Caches/<current Hammerspoon bundle id>/clipboard_center_images`

当选择器中的某一项被高亮时，Clipboard Center 会在右侧显示更大的预览面板。你可以通过 `preview_enabled`、`preview_width` 和 `preview_height` 调整它。旧版 `image_preview_*` 配置项仍然保留兼容。

`hs.chooser` 内的图片缩略图尺寸固定较小，因为原生 chooser 的行高基本不可变。如果需要更大的图像预览，请使用右侧的预览面板。

历史项支持单独删除：可以在 chooser 中右键点击某一行，或在菜单栏菜单里按住 `⌘` 再点击对应项。

菜单栏菜单打开时，最近的前九条历史还可以直接通过数字键 `1` 到 `9` 恢复。

`menu_history_size` 控制菜单栏里直接显示多少条最近历史。你也可以通过菜单里的 `最近历史显示数量` 在运行时修改，它会通过 `hs.settings` 持久化。

菜单栏菜单还可以在运行时修改 Clipboard Center 的快捷键。覆盖值会通过 `hs.settings` 保存，并且可以在同一个菜单里恢复成文件配置中的快捷键。

菜单栏菜单还提供 `自动粘贴` 开关。默认关闭；开启后，选择某条剪贴板历史会先恢复该内容，再向先前聚焦的应用发送 <kbd>⌘</kbd> + <kbd>V</kbd>。这个运行时覆盖值同样会通过 `hs.settings` 持久化。

`chooser_rows` 控制 chooser 显示的行数，`chooser_width` 控制 chooser 宽度占当前屏幕的百分比。

### Snippet Center（文本片段）

使用 <kbd>⌥</kbd><kbd>⇧</kbd> + <kbd>S</kbd> 打开一个可搜索的选择器，管理保存过的文本片段。前两行是内置动作：

- 在内置多行编辑器中新建一个空白片段
- 把当前剪贴板文本保存为新的片段

选择某个片段后，会先写入粘贴板，重新激活之前聚焦的应用，然后发送 <kbd>⌘</kbd> + <kbd>V</kbd>。默认情况下，粘贴完成后会恢复原始剪贴板内容。

使用 <kbd>⌥</kbd><kbd>⇧</kbd><kbd>⌘</kbd> + <kbd>S</kbd> 可以直接快速保存当前剪贴板文本，而无需打开 chooser。重复内容会被拒绝保存。

片段标题是可选的。如果标题留空，chooser 会自动使用正文第一行非空内容作为显示标题。

在 chooser 中右键片段行，可以编辑、重命名、置顶、复制或删除。

当 chooser 打开时，Snippet Center 还会为当前选中行显示一个预览面板。对已保存的片段来说，预览会包含完整正文，便于在插入前查看多行内容。你可以通过 `preview_enabled`、`preview_width`、`preview_height`、`preview_poll_interval` 和 `preview_body_max_chars` 调整行为。

片段数据存储在 JSON 文件中，而不是 `hs.settings`。你可以通过 `storage_path` 自定义文件位置，便于跨设备迁移。写入时会先写临时文件，再做原子重命名，正常保存不会留下半写入状态。

如果启用了 `show_menubar`，Snippet Center 还会增加一个轻量级菜单栏入口，用于：

- 打开 chooser
- 新建空白片段
- 保存当前剪贴板文本
- 切换 `auto_paste`
- 通过子菜单管理少量常用片段

菜单栏里只显示有限数量的片段，由 `menu_items` 控制。这些条目和 chooser 使用相同的排序规则：置顶优先，其次是最近使用和高频使用。菜单栏中对 `auto_paste` 的运行时修改会通过 `hs.settings` 持久化。

菜单栏还会显示打开 chooser 和快速保存剪贴板的当前快捷键，并允许你在运行时修改或恢复这两个快捷键。这些快捷键覆盖值同样会通过 `hs.settings` 持久化。

可以在 `~/.hammerspoon/keybindings_config.lua` 中这样配置：

```lua
_M.snippets = {
	enabled = true,
	storage_path = "~/.hammerspoon/data/snippets.json",
	max_items = 200,
	max_content_length = 20000,
	chooser_rows = 12,
	chooser_width = 40,
	auto_paste = true,
	restore_clipboard_after_paste = true,
	preview_enabled = true,
	preview_width = 420,
	preview_height = 320,
	preview_poll_interval = 0.08,
	preview_body_max_chars = 6000,
	show_menubar = true,
	menu_items = 8,
	auto_title_length = 36,
	editor = {
		width = 620,
		height = 480,
	},
	prefix = { "Option", "Shift" },
	key = "S",
	message = "Snippet Center",
	quick_save = {
		prefix = { "Option", "Shift", "Command" },
		key = "S",
		message = "Quick Save Snippet",
	},
}
```

你也可以在 Hammerspoon Console 中调用 `package.loaded.snippet_center.show_menubar()`、`package.loaded.snippet_center.hide_menubar()` 和 `package.loaded.snippet_center.toggle_menubar_visibility()` 来控制菜单栏入口。

### 选中文本翻译

![selected-text-translate](docs/screenshots/selected-text-translate.png)

选中任意文本后按 <kbd>⌥</kbd> + <kbd>R</kbd>，即可通过兼容 OpenAI 的 `chat/completions` API 进行翻译。默认情况下，非中文文本会被翻译为简体中文；包含中文字符的文本会被翻译成英文。翻译结果会显示在弹窗中，弹窗里也可以把结果复制回剪贴板。

模块会优先直接读取当前辅助功能选区。如果失败，它可以读取那些会自动复制选区的应用当前剪贴板，或者模拟一次复制快捷键，然后再恢复之前的剪贴板内容。默认回退快捷键是 <kbd>⌘</kbd> + <kbd>C</kbd>。当 Clipboard Center 启用时，这段临时的复制/恢复流程也会被从剪贴板历史里抑制掉。

模块还会增加一个菜单栏入口，你可以在运行时调整主要设置，并通过 `hs.settings` 保存下来，包括快捷键、翻译方向、目标语言、弹窗主题、弹窗时长，以及按 provider 分组的模型服务设置（`api_url`、`model` 和本地保存的 API key）。菜单里的 `恢复默认` 会清除这些覆盖项，并回退到 `keybindings_config.lua`。

可以在 `~/.hammerspoon/keybindings_config.lua` 中这样配置：

```lua
_M.selected_text_translate = {
	enabled = true,
	show_menubar = true,
	prefix = { "Option" },
	key = "R",
	message = "Translate Selection",
	translation_direction = "auto",
	target_language = "简体中文",
	chinese_target_language = "英文",
	popup_duration_seconds = 10,
	popup_theme = "paper",
	popup_background_alpha = 0.88,
	clipboard_poll_interval_seconds = 0.05,
	clipboard_max_wait_seconds = 0.4,
	selection_auto_copy_by_bundle_id = {
		["com.mitchellh.ghostty"] = true,
	},
	model_service = {
		provider = "ollama",
		request_timeout_seconds = 20,
		ollama = {
			api_url = "http://localhost:11434/api/chat",
			model = "qwen3.5:35b",
			enable_warmup = true,
			keep_alive = "30m",
			disable_thinking = true,
		},
		openai_compatible = {
			api_url = "https://api.openai.com/v1/chat/completions",
			model = "gpt-4o-mini",
			api_key_env = "OPENAI_API_KEY",
			api_key = "",
		},
		gemini = {
			api_url = "https://generativelanguage.googleapis.com/v1beta/models",
			model = "gemini-2.0-flash",
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
```

翻译弹窗支持轻量的浮动卡片样式。默认会在 `popup_duration_seconds` 后自动隐藏；当鼠标悬停在弹窗上时，自动隐藏会暂停，鼠标移开后继续计时。

`selection_auto_copy_by_bundle_id` 用来告诉模块：对某些应用可以直接信任当前剪贴板。对于 Ghostty 这类已经自动复制选中文本的终端，这很有用，也适用于常见的 zellij 场景。

如果某个应用不会自动复制，但使用了非标准复制快捷键，也可以通过 `copy_shortcuts_by_bundle_id` 为不同 bundle ID 覆盖回退复制快捷键。

`popup_theme` 现在使用预设主题，`popup_background_alpha` 单独控制透明度。内置主题有：`paper`、`mist`、`graphite`、`slate`、`ocean`、`forest`、`amber`、`rose`、`cocoa`、`mint`。

旧版的 `popup_background = "#RRGGBB"` / `"#RRGGBBAA"` 和 `popup_background_color` 仍然兼容，但更推荐使用预设主题，因为它会同时协调背景、边框、文字和复制按钮的配色。

`translation_direction = "auto"` 会启用双向翻译：当选中文本包含中文字符时，目标语言使用 `chinese_target_language`；否则使用 `target_language`。如果想保留以前的固定行为，可以改为 `translation_direction = "to_target"`。

菜单预设里的 `中文目标语言` 故意不包含 `简体中文`，以避免同语言翻译没有实际效果。如果你确实需要特殊场景，可以通过自定义选项手动输入。

`model_service.provider` 支持 `ollama`、`openai_compatible`、`gemini` 和 `anthropic`。当前选中的 provider 决定实际使用哪个子配置块中的 `api_url`、`model` 和 API 凭据。在菜单栏里，这些设置会按 provider 分组，因此你可以查看或修改其他 provider 的配置，而不必先切换当前 provider。

对于本地 Ollama 模型，`model_service.ollama.enable_warmup = true` 会在启动几秒后悄悄发送一次轻量预热请求，减少第一次翻译的等待时间。`model_service.ollama.keep_alive = "30m"` 会把 Ollama 的 `keep_alive` 选项同时附加到预热请求和正常翻译请求上，让模型在使用后更久地保持加载。`model_service.ollama.disable_thinking = true` 还会默认发送 `think = false`，以加快响应。

对于 Gemini，默认 `api_url` 可以保持在基础 `/models` 路径上；模块会自动扩展为当前模型对应的 `/{model}:generateContent`。Anthropic 直接使用 `/v1/messages`。

对于需要 API key 的 provider，你可以把文件配置里的 `api_key` 留空，然后通过菜单栏保存密钥。该值会通过 `hs.settings` 持久化到本地，重启后依然可用。如果你更喜欢环境变量，针对 GUI 启动的 Hammerspoon，可以这样设置：

```sh
launchctl setenv OPENAI_API_KEY "your-api-key"
launchctl setenv GEMINI_API_KEY "your-api-key"
launchctl setenv ANTHROPIC_API_KEY "your-api-key"
```

然后重启 Hammerspoon，让应用重新读取这些变量。

### Key Caster（按键显示）

![key-caster](docs/screenshots/key-caster.png)

Key Caster 适合录屏或现场演示。启用后，它会监听键盘事件，并在当前屏幕上用浮层显示最近一次按键组合。

它支持轻量的运行时控制：默认用 `⌃⌘K` 在当前 Hammerspoon 会话里切换开关，菜单栏入口则支持 `auto`、`true` 和 `false` 三种可见性模式。

可以在 `~/.hammerspoon/keybindings_config.lua` 中启用或调整：

```lua
_M.key_caster = {
	enabled = false,
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
	display_mode = "single",
	sequence_window_seconds = 0.4,
	duration_seconds = 1.2,
}
```

- `enabled`：Hammerspoon 重载后是否默认开启浮层。默认关闭，避免日常使用时造成视觉干扰。
- `show_menubar`：支持 `auto`、`true`、`false`。`auto` 仅在 Key Caster 启用时显示菜单栏入口；`true` 始终显示；运行时改动只在当前会话生效，`hs.reload()` 后重置。
- `toggle_hotkey`：配置运行时开关快捷键。设置 `key = ""` 可以彻底禁用快捷键。
- `position.anchor`：支持 `top_left`、`top_center`、`top_right`、`center`、`bottom_left`、`bottom_center`、`bottom_right`。
- `position.offset_x` 和 `position.offset_y`：相对锚点微调浮层位置。
- `font`：配置显示字体和字号。
- `text_color` 和 `background_color`：配置浮层颜色和透明度。
- `display_mode`：`single` 保持原有行为，只显示最近一次按键；`sequence` 会把连续输入的普通字母拼接成一小段文本。
- `sequence_window_seconds`：仅在 `sequence` 模式下使用；在这个时间窗口内输入的字母会被归并进同一个浮层。
- `duration_seconds`：每次按键浮层停留多久后消失。
- 菜单栏菜单提供运行时 UI，可用于启用或禁用 Key Caster、调整图标可见模式、切换 `single` 和 `sequence` 显示模式，以及修改浮层位置、字号和显示时长。
- 通过 Key Caster 菜单栏修改的位置、字号、时长、显示模式和菜单栏可见性会通过 `hs.settings` 持久化；同一个菜单里也提供 `恢复默认`，用于清除这些保存值并回退到 `keybindings_config.lua`。
- 你也可以在 Hammerspoon Console 中调用 `package.loaded.key_caster.toggle()`、`package.loaded.key_caster.show_menubar()`、`package.loaded.key_caster.auto_menubar()`、`package.loaded.key_caster.single_display_mode()` 和 `package.loaded.key_caster.sequence_display_mode()` 来控制它。
- 需要辅助功能权限。如果缺少权限，启动时会给出警告，模块可能无法捕获按键事件。

### 应用启动或隐藏

![application-launch](https://user-images.githubusercontent.com/6139938/213380921-4a8a891f-3476-4160-a23d-afd402f53c46.gif)

- <kbd>⌥</kbd> + <kbd>H</kbd>: Hammerspoon Console
- <kbd>⌥</kbd> + <kbd>F</kbd>: Finder
- <kbd>⌥</kbd> + <kbd>I</kbd>: Ghostty
- <kbd>⌥</kbd> + <kbd>C</kbd>: Chrome
- <kbd>⌥</kbd> + <kbd>N</kbd>: Antigravity
- <kbd>⌥</kbd> + <kbd>D</kbd>: WPS
- <kbd>⌥</kbd> + <kbd>O</kbd>: Obsidian
- <kbd>⌥</kbd> + <kbd>M</kbd>: Mail
- <kbd>⌥</kbd> + <kbd>P</kbd>: Postman
- <kbd>⌥</kbd> + <kbd>E</kbd>: Excel
- <kbd>⌥</kbd> + <kbd>V</kbd>: VSCode
- <kbd>⌥</kbd> + <kbd>K</kbd>: Cursor
- <kbd>⌥</kbd> + <kbd>J</kbd>: Tuitui
- <kbd>⌥</kbd> + <kbd>W</kbd>: WeChat

### 休息提醒

![break-reminder](docs/screenshots/break-reminder.png)

这个配置会根据你设定的工作时长和休息时长，在所有屏幕上强制执行定时休息。

- 提供菜单栏图标，用于运行时控制和快速配置。
- `soft`：显示半透明全屏浮层，但仍可继续操作当前应用。
- `hard`：显示浮层，并在休息期间阻止键盘和鼠标输入。
- `show_menubar`：显示菜单栏图标，便于快速操作和图形化配置。
- `start_next_cycle`：控制休息结束后下一轮工作周期如何开始。`auto` 表示立即开始，`on_input` 表示等待第一次键盘或鼠标输入后开始。
- `overlay_opacity`：浮层透明度，范围 `0` 到 `1`。`soft` 模式默认 `0.32`，`hard` 模式默认 `0.96`。
- `minimal_display`：启用后，浮层只显示一个咖啡图标 `☕️`。
- `friendly_reminder_message`：自定义轻提醒文案模板。
- `friendly_reminder_duration_seconds`：轻提醒显示多久。设为 `0` 时保持显示，直到手动点 `×` 关闭。
- `friendly_reminder_seconds`：离休息开始前多少秒弹出轻提醒。设为 `0` 表示禁用。
- 菜单栏中会直接展示每日专注时长、已完成休息次数、跳过次数、连续达标天数以及简单分数。
- `menubar_skin`：在 `coffee`、`hourglass` 和 `bars` 之间切换菜单栏图标样式。
- `focus_goal_minutes`：用于连续达标统计的每日专注目标时长。
- `break_goal_count`：每日完成休息次数目标。设为 `0` 表示禁用。
- 休息执行率会显示为“完成休息次数 /（完成次数 + 跳过次数）”。
- `strict_mode_after_skips`：每天跳过达到这个次数后，提醒会自动升级为 `hard` 模式。设为 `0` 表示禁用。
- `rest_penalty_seconds_per_skip`：每次跳过后，后续每次休息额外增加的秒数。
- `max_rest_penalty_seconds`：累计跳过惩罚的上限。
- 菜单栏菜单提供 `Skip Current Break`，可立即结束当前休息并应用相应惩罚。
- `rest_seconds`：休息时长，单位秒。
- 在菜单栏中做出的改动会通过 `hs.settings` 持久化，在你选择 `恢复默认` 之前，它们会覆盖文件中的配置。
- 选择 `恢复默认` 后会先弹出确认，再清除运行时覆盖值，并回退到 `keybindings_config.lua` 中定义的默认配置。
- 锁屏、显示器休眠和系统休眠期间的时间不计入工作时长。会话重新活跃后，工作计时会从新一轮周期开始。

支持的提醒占位符：

- `{{remaining}}`：可读格式的剩余时间，例如 `1 分钟 30 秒`
- `{{remaining_seconds}}`：整数形式的剩余秒数
- `{{remaining_mmss}}`：`MM:SS` 格式的剩余时间
- `{{rest}}`：可读格式的休息时长
- `{{rest_seconds}}`：休息时长秒数
- `{{rest_mmss}}`：`MM:SS` 格式的休息时长

可以在 `~/.hammerspoon/keybindings_config.lua` 中修改或关闭：

```lua
_M.break_reminder = {
	enabled = true,
	show_menubar = true,
	menubar_skin = "hourglass",
	start_next_cycle = "on_input",
	mode = "soft",
	overlay_opacity = 0.32,
	minimal_display = true,
	focus_goal_minutes = 240,
	break_goal_count = 8,
	strict_mode_after_skips = 2,
	rest_penalty_seconds_per_skip = 30,
	max_rest_penalty_seconds = 300,
	friendly_reminder_message = "还有 {{remaining}} 开始休息",
	friendly_reminder_duration_seconds = 10,
	friendly_reminder_seconds = 120,
	work_minutes = 28,
	rest_seconds = 120,
}
```

### 窗口管理

窗口移动和缩放动作会把当前聚焦窗口约束在当前屏幕的可视区域内，并避免连续缩小时把窗口压到不可用的最小尺寸以下。

#### 窗口定位

![window-position](https://user-images.githubusercontent.com/6139938/213381748-31c10324-aee6-48d4-9ec7-492611fac499.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>C</kbd>: 窗口居中

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>K</kbd>: 上半屏
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>J</kbd>: 下半屏
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>H</kbd>: 左半屏
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>L</kbd>: 右半屏

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>Y</kbd>: 左上角
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>O</kbd>: 右上角
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>U</kbd>: 左下角
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>I</kbd>: 右下角

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>Q</kbd>: 左侧或上方 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>W</kbd>: 右侧或下方 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>E</kbd>: 左侧或上方 2/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>R</kbd>: 右侧或下方 2/3

#### 窗口缩放

![window-resize](https://user-images.githubusercontent.com/6139938/213382832-7f326b87-a704-441d-aa56-9c016f2072cc.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>M</kbd>: 窗口最大化

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>=</kbd>: 向外拉伸
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>-</kbd>: 向内收缩

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>K</kbd>: 底边向上拉伸
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>J</kbd>: 底边向下拉伸
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>H</kbd>: 右边向左拉伸
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>L</kbd>: 右边向右拉伸

#### 窗口移动

![window-movement](https://user-images.githubusercontent.com/6139938/213383576-facc8b81-a94f-4124-b0a1-409d23261421.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>K</kbd>: 向上移动
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>J</kbd>: 向下移动
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>H</kbd>: 向左移动
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>L</kbd>: 向右移动

#### 跨显示器移动

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>UP</kbd>: 移动到上方显示器
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>DOWN</kbd>: 移动到下方显示器
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>LEFT</kbd>: 移动到左侧显示器
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>RIGHT</kbd>: 移动到右侧显示器
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>SPACE</kbd>: 移动到下一个显示器

#### 窗口批量操作

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>M</kbd>: 最小化所有窗口
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>U</kbd>: 取消最小化所有窗口
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>Q</kbd>: 关闭所有窗口

## 快捷键自定义

根据你的按键习惯，修改 `~/.hammerspoon/keybindings_config.lua` 即可。

## macOS 自带的一些实用快捷键

<details>
<summary>展开查看更多</summary>

### 桌面

- <kbd>⌃</kbd> + <kbd>RIGHT</kbd>: 切换到右侧桌面
- <kbd>⌃</kbd> + <kbd>LEFT</kbd>: 切换到左侧桌面
- <kbd>⌃</kbd> + <kbd>UP</kbd>: 打开 Mission Control
- <kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>D</kbd>: 显示或隐藏 Dock

### 应用

- <kbd>⌘</kbd> + <kbd>Q</kbd>: 退出应用
- <kbd>⌘</kbd> + <kbd>,</kbd>: 打开应用偏好设置
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>/</kbd>: 打开帮助

### 窗口

- <kbd>⌘</kbd> + <kbd>H</kbd>: 隐藏窗口
- <kbd>⌘</kbd> + <kbd>M</kbd>: 最小化窗口
- <kbd>⌘</kbd> + <kbd>N</kbd>: 新建窗口
- <kbd>⌘</kbd> + <kbd>W</kbd>: 关闭窗口
- <kbd>⌘</kbd> + <kbd>\`</kbd>: 在同一应用的多个窗口之间切换
- <kbd>⌃</kbd><kbd>⌘</kbd> + <kbd>F</kbd>: 切换窗口全屏
- <kbd>⌃</kbd><kbd>⌘</kbd> + <kbd>H</kbd>: 隐藏除当前窗口外的所有窗口

### 窗口标签

- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>[</kbd>: 切换到左侧标签页
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>]</kbd>: 切换到右侧标签页
- <kbd>⌘</kbd> + <kbd>NUMBER</kbd>: 切换到指定标签页
- <kbd>⌘</kbd> + <kbd>9</kbd>: 切换到最后一个标签页

### 光标

- <kbd>⌃</kbd> + <kbd>P</kbd>: 光标上移
- <kbd>⌃</kbd> + <kbd>N</kbd>: 光标下移
- <kbd>⌃</kbd> + <kbd>B</kbd>: 光标后退或左移
- <kbd>⌃</kbd> + <kbd>F</kbd>: 光标前进或右移
- <kbd>⌃</kbd> + <kbd>A</kbd>: 移动到行首
- <kbd>⌃</kbd> + <kbd>E</kbd>: 移动到行尾

### 文件

- <kbd>⌘</kbd> + <kbd>BACKSPACE</kbd>: 删除选中文件
- <kbd>⌘</kbd> + <kbd>DOWN</kbd>: 进入目录或打开文件
- <kbd>⌘</kbd> + <kbd>UP</kbd>: 返回上一级目录
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>BACKSPACE</kbd>: 清空废纸篓

### 其他

- <kbd>⌘</kbd> + <kbd>+</kbd>: 放大字号
- <kbd>⌘</kbd> + <kbd>-</kbd>: 缩小字号
- <kbd>⌘</kbd> + <kbd>0</kbd>: 重置字号

- <kbd>⌘</kbd> + <kbd>Z</kbd>: 撤销
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>Z</kbd>: 重做
- <kbd>⌘</kbd> + <kbd>C</kbd>: 复制
- <kbd>⌘</kbd> + <kbd>V</kbd>: 粘贴
- <kbd>⌘</kbd><kbd>⌥</kbd> + <kbd>V</kbd>: 粘贴并删除原对象

</details>

## 致谢

- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon)
- [awesome-hammerspoon](https://github.com/ashfinal/awesome-hammerspoon)
- [KURANADO2/hammerspoon-kuranado](https://github.com/KURANADO2/hammerspoon-kuranado)

## 许可证

本项目采用 MIT License。
完整许可证文本请见 [LICENSE](LICENSE)。
