# Notch Prompter

[![CI](https://github.com/gRiverOS/notch-prompter/actions/workflows/ci.yml/badge.svg)](https://github.com/gRiverOS/notch-prompter/actions/workflows/ci.yml)

A teleprompter for macOS that hangs from the notch. Built for recording videos while talking to the camera: the text sits right below the lens.

Available in English and Spanish.

## Install

With Homebrew:

```bash
brew install --cask gRiverOS/tap/notch-prompter
```

Or download the latest `NotchPrompter-<version>.zip` from [Releases](https://github.com/gRiverOS/notch-prompter/releases), unzip it and drag `Notch Prompter.app` to Applications.

The app is signed with a Developer ID and notarized, so it opens without warnings.

## Requirements

- macOS 14+
- Xcode 15+
- `brew install xcodegen`

## Build

```bash
xcodegen generate
xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData
open "DerivedData/Build/Products/Debug/Notch Prompter.app"
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

## Languages

The interface follows your macOS system language. There is no setting to change inside the app.

| Language | Status |
|---|---|
| English | Source language |
| Spanish | Complete |

Translations live in `NotchPrompter/Resources/Localizable.xcstrings`, a String Catalog you can open in Xcode. To add a language, add its locale to the catalog, translate every key, then add the locale to `supportedLanguages` in `NotchPrompterTests/LocalizationTests.swift`. The test suite fails on any key left untranslated, so nothing ships half-localized.

## Icon

Both icons are drawn as SVGs in `Design/`: `AppIcon.svg` for the app and `MenuBarIcon.svg` for the menu bar. The menu bar one is a template image, so macOS recolors it for the light bar, the dark bar and the highlighted state. After editing either SVG, regenerate the PNGs and commit them alongside the source:

```bash
scripts/make-icon.sh
```

Requires `brew install librsvg`.

## Release (maintainers)

Requires a Developer ID Application certificate, a `notarytool` keychain profile and an authenticated `gh` CLI. See the header of `scripts/release.sh` for the one-time setup.

```bash
scripts/release.sh 0.2.1
```

It builds a Release binary, signs it with hardened runtime, notarizes and staples it, runs a Gatekeeper check, tags the version and publishes a GitHub Release with the zip attached. It then bumps the [Homebrew cask](https://github.com/gRiverOS/homebrew-tap) to the new version and sha256, and pushes it. Set `TAP_DIR` if your clone of the tap is not at `~/dev/personal/homebrew-tap`.

Versions follow [Semantic Versioning](https://semver.org).

## License

MIT. See [LICENSE](LICENSE).
