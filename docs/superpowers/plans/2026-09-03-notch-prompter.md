# NotchPrompter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native macOS teleprompter that hangs from the notch, with adjustable-speed auto-scroll and global hotkeys, for recording videos while talking to the camera.

**Architecture:** A menu bar app (`LSUIElement`) with a non-activating `NSPanel` that floats over everything, even fullscreen, pinned to the top edge of the screen and centered on the notch. A pure `PrompterEngine` (no UI) advances the offset with an injectable clock and persists text and speed. SwiftUI draws the text; Carbon `RegisterEventHotKey` provides the global hotkeys without requiring permissions.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, Carbon (HotKeys), XCTest, XcodeGen, macOS 14+. No external dependencies.

**Spec:** `docs/superpowers/specs/2026-09-03-notch-prompter-design.md`

## Global Constraints

- Deployment target: macOS 14.0 (uses `NSScreen.displayLink`).
- No external packages. Apple frameworks only.
- `LSUIElement = true`: no Dock icon, no main window.
- Panel: 560 x 130 pt, bottom corners 16 pt, black background.
- Speed: range 20...200 pt/s, default 60, step 10.
- Typography: SF Pro 34 pt, white, 1.3 line spacing, no `minimumScaleFactor`.
- Fixed hotkeys with ⌃⌥: Space (play/pause), ↑/↓ (speed), R (reset), T (show/hide).
- Empty text shows: "Write your script from the menu".
- Bundle id prefix: `cl.gustavo`.
- Test command: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS'`.

---

## File Structure

```
project.yml                                  # XcodeGen: 2 targets (app + tests)
NotchPrompter/
  NotchPrompterApp.swift                     # @main, MenuBarExtra, editor Window, AppDelegate
  Info.plist                                 # LSUIElement
  Window/NotchGeometry.swift                 # pure computation of the panel's frame
  Window/PrompterPanel.swift                 # configured NSPanel + repositioning
  Engine/FrameClock.swift                    # protocol + DisplayLinkClock
  Engine/SettingsStore.swift                 # protocol + UserDefaultsStore
  Engine/PrompterEngine.swift                # scroll state and rules
  Views/PrompterView.swift                   # renders the text in the panel
  Views/ScriptEditorView.swift               # script TextEditor
  Input/HotKeys.swift                        # Carbon hotkeys
NotchPrompterTests/
  NotchGeometryTests.swift
  PrompterEngineTests.swift
  UserDefaultsStoreTests.swift
```

---

### Task 1: Project scaffold with XcodeGen

**Files:**
- Create: `project.yml`
- Create: `NotchPrompter/Info.plist`
- Create: `NotchPrompter/NotchPrompterApp.swift`
- Create: `NotchPrompterTests/SmokeTests.swift`
- Create: `.gitignore`

**Interfaces:**
- Produces: generated `NotchPrompter.xcodeproj` project, `NotchPrompter` scheme with tests. Later tasks only add files under `NotchPrompter/` and `NotchPrompterTests/` and regenerate with `xcodegen`.

- [ ] **Step 1: Install XcodeGen**

Run: `brew install xcodegen`
Expected: `xcodegen --version` prints a version.

- [ ] **Step 2: Create `project.yml`**

```yaml
name: NotchPrompter
options:
  bundleIdPrefix: cl.gustavo
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    DEVELOPMENT_TEAM: ""
targets:
  NotchPrompter:
    type: application
    platform: macOS
    sources:
      - NotchPrompter
    info:
      path: NotchPrompter/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: NotchPrompter
        CFBundleDisplayName: NotchPrompter
        NSHumanReadableCopyright: ""
    settings:
      base:
        ENABLE_TESTABILITY: YES
  NotchPrompterTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - NotchPrompterTests
    dependencies:
      - target: NotchPrompter
schemes:
  NotchPrompter:
    build:
      targets:
        NotchPrompter: all
        NotchPrompterTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - NotchPrompterTests
```

- [ ] **Step 3: Create `.gitignore`**

```
*.xcodeproj
DerivedData/
xcuserdata/
.DS_Store
```

- [ ] **Step 4: Create `NotchPrompter/Info.plist`**

