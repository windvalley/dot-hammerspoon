# Repository Guidelines

## Project Structure & Module Organization
This repository is a flat Hammerspoon Lua config. `init.lua` is the entry point and loads each feature module in order. Core modules live at the repository root, such as `app_launch.lua`, `break_reminder.lua`, and `clipboard_center.lua`. Shared helpers are in files like `hotkey_helper.lua`, `utils_lib.lua`, and `window_lib.lua`. Runtime configuration is centralized in `keybindings_config.lua`. Custom or third-party Spoon code belongs in `Spoons/`. Project documentation lives in `README.md`; `CHANGELOG.md` exists but is automation-managed.

## Build, Test, and Development Commands
There is no build step in the usual sense. Common commands:

- `brew install --cask hammerspoon`: install the runtime.
- `luacheck .`: run static analysis using `.luacheckrc`.
- `open -a Hammerspoon`: launch or foreground Hammerspoon.
- Run `hs.reload()` in the Hammerspoon Console: reload the config and verify startup.
- `osascript -e 'id of app "Google Chrome"'`: look up a macOS bundle ID before editing app mappings.

## Coding Style & Naming Conventions
Follow the existing module pattern: define `local _M = {}` and export module metadata such as `_M.name` and `_M.description` when appropriate. Prefer `snake_case` for filenames, config keys, and local functions. Logger variables are typically named `log`; state tables are typically named `state`. Match the surrounding file’s indentation and spacing instead of reformatting unrelated code. New hotkeys, bundle IDs, and URLs should be added to `keybindings_config.lua`, not hardcoded across modules.

## Testing Guidelines
There is no dedicated `tests/` directory yet, so validation is mostly manual. Before submitting changes, run `luacheck .`, reload Hammerspoon, and check the Console for module load failures. Then exercise the affected hotkeys, menubar items, chooser flows, or fullscreen overlays directly. For modules that persist values through `hs.settings`, including `keep_awake`, `clipboard_center`, and `break_reminder`, verify behavior both before and after `hs.reload()`.

## Commit & Pull Request Guidelines
Recent history follows scoped Conventional Commits, for example `feat(core): ...`, `fix(utils): ...`, and `refactor(cheatsheet): ...`. Keep each commit focused on one module or one behavior change. Do not manually edit `CHANGELOG.md`; it is updated by automation. Pull requests should include a short summary, manual verification steps, and notes about changed hotkeys or menubar behavior. Add screenshots or GIFs when changing chooser panels, reminders, or overlays.

## Security & Configuration Tips
Some modules require macOS Accessibility permissions for window control or input monitoring, so document those prerequisites when relevant. Do not commit personal paths, private URLs, account-specific settings, or machine-specific bundle IDs unless they are intentionally configurable through `keybindings_config.lua`.
