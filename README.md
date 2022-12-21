# dot-hammerspoon

`dot-hammerspoon` is my configuration for [Hammerspoon](http://www.hammerspoon.org/).

## Features

- Application quick launch or switch.
- Application window management, such as split screen management, zoom in or zoom out, move position, etc.
- Quickly switch to the specified input method.
- Toggle the keybindings cheatsheet.
- Configuration file changes will be automatically reloaded to take effect in real time.
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

### Toggle the keybindings cheatsheet

<kbd>⌥</kbd> + <kbd>/</kbd>

### Switch to the specified input method

- <kbd>⌥</kbd> + <kbd>1</kbd>: ABC
- <kbd>⌥</kbd> + <kbd>2</kbd>: Pinyin

### Application launch or switch

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

### Window manpulation

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>=</kbd>: Zoom window
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>-</kbd>: Shrink window

- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>C</kbd>: Center window
- <kbd>⌃</kbd><kbd>⌥</kbd> + <kbd>M</kbd>: Max window

## Customization

## Acknowledgments

- [Hammerspoon](https://github.com/Hammerspoon/hammerspoon)
- [KURANADO2/hammerspoon-kuranado](https://github.com/KURANADO2/hammerspoon-kuranado)

## License

This project is under the MIT License.
See the [LICENSE](LICENSE) file for the full license text.
