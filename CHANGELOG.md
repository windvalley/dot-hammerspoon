# Changelog

## [0.9.0] - 2026-03-24

### Added
- Introduced a centralized Clipboard History Center for managing and browsing clipboard records.
- Support for deleting specific history items.
- Dynamic runtime configuration for history menu size.
- Enhanced accessibility with new keyboard shortcuts and customizable hotkeys.

### Changed
- Refined the clipboard interface with updated icons.

### Removed
- Discontinued the snippet functionality within the clipboard module.


## [0.8.0] - 2026-03-19

### Added
- Comprehensive Break Reminder overhaul featuring a gamified experience with statistics, skins, and pre-break notifications.
- Menubar integration for reminders including a real-time progress ring, persistence, and session state transition handling.
- New "Keep-Awake" module with system sleep prevention capabilities and dedicated status icon control.
- Flexible display options for break overlays, including a new minimal mode and customizable opacity.
- Enhanced session management with resumption retry logic and input-triggered restart functionality.

### Changed
- Optimized display selection logic for break overlays to improve multi-monitor behavior.
- Refined global configuration for hotkeys and reminder settings.
- Improved Keep-Awake module behavior to automatically reset state on application reload.

### Fixed
- Resolved window movement issues by enforcing the use of visible frames for coordinate calculations.
- Improved application watcher robustness for more reliable input detection.
- Fixed cheatsheet alignment to ensure the canvas centers correctly on the active screen.


## [0.7.0] - 2026-03-17

### Added
- New Break Reminder module to encourage healthy work-rest intervals.

### Changed
- Refactored and optimized the global keybinding system, including dedicated shortcut support for Cursor, Obsidian, and Freeplane.
- Updated environment configurations to migrate input methods and terminal support to WeType and Ghostty.
- Restructured core configuration by consolidating settings into `init.lua` for better maintainability.
- Enhanced project documentation with interactive GIF demonstrations and a curated list of native macOS shortcuts.


All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.6.1

### Added

- Add `hs.logger` to manage logs

### Changed

- Optimize input method switch code structure
- Optimize keybindings cheatsheet

## v0.6.0

### Added

New feature: Auto switch input method according to the application, for example:

```lua
-- keybindings_config.lua
_M.auto_input_methods = {
    ["org.hammerspoon.Hammerspoon"] = abc,
    ["com.apple.finder"] = abc,
    ["com.apple.Spotlight"] = abc,
    ["io.alacritty"] = abc,
    ["com.google.Chrome"] = abc,
    ["com.microsoft.VSCode"] = abc,
    ["com.postmanlabs.mac"] = abc,
    ["com.tencent.xinWeChat"] = pinyin,
    ["com.apple.mail"] = pinyin,
    ["com.microsoft.Excel"] = pinyin,
    ["mac.im.qihoo.net"] = pinyin,
    ["ynote-desktop"] = pinyin
}
```

### Changed

- Optimize manual switch input method.

## v0.5.1

### Changed

- Application launch -> Application launch or hide
- Keybindings Cheatsheet: [Application Launch] -> [App Launch Or Hide]

## v0.5.0

### Added

#### Features

- Open URL directly.
- Auto add keybinding items to cheatsheet.

#### Keybindings

Open URL:

- <kbd>⌥</kbd> + <kbd>8</kbd>: github.com
- <kbd>⌥</kbd> + <kbd>9</kbd>: google.com
- <kbd>⌥</kbd> + <kbd>7</kbd>: bing.com

## v0.4.1

### Changed

- Optimize keybindings cheatsheet:

  - Window manipulation grouping
  - Add `System Mangement`
  - Add `Input Methods`
  - Add `Toggle Keybindings Cheatsheet` in `Application Launch`

- Optimize README.md

## v0.4.0

### Added

#### Features

- New window manipulation: Minimize or Unminimize or Close all windows.
- Add system manage

