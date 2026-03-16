# UserScripts

<p align="center">
  <img src="assets/icon/userscripts-icon.svg" alt="UserScripts icon" width="128" />
</p>

<p align="center">
  A macOS menu bar app for managing, scheduling, and running shell scripts from a lightweight control console.
</p>

## Overview

UserScripts is designed for people who want quick access to repeatable shell commands without living in Terminal all day. It keeps a persistent menu bar presence, offers a larger control console for management, and supports scheduling, logging, notifications, theming, and language preferences.

## Features

- Run shell scripts from a macOS menu bar app
- Organize scripts with names, working directories, commands, environment variables, and schedules
- Start and stop scripts from both the menu bar panel and the main console
- Track execution history and inspect recent logs
- Restore selected scripts on launch
- Configure light, dark, or system appearance
- Configure English, Chinese, or system language
- Choose what happens when closing the console window
- Build a universal macOS app bundle for both Apple Silicon and Intel Macs

## Tech Stack

- Swift 6
- SwiftUI
- AppKit
- Swift Package Manager

## Project Structure

```text
Sources/
  UserScriptsApp/   macOS app, menu bar UI, settings, presentation state
  UserScriptsCore/  script models, validation, persistence, scheduling, process runner
Tests/
  UserScriptsCoreTests/  core and presentation tests
assets/
  icon/  source icon assets
```

## Development

### Run tests

```bash
swift test
```

### Build a release app bundle

```bash
./build-release.sh
```

This generates:

- `UserScripts.app`
- a universal executable containing both `arm64` and `x86_64`
- an `.icns` app icon generated from `assets/icon/userscripts-icon.svg`

## Product Notes

- The app is menu bar first, with a larger console window for detailed management
- Theme and language can follow system preferences
- Close behavior can be configured to ask, keep running in the menu bar, or quit
- Script execution runs under the current user unless a script is explicitly configured to request elevated privileges

## License

This project is released under the Unlicense. See [LICENSE](LICENSE).