XcodeGen generates the plist from `info.properties`, but it needs the file to exist. Create it with minimal content; XcodeGen will overwrite it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 5: Create the minimal app `NotchPrompter/NotchPrompterApp.swift`**

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
```

- [ ] **Step 6: Create the smoke test `NotchPrompterTests/SmokeTests.swift`**

```swift
import XCTest
@testable import NotchPrompter

final class SmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 7: Generate the project and run tests**

Run:
```bash
xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case|error:|TEST (SUCCEEDED|FAILED)"
```
Expected: `Test Case '-[NotchPrompterTests.SmokeTests testModuleLinks]' passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add project.yml .gitignore NotchPrompter NotchPrompterTests
git commit -m "chore: scaffold NotchPrompter with XcodeGen"
```

---

### Task 2: NotchGeometry

**Files:**
- Create: `NotchPrompter/Window/NotchGeometry.swift`
- Test: `NotchPrompterTests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum NotchGeometry {
      static let panelSize: CGSize  // 560 x 130
      static func panelFrame(screenFrame: CGRect, topLeftArea: CGRect?, topRightArea: CGRect?, size: CGSize = panelSize) -> CGRect
  }
  ```
  AppKit coordinates (origin at bottom left). The frame is pinned to the top edge (`maxY`) of `screenFrame`.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import NotchPrompter

final class NotchGeometryTests: XCTestCase {
    // MacBook Pro 14": 1512x982 screen, 38 pt notch between the auxiliary areas.
    let mbp14 = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let leftArea = CGRect(x: 0, y: 944, width: 700, height: 38)
    let rightArea = CGRect(x: 820, y: 944, width: 692, height: 38)

    func testPanelIsCenteredOnNotchAndPinnedToTop() {
        let frame = NotchGeometry.panelFrame(screenFrame: mbp14, topLeftArea: leftArea, topRightArea: rightArea)
        // Notch center = (700 + 820) / 2 = 760
        XCTAssertEqual(frame.midX, 760, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, 982, accuracy: 0.001)
        XCTAssertEqual(frame.size, NotchGeometry.panelSize)
    }

    func testWithoutNotchPanelIsCenteredOnScreen() {
        let external = CGRect(x: 1512, y: 200, width: 2560, height: 1440)
        let frame = NotchGeometry.panelFrame(screenFrame: external, topLeftArea: nil, topRightArea: nil)
        XCTAssertEqual(frame.midX, external.midX, accuracy: 0.001)
        XCTAssertEqual(frame.maxY, external.maxY, accuracy: 0.001)
    }

    func testAreasThatDoNotLeaveGapCountAsNoNotch() {
        let left = CGRect(x: 0, y: 944, width: 756, height: 38)
        let right = CGRect(x: 756, y: 944, width: 756, height: 38)
        let frame = NotchGeometry.panelFrame(screenFrame: mbp14, topLeftArea: left, topRightArea: right)
        XCTAssertEqual(frame.midX, mbp14.midX, accuracy: 0.001)
    }