#### Keybindins

Minimize or Unminimize or Close all windows:

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>M</kbd>: Minimize All Windows
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>U</kbd>: Unminimize All Windows
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>Q</kbd>: Close All Windows

System Manage:

- <kbd>⌥</kbd> + <kbd>Q</kbd>: Lock Screen
- <kbd>⌥</kbd> + <kbd>S</kbd>: Start Screensaver
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>R</kbd>: Restart Computer
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>S</kbd>: Shutdown Computer

### Changed

- Optimize bing daily wallpaper.
- Optimize `Center Window` for window manipulation:  
  From keeping the original size in the center, to changing to the appropriate size and centering.

## v0.3.1

### Changed

Set wallpaper for main monitor -> Set wallpaper for all monitors.

### Fixed

- Fix bug for `Move to Next Monitor`

## v0.3.0

### Added

#### Features

- Keep the desktop wallpaper the same as the bing daily picture.
- New window manipulation: Move to other monitors.

#### Keybindins

Move to other monitors:

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>UP</kbd>: Move to Above Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>DOWN</kbd>: Move to Below Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>LEFT</kbd>: Move to Left Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>RIGHT</kbd>: Move to Right Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>SPACE</kbd>: Move to Next Monitor

## v0.2.0

### Added

#### Features

New window manipulation: Stretch from bottom or right side.

#### Keybindins

Stretch from bottom or right side:

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>K</kbd>: Bottom Side Stretch Upward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>J</kbd>: Bottom Side Stretch Downward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>H</kbd>: Right Side Stretch Leftward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>L</kbd>: Right Side Stretch Rightward

## v0.1.0

### Added

#### Features

- Application quick launch or switch.
- Application window manipulation, such as movement, stretch or shrink, change position, etc.
- Quickly switch to the specified input method.
- Toggle the keybindings cheatsheet.
- Configuration file changes will be automatically reloaded to take effect in real time.
- The code structure is clear and easy to customize into your own configuration.

#### Keybindins

##### Toggle keybindings cheatsheet

<kbd>⌥</kbd> + <kbd>/</kbd>

##### Switch to the specified input method

- <kbd>⌥</kbd> + <kbd>1</kbd>: ABC
- <kbd>⌥</kbd> + <kbd>2</kbd>: Pinyin

##### Application launch or switch

- <kbd>⌥</kbd> + <kbd>H</kbd>: Hammerspoon Console
- <kbd>⌥</kbd> + <kbd>F</kbd>: Finder
- <kbd>⌥</kbd> + <kbd>I</kbd>: Alacritty
- <kbd>⌥</kbd> + <kbd>C</kbd>: Chrome
- <kbd>⌥</kbd> + <kbd>N</kbd>: YNote
- <kbd>⌥</kbd> + <kbd>M</kbd>: Mail
- <kbd>⌥</kbd> + <kbd>P</kbd>: Postman
- <kbd>⌥</kbd> + <kbd>E</kbd>: Excel
- <kbd>⌥</kbd> + <kbd>V</kbd>: VSCode
- <kbd>⌥</kbd> + <kbd>W</kbd>: WeChat

##### Window manipulation

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>=</kbd>: Stretch Outward
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>-</kbd>: Shrink Inward

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>C</kbd>: Center window
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>M</kbd>: Max window

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>H</kbd>: Left Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>L</kbd>: Right Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>K</kbd>: Up Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>J</kbd>: Down Half of Screen

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>U</kbd>: Top Left Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>I</kbd>: Top Right Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>O</kbd>: Bottom Left Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>P</kbd>: Bottom Right Corner

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>Q</kbd>: Left or Top 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>W</kbd>: Right or Bottom 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>E</kbd>: Left or Top 2/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>R</kbd>: Right or Bottom 2/3

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>K</kbd>: Move Upward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>J</kbd>: Move Downward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>H</kbd>: Move Leftward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>L</kbd>: Move Rightward
