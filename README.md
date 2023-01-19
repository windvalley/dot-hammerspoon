# ![sre.im](https://sre.im/favicon-64.png)dot-hammerspoon

![Language](https://img.shields.io/badge/language-Lua-orange)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
[![Version](https://img.shields.io/github/v/release/windvalley/dot-hammerspoon?include_prereleases)](https://github.com/windvalley/dot-hammerspoon/releases)
[![LICENSE](https://img.shields.io/github/license/windvalley/dot-hammerspoon)](LICENSE)
![Page Views](https://views.whatilearened.today/views/github/windvalley/dot-hammerspoon.svg)

`dot-hammerspoon` is my personal configuration for [Hammerspoon](http://www.hammerspoon.org/), and you can modify to suit your needs and preferences.

## Features

- Application quick launch or hide.
- Application window manipulation, such as moving, resizing, changing position, etc.
- System management, such as lock screen, restart system, etc.
- Auto switch input method according to the application.
- Switch to the specified input method.
- Open the specified website directly.
- Toggle the keybindings cheatsheet.
- Keep the desktop wallpaper the same as the bing daily picture.
- Auto reload configuration when lua files changes.
- The code structure is clear and easy to customize into your own configuration.

## Installation

1. Install [Hammerspoon](http://www.hammerspoon.org/) first: `brew install hammerspoon --cask`

2. Run `Hammerspoon.app` and follow the prompts to enable Accessibility access for the app.

3. `git clone --depth 1 https://github.com/windvalley/dot-hammerspoon.git ~/.hammerspoon`

Keep update:

```sh
cd ~/.hammerspoon && git pull
```

## Usage

### Toggle Keybindings Cheatsheet

![toggle-keybindings-cheatsheet](https://user-images.githubusercontent.com/6139938/213378139-2d005ac0-bce3-4798-a8b5-e2c23fd5817c.gif)

<kbd>⌥</kbd> + <kbd>/</kbd>

### Switch to the specified Input Method

- <kbd>⌥</kbd> + <kbd>1</kbd>: ABC
- <kbd>⌥</kbd> + <kbd>2</kbd>: Pinyin

### System Management

- <kbd>⌥</kbd> + <kbd>Q</kbd>: Lock Screen
- <kbd>⌥</kbd> + <kbd>S</kbd>: Start Screensaver
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>R</kbd>: Restart Computer
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>S</kbd>: Shutdown Computer

### Website Open

- <kbd>⌥</kbd> + <kbd>8</kbd>: github.com
- <kbd>⌥</kbd> + <kbd>9</kbd>: google.com
- <kbd>⌥</kbd> + <kbd>7</kbd>: bing.com

### Application Launch or Hide

![application-launch](https://user-images.githubusercontent.com/6139938/213380921-4a8a891f-3476-4160-a23d-afd402f53c46.gif)

- <kbd>⌥</kbd> + <kbd>H</kbd>: Hammerspoon Console
- <kbd>⌥</kbd> + <kbd>F</kbd>: Finder
- <kbd>⌥</kbd> + <kbd>I</kbd>: Alacritty
- <kbd>⌥</kbd> + <kbd>C</kbd>: Chrome
- <kbd>⌥</kbd> + <kbd>N</kbd>: YNote
- <kbd>⌥</kbd> + <kbd>M</kbd>: Mail
- <kbd>⌥</kbd> + <kbd>O</kbd>: VirtualBox
- <kbd>⌥</kbd> + <kbd>D</kbd>: DeepL
- <kbd>⌥</kbd> + <kbd>P</kbd>: Postman
- <kbd>⌥</kbd> + <kbd>E</kbd>: Excel
- <kbd>⌥</kbd> + <kbd>V</kbd>: VSCode
- <kbd>⌥</kbd> + <kbd>W</kbd>: WeChat

### Window Manipulation

#### Window Position

![window-position](https://user-images.githubusercontent.com/6139938/213381748-31c10324-aee6-48d4-9ec7-492611fac499.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>C</kbd>: Center Window

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>K</kbd>: Up Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>J</kbd>: Down Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>H</kbd>: Left Half of Screen
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>L</kbd>: Right Half of Screen

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>U</kbd>: Top Left Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>I</kbd>: Top Right Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>O</kbd>: Bottom Left Corner
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>P</kbd>: Bottom Right Corner

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>Q</kbd>: Left or Top 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>W</kbd>: Right or Bottom 1/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>E</kbd>: Left or Top 2/3
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>R</kbd>: Right or Bottom 2/3

#### Window Resize

![window-resize](https://user-images.githubusercontent.com/6139938/213382832-7f326b87-a704-441d-aa56-9c016f2072cc.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>M</kbd>: Max Window

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>=</kbd>: Stretch Outward
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>-</kbd>: Shrink Inward

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>K</kbd>: Bottom Side Stretch Upward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>J</kbd>: Bottom Side Stretch Downward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>H</kbd>: Right Side Stretch Leftward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>L</kbd>: Right Side Stretch Rightward

#### Window Movement

![window-movement](https://user-images.githubusercontent.com/6139938/213383576-facc8b81-a94f-4124-b0a1-409d23261421.gif)

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>K</kbd>: Move Upward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>J</kbd>: Move Downward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>H</kbd>: Move Leftward
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>L</kbd>: Move Rightward

#### Window Monitor

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>UP</kbd>: Move to Above Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>DOWN</kbd>: Move to Below Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>LEFT</kbd>: Move to Left Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>RIGHT</kbd>: Move to Right Monitor
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>SPACE</kbd>: Move to Next Monitor

#### Window Batch

- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>M</kbd>: Minimize All Windows
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>U</kbd>: Unminimize All Windows
- <kbd>⌃</kbd><kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>Q</kbd>: Close All Windows

## Keybindings Customization

Modify the file `~/.hammerspoon/keybindings_config.lua` according to your keystroke habits.

## Some Useful Shortcuts Come With macOS

<details>
<summary>More details</summary>

### Desktop

- <kbd>⌃</kbd> + <kbd>RIGHT</kbd>: Switch to right desktop
- <kbd>⌃</kbd> + <kbd>LEFT</kbd>: Switch to left desktop
- <kbd>⌃</kbd> + <kbd>UP</kbd>: Toggle tiling windows
- <kbd>⌥</kbd><kbd>⌘</kbd> + <kbd>D</kbd>: Toggle dock

### Application

- <kbd>⌘</kbd> + <kbd>Q</kbd>: Close app
- <kbd>⌘</kbd> + <kbd>,</kbd>: Open the app's preferences
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>/</kbd>: Toggle help

### Window

- <kbd>⌘</kbd> + <kbd>H</kbd>: Hide window
- <kbd>⌘</kbd> + <kbd>M</kbd>: Minimize window
- <kbd>⌘</kbd> + <kbd>N</kbd>: New window
- <kbd>⌘</kbd> + <kbd>W</kbd>: Close window
- <kbd>⌘</kbd> + <kbd>\`</kbd>: Switch between windows of the same application
- <kbd>⌃</kbd><kbd>⌘</kbd> + <kbd>F</kbd>: Toggle window fullscreen
- <kbd>⌃</kbd><kbd>⌘</kbd> + <kbd>H</kbd>: Hide all windows except the current one

### Window Tab

- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>[</kbd>: Switch to the left tab
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>]</kbd>: Switch to the right tab
- <kbd>⌘</kbd> + <kbd>NUMBER</kbd>: Switch to the specified tab
- <kbd>⌘</kbd> + <kbd>9</kbd>: Switch to the last tab

### Cursor

- <kbd>⌃</kbd> + <kbd>P</kbd>: Move the cursor up
- <kbd>⌃</kbd> + <kbd>N</kbd>: Move the cursor down
- <kbd>⌃</kbd> + <kbd>B</kbd>: Move the cursor back/left
- <kbd>⌃</kbd> + <kbd>F</kbd>: Move the cursor forward/right
- <kbd>⌃</kbd> + <kbd>A</kbd>: Move the cursor to the beginning of the line
- <kbd>⌃</kbd> + <kbd>E</kbd>: Move the cursor to the end of the line

### File

- <kbd>⌘</kbd> + <kbd>BACKSPACE</kbd>: Delete the selected file
- <kbd>⌘</kbd> + <kbd>DOWN</kbd>: Go to a directory or open a file
- <kbd>⌘</kbd> + <kbd>UP</kbd>: Back to the upper level directory
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>BACKSPACE</kbd>: Clear the Trash

### Others

- <kbd>⌘</kbd> + <kbd>+</kbd>: Expand font size
- <kbd>⌘</kbd> + <kbd>-</kbd>: Shrink font size
- <kbd>⌘</kbd> + <kbd>0</kbd>: Reset font size

- <kbd>⌘</kbd> + <kbd>Z</kbd>: Undo
- <kbd>⌘</kbd><kbd>⇧</kbd> + <kbd>Z</kbd>: Redo
- <kbd>⌘</kbd> + <kbd>C</kbd>: Copy
- <kbd>⌘</kbd> + <kbd>V</kbd>: Paste
- <kbd>⌘</kbd><kbd>⌥</kbd> + <kbd>V</kbd>: Paste and delete the original object

</details>

## Acknowledgments

- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon)
- [awesome-hammerspoon](https://github.com/ashfinal/awesome-hammerspoon)
- [KURANADO2/hammerspoon-kuranado](https://github.com/KURANADO2/hammerspoon-kuranado)

## License

This project is under the MIT License.
See the [LICENSE](LICENSE) file for the full license text.