    func testPanelSizeMatchesSpec() {
        XCTAssertEqual(NotchGeometry.panelSize, CGSize(width: 560, height: 130))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: compile error `cannot find 'NotchGeometry' in scope`.

- [ ] **Step 3: Implement `NotchPrompter/Window/NotchGeometry.swift`**

```swift
import CoreGraphics

/// Pure computation of the panel's frame from the screen's geometry.
/// AppKit coordinates: origin at bottom left, Y grows upward.
enum NotchGeometry {
    static let panelSize = CGSize(width: 560, height: 130)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea` (nil if there is no notch).
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea` (nil if there is no notch).
    static func panelFrame(
        screenFrame: CGRect,
        topLeftArea: CGRect?,
        topRightArea: CGRect?,
        size: CGSize = panelSize
    ) -> CGRect {
        let centerX: CGFloat
        if let left = topLeftArea, let right = topRightArea, right.minX > left.maxX {
            centerX = (left.maxX + right.minX) / 2
        } else {
            centerX = screenFrame.midX
        }
        let origin = CGPoint(
            x: centerX - size.width / 2,
            y: screenFrame.maxY - size.height
        )
        return CGRect(origin: origin, size: size)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*NotchGeometry|TEST (SUCCEEDED|FAILED)"`
Expected: 4 tests `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add NotchPrompter/Window/NotchGeometry.swift NotchPrompterTests/NotchGeometryTests.swift
git commit -m "feat: panel geometry over the notch"
```

---

### Task 3: FrameClock, SettingsStore and PrompterEngine

**Files:**
- Create: `NotchPrompter/Engine/FrameClock.swift`
- Create: `NotchPrompter/Engine/SettingsStore.swift`
- Create: `NotchPrompter/Engine/PrompterEngine.swift`
- Test: `NotchPrompterTests/PrompterEngineTests.swift`

**Interfaces:**
- Produces:
  ```swift
  protocol FrameClock: AnyObject {
      func start(onTick: @escaping (TimeInterval) -> Void)
      func stop()
  }
  final class DisplayLinkClock: FrameClock   // production, uses NSScreen.displayLink

  protocol SettingsStore: AnyObject {
      var text: String { get set }
      var speed: Double { get set }
  }
  final class InMemoryStore: SettingsStore   // tests only (lives in the tests target)

  @MainActor final class PrompterEngine: ObservableObject {
      static let speedRange: ClosedRange<Double>  // 20...200
      static let speedStep: Double                // 10
      static let defaultSpeed: Double             // 60
      @Published var text: String
      @Published private(set) var offset: CGFloat
      @Published private(set) var speed: Double
      @Published private(set) var isPlaying: Bool
      var contentHeight: CGFloat                  // set by the view
      init(clock: FrameClock, store: SettingsStore)
      func tick(dt: TimeInterval)
      func togglePlay()
      func increaseSpeed()
      func decreaseSpeed()
      func reset()
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import NotchPrompter

final class FakeClock: FrameClock {
    var onTick: ((TimeInterval) -> Void)?
    var startCount = 0
    var stopCount = 0
    func start(onTick: @escaping (TimeInterval) -> Void) { self.onTick = onTick; startCount += 1 }
    func stop() { onTick = nil; stopCount += 1 }
}

final class InMemoryStore: SettingsStore {
    var text: String = ""
    var speed: Double = PrompterEngine.defaultSpeed
}

@MainActor
final class PrompterEngineTests: XCTestCase {
    var clock: FakeClock!
    var store: InMemoryStore!
    var engine: PrompterEngine!

    override func setUp() {
        clock = FakeClock()
        store = InMemoryStore()
        engine = PrompterEngine(clock: clock, store: store)
        engine.contentHeight = 1000
    }

    func testInitialState() {
        XCTAssertEqual(engine.offset, 0)
        XCTAssertEqual(engine.speed, 60)
        XCTAssertFalse(engine.isPlaying)
    }

    func testLoadsTextAndSpeedFromStore() {
        store.text = "hello"
        store.speed = 90
        let e = PrompterEngine(clock: clock, store: store)
        XCTAssertEqual(e.text, "hello")
        XCTAssertEqual(e.speed, 90)
    }

    func testTickAdvancesOffsetBySpeedTimesDt() {
        engine.togglePlay()
        engine.tick(dt: 0.5)
        XCTAssertEqual(engine.offset, 30, accuracy: 0.001)
    }

    func testTickDoesNothingWhenPaused() {
        engine.tick(dt: 1)
        XCTAssertEqual(engine.offset, 0)
    }

    func testStopsAtEndOfContent() {
        engine.togglePlay()
        engine.tick(dt: 100) // 60 * 100 = 6000 > 1000
        XCTAssertEqual(engine.offset, 1000)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testTogglePlayStartsAndStopsClock() {
        engine.togglePlay()
        XCTAssertTrue(engine.isPlaying)
        XCTAssertEqual(clock.startCount, 1)
        engine.togglePlay()
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testClockTicksReachEngine() {
        engine.togglePlay()
        clock.onTick?(1)
        XCTAssertEqual(engine.offset, 60, accuracy: 0.001)
    }

    func testSpeedStepsAndClamps() {
        engine.increaseSpeed()
        XCTAssertEqual(engine.speed, 70)
        engine.decreaseSpeed()
        engine.decreaseSpeed()
        XCTAssertEqual(engine.speed, 50)
        for _ in 0..<30 { engine.increaseSpeed() }
        XCTAssertEqual(engine.speed, 200)
        for _ in 0..<30 { engine.decreaseSpeed() }
        XCTAssertEqual(engine.speed, 20)
    }

    func testSpeedPersistsToStore() {
        engine.increaseSpeed()
        XCTAssertEqual(store.speed, 70)
    }

    func testTextPersistsToStore() {
        engine.text = "new script"
        XCTAssertEqual(store.text, "new script")
    }

    func testResetReturnsToZeroAndPauses() {
        engine.togglePlay()
        engine.tick(dt: 1)
        engine.reset()
        XCTAssertEqual(engine.offset, 0)
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(clock.stopCount, 1)
    }

    func testChangingTextResetsOffset() {
        engine.togglePlay()
        engine.tick(dt: 1)
        engine.text = "another"
        XCTAssertEqual(engine.offset, 0)
        XCTAssertFalse(engine.isPlaying)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: errors `cannot find type 'FrameClock'`, `'SettingsStore'`, `'PrompterEngine'`.

- [ ] **Step 3: Implement `NotchPrompter/Engine/FrameClock.swift`**

```swift
import AppKit
import QuartzCore

/// Source of per-frame ticks. Injectable so the engine can be tested without UI.
protocol FrameClock: AnyObject {
    func start(onTick: @escaping (TimeInterval) -> Void)
    func stop()
}

/// Real implementation over NSScreen's CADisplayLink (macOS 14+).
final class DisplayLinkClock: FrameClock {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var onTick: ((TimeInterval) -> Void)?

    func start(onTick: @escaping (TimeInterval) -> Void) {
        stop()
        self.onTick = onTick
        lastTimestamp = nil
        guard let screen = NSScreen.main else { return }
        let link = screen.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        onTick = nil
        lastTimestamp = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let last = lastTimestamp else { return }
        onTick?(link.timestamp - last)
    }
}
```

- [ ] **Step 4: Implement `NotchPrompter/Engine/SettingsStore.swift`**

```swift
import Foundation

/// Persistence for text and speed. Injectable for tests.
protocol SettingsStore: AnyObject {
    var text: String { get set }
    var speed: Double { get set }
}

final class UserDefaultsStore: SettingsStore {
    private let defaults: UserDefaults
    private enum Key {
        static let text = "script.text"
        static let speed = "prompter.speed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var text: String {
        get { defaults.string(forKey: Key.text) ?? "" }
        set { defaults.set(newValue, forKey: Key.text) }
    }

    var speed: Double {
        get {
            let stored = defaults.double(forKey: Key.speed)
            return stored == 0 ? PrompterEngine.defaultSpeed : stored
        }
        set { defaults.set(newValue, forKey: Key.speed) }
    }
}
```

- [ ] **Step 5: Implement `NotchPrompter/Engine/PrompterEngine.swift`**

```swift
import Foundation
import CoreGraphics

/// Teleprompter state and rules. No UI dependencies.
@MainActor
final class PrompterEngine: ObservableObject {
    static let speedRange: ClosedRange<Double> = 20...200
    static let speedStep: Double = 10
    static let defaultSpeed: Double = 60

    @Published var text: String {
        didSet {
            store.text = text
            reset()
        }
    }
    @Published private(set) var offset: CGFloat = 0
    @Published private(set) var speed: Double {
        didSet { store.speed = speed }
    }
    @Published private(set) var isPlaying = false

    /// Total scrollable content height. The view reports it when measured.
    var contentHeight: CGFloat = 0

    private let clock: FrameClock
    private let store: SettingsStore

    init(clock: FrameClock, store: SettingsStore) {
        self.clock = clock
        self.store = store
        self.text = store.text
        self.speed = Self.speedRange.clamp(store.speed)
    }

    func tick(dt: TimeInterval) {
        guard isPlaying else { return }
        offset += CGFloat(speed * dt)
        if offset >= contentHeight {
            offset = contentHeight
            pause()
        }
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func increaseSpeed() {
        speed = Self.speedRange.clamp(speed + Self.speedStep)
    }

    func decreaseSpeed() {
        speed = Self.speedRange.clamp(speed - Self.speedStep)
    }

    func reset() {
        offset = 0
        pause()
    }

    private func play() {
        guard !isPlaying else { return }
        isPlaying = true
        clock.start { [weak self] dt in
            self?.tick(dt: dt)
        }
    }

    private func pause() {
        guard isPlaying else { return }
        isPlaying = false
        clock.stop()
    }
}

private extension ClosedRange where Bound == Double {
    func clamp(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
```

Note: `text.didSet` calls `reset()`, which calls `pause()`. `pause()` only stops the clock if it was playing, so `stopCount` isn't inflated in the tests.

- [ ] **Step 6: Run to verify it passes**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*PrompterEngine|error:|TEST (SUCCEEDED|FAILED)"`
Expected: 12 tests `passed`, `** TEST SUCCEEDED **`. If `clock.start` inside `init` produces a concurrency error, the closure already captures `self` weakly within a `@MainActor` context; adding `@MainActor` to the closure like `clock.start { [weak self] dt in Task { @MainActor in self?.tick(dt: dt) } }` is NOT acceptable because it breaks the `testClockTicksReachEngine` test (synchronous). Use `MainActor.assumeIsolated { self?.tick(dt: dt) }` instead if the compiler requires it.

- [ ] **Step 7: Commit**

```bash
git add NotchPrompter/Engine NotchPrompterTests/PrompterEngineTests.swift
git commit -m "feat: scroll engine with injectable clock and store"
```

---

### Task 4: UserDefaultsStore tests

**Files:**
- Test: `NotchPrompterTests/UserDefaultsStoreTests.swift`

**Interfaces:**
- Consumes: `UserDefaultsStore(defaults:)` from Task 3.

- [ ] **Step 1: Write the tests**

```swift
import XCTest
@testable import NotchPrompter

final class UserDefaultsStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: UserDefaultsStore!

    override func setUp() {
        let suite = "cl.gustavo.NotchPrompter.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = UserDefaultsStore(defaults: defaults)
    }

    func testDefaultsWhenEmpty() {
        XCTAssertEqual(store.text, "")
        XCTAssertEqual(store.speed, PrompterEngine.defaultSpeed)
    }

    func testRoundTripsTextAndSpeed() {
        store.text = "script"
        store.speed = 120
        let reloaded = UserDefaultsStore(defaults: defaults)
        XCTAssertEqual(reloaded.text, "script")
        XCTAssertEqual(reloaded.speed, 120)
    }
}
```

- [ ] **Step 2: Run to verify it passes**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*UserDefaultsStore|error:|TEST (SUCCEEDED|FAILED)"`
Expected: 2 tests `passed`. If it fails, the Task 3 implementation has a bug; fix it there.

- [ ] **Step 3: Commit**

```bash
git add NotchPrompterTests/UserDefaultsStoreTests.swift
git commit -m "test: UserDefaultsStore coverage"
```

---

### Task 5: PrompterView

**Files:**
- Create: `NotchPrompter/Views/PrompterView.swift`

**Interfaces:**
- Consumes: `PrompterEngine` (`text`, `offset`, `speed`, `isPlaying`, `contentHeight`).
- Produces: `struct PrompterView: View { init(engine: PrompterEngine) }`.

No unit tests: it's pure rendering. Verified visually in Task 6 and in the final manual verification.

- [ ] **Step 1: Implement `NotchPrompter/Views/PrompterView.swift`**

```swift
import SwiftUI

struct PrompterView: View {
    @ObservedObject var engine: PrompterEngine
    @State private var showSpeedBadge = false
    @State private var badgeTask: Task<Void, Never>?

    private let cornerRadius: CGFloat = 16
    private let fontSize: CGFloat = 34
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black
                if engine.text.isEmpty {
                    placeholder
                } else {
                    scrollingText(viewportHeight: geo.size.height)
                        .opacity(engine.isPlaying ? 1 : 0.6)
                    fades
                }
                speedBadge
            }
        }
        .clipShape(UnevenRoundedRectangle(
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius
        ))
        .onChange(of: engine.speed) { _, _ in flashSpeedBadge() }
    }

    private var placeholder: some View {
        Text("Write your script from the menu")
            .font(.system(size: 18))
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scrollingText(viewportHeight: CGFloat) -> some View {
        Text(engine.text)
            .font(.system(size: fontSize, weight: .medium))
            .lineSpacing(fontSize * 0.3)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, viewportHeight)
            .background(
                GeometryReader { textGeo in
                    Color.clear.onAppear { engine.contentHeight = textGeo.size.height }
                        .onChange(of: textGeo.size.height) { _, h in engine.contentHeight = h }
                }
            )
            .offset(y: -engine.offset)
    }

    private var fades: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            Spacer()
            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 44)
        }
        .allowsHitTesting(false)
    }

    private var speedBadge: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                Text("\(Int(engine.speed))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                    .padding(8)
                    .opacity(showSpeedBadge ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: showSpeedBadge)
            }
        }
    }

    private func flashSpeedBadge() {
        badgeTask?.cancel()
        showSpeedBadge = true
        badgeTask = Task {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled { showSpeedBadge = false }
        }
    }
}
```

Note on `contentHeight`: it includes the top padding equal to the viewport, so the text enters from below and the scroll ends when the last line exits at the top.

- [ ] **Step 2: Verify it builds**

Run: `xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add NotchPrompter/Views/PrompterView.swift
git commit -m "feat: teleprompter view with fades and speed badge"
```

---

### Task 6: PrompterPanel and the AppDelegate that shows it

**Files:**
- Create: `NotchPrompter/Window/PrompterPanel.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (full replacement)

**Interfaces:**
- Consumes: `NotchGeometry.panelFrame`, `PrompterView`, `PrompterEngine`, `DisplayLinkClock`, `UserDefaultsStore`.
- Produces:
  ```swift
  final class PrompterPanel: NSPanel { init(engine: PrompterEngine); func reposition() }
  final class AppDelegate: NSObject, NSApplicationDelegate {
      let engine: PrompterEngine
      func togglePanel()
      var isPanelVisible: Bool
  }
  ```

- [ ] **Step 1: Implement `NotchPrompter/Window/PrompterPanel.swift`**

```swift
import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating panel that floats over everything, pinned to the notch.
final class PrompterPanel: NSPanel {
    private var cancellables = Set<AnyCancellable>()

    init(engine: PrompterEngine) {
        super.init(
            contentRect: CGRect(origin: .zero, size: NotchGeometry.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        contentView = NSHostingView(rootView: PrompterView(engine: engine))

        // The panel has no interactive content, so it always ignores the mouse.
        ignoresMouseEvents = true

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)

        reposition()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen.frame,
            topLeftArea: screen.auxiliaryTopLeftArea,
            topRightArea: screen.auxiliaryTopRightArea
        )
        setFrame(frame, display: true)
    }
}
```

- [ ] **Step 2: Replace `NotchPrompter/NotchPrompterApp.swift`**

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button(delegate.isPanelVisible ? "Hide Panel" : "Show Panel") {
                delegate.togglePanel()
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let engine = PrompterEngine(clock: DisplayLinkClock(), store: UserDefaultsStore())
    private var panel: PrompterPanel?
    @Published private(set) var isPanelVisible = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        showPanel()
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        if panel == nil { panel = PrompterPanel(engine: engine) }
        panel?.reposition()
        panel?.orderFrontRegardless()
        isPanelVisible = true
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        engine.pause()
        isPanelVisible = false
    }
}
```

- [ ] **Step 3: Build and run the app**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected: `BUILD SUCCEEDED`. The icon appears in the menu bar and a black panel with the placeholder "Write your script from the menu" hangs from the notch, centered. "Hide Panel" hides it, "Show Panel" shows it again. Close the app from the menu before continuing.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Window/PrompterPanel.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: floating panel over the notch and menu bar item"
```

---

### Task 7: Global hotkeys with Carbon

**Files:**
- Create: `NotchPrompter/Input/HotKeys.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (AppDelegate: register and dispatch; menu: shortcuts submenu with failures)

**Interfaces:**
- Consumes: `AppDelegate.engine`, `AppDelegate.togglePanel()`.
- Produces:
  ```swift
  final class HotKeyCenter {
      enum Action: UInt32, CaseIterable { case togglePlay = 1, speedUp, speedDown, reset, toggleVisibility
          var label: String }
      var handler: ((Action) -> Void)?
      private(set) var failed: [Action]
      func register()
      func unregister()
  }
  ```

- [ ] **Step 1: Implement `NotchPrompter/Input/HotKeys.swift`**

```swift
import Carbon
import Foundation

/// Global hotkeys via Carbon. Does not require Accessibility permission.
final class HotKeyCenter {
    enum Action: UInt32, CaseIterable {
        case togglePlay = 1
        case speedUp
        case speedDown
        case reset
        case toggleVisibility

        var keyCode: UInt32 {
            switch self {
            case .togglePlay: return UInt32(kVK_Space)
            case .speedUp: return UInt32(kVK_UpArrow)
            case .speedDown: return UInt32(kVK_DownArrow)
            case .reset: return UInt32(kVK_ANSI_R)
            case .toggleVisibility: return UInt32(kVK_ANSI_T)
            }
        }

        var label: String {
            switch self {
            case .togglePlay: return "⌃⌥ Space  Play / pause"
            case .speedUp: return "⌃⌥ ↑  Speed +10"
            case .speedDown: return "⌃⌥ ↓  Speed -10"
            case .reset: return "⌃⌥ R  Back to start"
            case .toggleVisibility: return "⌃⌥ T  Show / hide panel"
            }
        }
    }

    var handler: ((Action) -> Void)?
    private(set) var failed: [Action] = []

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = 0x4E50524D // "NPRM"
    private static let modifiers = UInt32(controlKey | optionKey)

    func register() {
        unregister()
        installEventHandler()
        for action in Action.allCases {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: action.rawValue)
            let status = RegisterEventHotKey(
                action.keyCode, Self.modifiers, id,
                GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
            } else {
                failed.append(action)
            }
        }
    }

    func unregister() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        failed.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == HotKeyCenter.signature,
                      let action = Action(rawValue: hotKeyID.id) else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                center.handler?(action)
                return noErr
            },
            1,
            &spec,
            userData,
            &eventHandlerRef
        )
    }

    deinit { unregister() }
}
```

- [ ] **Step 2: Wire it up in `AppDelegate` and add the shortcuts submenu**

Replace `NotchPrompter/NotchPrompterApp.swift` in full:

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button(delegate.isPanelVisible ? "Hide Panel" : "Show Panel") {
                delegate.togglePanel()
            }
            Menu("Shortcuts") {
                ForEach(HotKeyCenter.Action.allCases, id: \.rawValue) { action in
                    if delegate.failedHotKeys.contains(action) {
                        Text("\(action.label)  (unavailable)")
                    } else {
                        Text(action.label)
                    }
                }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let engine = PrompterEngine(clock: DisplayLinkClock(), store: UserDefaultsStore())
    private var panel: PrompterPanel?
    private let hotKeys = HotKeyCenter()
    @Published private(set) var isPanelVisible = false
    @Published private(set) var failedHotKeys: [HotKeyCenter.Action] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeys.handler = { [weak self] action in
            Task { @MainActor in self?.handle(action) }
        }
        hotKeys.register()
        failedHotKeys = hotKeys.failed
        showPanel()
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    private func handle(_ action: HotKeyCenter.Action) {
        switch action {
        case .togglePlay: engine.togglePlay()
        case .speedUp: engine.increaseSpeed()
        case .speedDown: engine.decreaseSpeed()
        case .reset: engine.reset()
        case .toggleVisibility: togglePanel()
        }
    }

    private func showPanel() {
        if panel == nil { panel = PrompterPanel(engine: engine) }
        panel?.reposition()
        panel?.orderFrontRegardless()
        isPanelVisible = true
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        engine.pause()
        isPanelVisible = false
    }
}
```

- [ ] **Step 3: Build and test manually**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected: with another app in focus (for example Finder), ⌃⌥T hides and shows the panel. The Shortcuts submenu lists all 5 without "(unavailable)". Play and speed can't be seen yet because there's no text; that's tested in Task 8. Close the app.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Input/HotKeys.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: global hotkeys with Carbon"
```

---

### Task 8: Script editor

**Files:**
- Create: `NotchPrompter/Views/ScriptEditorView.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (add `Window` scene and "Edit Script…" button)

**Interfaces:**
- Consumes: `PrompterEngine.text`.
- Produces: `struct ScriptEditorView: View { init(engine: PrompterEngine) }`.

- [ ] **Step 1: Implement `NotchPrompter/Views/ScriptEditorView.swift`**

```swift
import SwiftUI

/// Temporary buffer for the script while the editor window is open.
/// The engine is only updated when the window closes (see `AppDelegate.windowWillClose`).
@MainActor
final class ScriptDraft: ObservableObject {
    @Published var text: String

    init(text: String) {
        self.text = text
    }
}

struct ScriptEditorView: View {
    @ObservedObject var draft: ScriptDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script")
                .font(.headline)
            TextEditor(text: $draft.text)
                .font(.system(size: 15))
                .frame(minWidth: 420, minHeight: 280)
            Text("Saved when this window closes. The panel goes back to the start.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
```

Note: the script is committed to `engine.text` only when the window closes (`windowWillClose`), not on every keystroke; `engine.text.didSet` saves it to the store and resets the offset at that point.

- [ ] **Step 2: Open the editor as an `NSWindow` from the `AppDelegate`**

Do not use a SwiftUI `Window` scene: with `LSUIElement` it could only be opened on launch. The editor is handled manually.

In `NotchPrompter/NotchPrompterApp.swift`, add the button at the top of the `MenuBarExtra`:

```swift
            Button("Edit Script…") { delegate.openEditor() }
```

And in `AppDelegate` (which now also conforms to `NSWindowDelegate`), add the `draft` property, the `openEditor()` method, and `windowWillClose(_:)`:

```swift
    private var editorWindow: NSWindow?
    private let draft = ScriptDraft(text: "")

    func openEditor() {
        draft.text = engine.text
        if editorWindow == nil {
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 480, height: 360),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Script"
            window.contentView = NSHostingView(rootView: ScriptEditorView(draft: draft))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            editorWindow = window
        }
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === editorWindow else { return }
        if draft.text != engine.text {
            engine.text = draft.text
        }
    }
```

The full `body` of the `App` becomes:

```swift
    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button("Edit Script…") { delegate.openEditor() }
            Button(delegate.isPanelVisible ? "Hide Panel" : "Show Panel") {
                delegate.togglePanel()
            }
            Menu("Shortcuts") {
                ForEach(HotKeyCenter.Action.allCases, id: \.rawValue) { action in
                    if delegate.failedHotKeys.contains(action) {
                        Text("\(action.label)  (unavailable)")
                    } else {
                        Text(action.label)
                    }
                }
            }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
```

- [ ] **Step 3: Build and test the full flow**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected:
1. Menu > Edit Script… opens the window. Paste 6 or 7 paragraphs.
2. The panel shows the text in white at 60% (paused).
3. Close the editor, click on Finder, ⌃⌥Space: the text scrolls up and reaches 100%.
4. ⌃⌥↑ shows "70" in the corner for a second and the text speeds up.
5. ⌃⌥R returns to the start and pauses.
6. Close the app and reopen it: the script and speed persist.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Views/ScriptEditorView.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: script editor with persistence"
```

---

### Task 9: Manual verification with recording and README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Run the full suite**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case|TEST (SUCCEEDED|FAILED)"`
Expected: 19 tests `passed` (4 geometry + 13 engine + 2 store; excluding `SmokeTests`, whose only test didn't verify anything), `** TEST SUCCEEDED **`.

- [ ] **Step 2: Test with QuickTime**

1. Open QuickTime Player > File > New Screen Recording.
2. Open NotchPrompter. The panel should appear on top of QuickTime.
3. With QuickTime in focus, ⌃⌥Space starts the scroll. QuickTime does not lose focus.
4. Put QuickTime in fullscreen (green button). The panel remains visible.
5. Read a 1-minute script at speed 60. Note whether 60 feels comfortable or `PrompterEngine.defaultSpeed` needs to change.

If any of these fail, it's a bug: apply superpowers:systematic-debugging before touching the code.

- [ ] **Step 3: Write `README.md`**

```markdown
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
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README with build, tests and shortcuts"
```
