# NotchPrompter

A teleprompter for macOS that hangs from the notch. Built for recording videos while talking to the camera: the text sits right below the lens.

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

## License

MIT. See [LICENSE](LICENSE).
