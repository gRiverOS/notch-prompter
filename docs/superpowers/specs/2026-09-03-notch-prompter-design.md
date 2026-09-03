# NotchPrompter — Design

Date: 2026-09-03

## Goal

Native macOS teleprompter that hangs from the MacBook notch, for recording talking-head videos with your gaze 1-2 cm from the lens. Auto-scroll with adjustable speed, controlled by global shortcuts.

Out of scope for this version: voice tracking, manual line-by-line control, screen sharing exclusion, configurable shortcuts, script files or sync, font adjustment.

## Stack

- Swift 5.9+, SwiftUI for content, AppKit for the window.
- macOS 14 or later (uses `CADisplayLink` from `NSScreen`).
- Xcode project generated with XcodeGen from `project.yml`.
- No external dependencies.

## 1. Window over the notch

App with no Dock or main window (`LSUIElement = true`). Icon in the menu bar.

`PrompterPanel: NSPanel`:

- `styleMask = [.borderless, .nonactivatingPanel]`.
- `level = .statusBar + 1`.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`.
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`.
- `ignoresMouseEvents = true` always, since the panel has no interactive content.
- Content: `NSHostingView` with `PrompterView`, black background, bottom corners rounded 16 pt.

Geometry (`NotchGeometry`), a pure function over values pulled from `NSScreen`:

- Input: `screenFrame`, `safeAreaInsets.top`, `auxiliaryTopLeftArea`, `auxiliaryTopRightArea`.
- Notch width = `topRight.minX - topLeft.maxX` when both areas exist; if there is no notch, width 0.
- Panel: 560 x 130 pt, centered on the X axis over the notch's center (or the screen's, if there is no notch), top edge flush with the screen's top edge.
- Recalculated on receiving `NSApplication.didChangeScreenParametersNotification`.

## 2. Scroll engine

`PrompterEngine: ObservableObject`, with no UI dependencies.

State:

- `text: String`
- `offset: CGFloat` (points scrolled upward, starts at 0)
- `speed: Double` in pt/s, range 20...200, default 60, step 10
- `isPlaying: Bool`
- `contentHeight: CGFloat` (reported by the view)
- `viewportHeight: CGFloat`

Clock: `FrameClock` protocol with `start(onTick: (dt) -> Void)` and `stop()`. Real implementation with `NSScreen.displayLink`; in tests, `tick(dt:)` is called manually.

Rules:

- `tick(dt)`: if `isPlaying`, `offset += speed * dt`. If `offset >= contentHeight`, `offset = contentHeight` and `isPlaying = false`.
- `togglePlay()`, `increaseSpeed()`, `decreaseSpeed()` (clamp to range), `reset()` (offset 0, pause).
- `text` and `speed` are persisted to `UserDefaults` on change. `offset` is not.

Render (`PrompterView`):

- Full `Text` inside a `GeometryReader`, `.offset(y: -offset)`, `.clipped()`.
- Top padding equal to `viewportHeight` so the first line enters from below.
- SF Pro 34 pt, white on black, 1.3 line spacing, no `minimumScaleFactor`.
- Black gradient at top and bottom; the line under the lens at full brightness.
- While paused, text at 60% opacity.
- On speed change, the number appears in the corner for 1 s.
- Empty text: "Write your script from the menu" in gray.

## 3. Controls

Global shortcuts with `RegisterEventHotKey` (Carbon), no Accessibility permission needed, fixed:

| Shortcut | Action |
|---|---|
| ⌃⌥ Space | Play / pause |
| ⌃⌥ ↑ / ↓ | Speed +10 / -10 |
| ⌃⌥ R | Back to start |
| ⌃⌥ T | Show / hide panel |

Script editor: normal window with `TextEditor`. The script is saved when this window closes (not on every keystroke); once saved, the panel updates and `offset` goes back to 0.

Menu bar: "Edit Script…", "Show Panel" / "Hide Panel", submenu "Shortcuts" (reference), "Quit".

Show/hide panel: hiding only pauses playback, without rewinding `offset`; showing the panel again resumes where it left off. ⌃⌥ R is the only way to go back to the start.

Errors: if registering a hotkey fails, it is flagged in the menu and the rest keep working. Nothing else can fail in a relevant way.

## 4. Structure

```
NotchPrompter/
├── project.yml
├── NotchPrompter/
│   ├── NotchPrompterApp.swift
│   ├── Window/PrompterPanel.swift
│   ├── Window/NotchGeometry.swift
│   ├── Engine/PrompterEngine.swift
│   ├── Engine/FrameClock.swift
│   ├── Views/PrompterView.swift
│   ├── Views/ScriptEditorView.swift
│   ├── Input/HotKeys.swift
│   └── Info.plist
└── NotchPrompterTests/
    ├── PrompterEngineTests.swift
    └── NotchGeometryTests.swift
```

## 5. Tests

Unit (XCTest):

- `PrompterEngine`: advances `speed * dt`; stops at the end; speed clamp 20...200; reset to 0 and pause; does not advance while paused.
- `NotchGeometry`: 14" MacBook Pro with notch (panel centered over the notch, flush at the top); external monitor without a notch (centered on screen).

Manual:

1. QuickTime recording the camera: the panel shows on top and shortcuts work without activating the app.
2. QuickTime in fullscreen: the panel stays visible.
3. Read a 1-minute script at speed 60 and calibrate the default.
