# NotchPrompter

[![CI](https://github.com/gRiverOS/notch-prompter/actions/workflows/ci.yml/badge.svg)](https://github.com/gRiverOS/notch-prompter/actions/workflows/ci.yml)

A teleprompter for macOS that hangs from the notch. Built for recording videos while talking to the camera: the text sits right below the lens.

Available in English and Spanish. The app follows your system language, with no setting to change.

## Install

With Homebrew:

```bash
brew install --cask gRiverOS/tap/notch-prompter
```

Or download the latest `NotchPrompter-<version>.zip` from [Releases](https://github.com/gRiverOS/notch-prompter/releases), unzip it and drag `NotchPrompter.app` to Applications.

The app is signed with a Developer ID and notarized, so it opens without warnings.

## Requirements

- macOS 14+
- Xcode 15+
- `brew install xcodegen`

## Build

```bash
xcodegen generate
xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData
open DerivedData/Build/Products/Debug/NotchPrompter.app
```

## Tests

```bash
xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS'
```

## Shortcuts (global, with ⌃⌥)

| Shortcut | Action |
|---|---|
| ⌃⌥ Space | Play / pause |
| ⌃⌥ ↑ / ↓ | Speed +10 / -10 |
| ⌃⌥ R | Back to start |
| ⌃⌥ T | Show / hide panel |

The script is edited from the menu bar icon and saved automatically when the editor window closes.

## Release (maintainers)

Requires a Developer ID Application certificate, a `notarytool` keychain profile and an authenticated `gh` CLI. See the header of `scripts/release.sh` for the one-time setup.

```bash
scripts/release.sh 0.1.0
```

It builds a Release binary, signs it with hardened runtime, notarizes and staples it, runs a Gatekeeper check, tags `v0.1.0` and publishes a GitHub Release with the zip attached.

## License

MIT. See [LICENSE](LICENSE).
