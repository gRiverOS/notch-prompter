# NotchPrompter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teleprompter nativo de macOS que cuelga del notch, con scroll automático de velocidad ajustable y atajos globales, para grabar videos hablando a cámara.

**Architecture:** App de barra de menú (`LSUIElement`) con un `NSPanel` no activante que flota sobre todo, incluso fullscreen, pegado al borde superior de la pantalla centrado en el notch. Un `PrompterEngine` puro (sin UI) avanza el offset con un reloj inyectable y persiste texto y velocidad. SwiftUI dibuja el texto; Carbon `RegisterEventHotKey` provee los atajos globales sin permisos.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, Carbon (HotKeys), XCTest, XcodeGen, macOS 14+. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-09-03-notch-prompter-design.md`

## Global Constraints

- Deployment target: macOS 14.0 (usa `NSScreen.displayLink`).
- Sin paquetes externos. Solo frameworks de Apple.
- `LSUIElement = true`: sin ícono en Dock, sin ventana principal.
- Panel: 560 x 130 pt, esquinas inferiores 16 pt, fondo negro.
- Velocidad: rango 20...200 pt/s, default 60, paso 10.
- Tipografía: SF Pro 34 pt, blanco, interlineado 1.3, sin `minimumScaleFactor`.
- Atajos fijos con ⌃⌥: Espacio (play/pausa), ↑/↓ (velocidad), R (reset), T (mostrar/ocultar).
- Texto vacío muestra: "Escribe tu guion desde el menú".
- Bundle id prefix: `cl.gustavo`.
- Comando de tests: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS'`.

---

## File Structure

```
project.yml                                  # XcodeGen: 2 targets (app + tests)
NotchPrompter/
  NotchPrompterApp.swift                     # @main, MenuBarExtra, Window del editor, AppDelegate
  Info.plist                                 # LSUIElement
  Window/NotchGeometry.swift                 # cálculo puro del frame del panel
  Window/PrompterPanel.swift                 # NSPanel configurado + reposición
  Engine/FrameClock.swift                    # protocolo + DisplayLinkClock
  Engine/SettingsStore.swift                 # protocolo + UserDefaultsStore
  Engine/PrompterEngine.swift                # estado y reglas del scroll
  Views/PrompterView.swift                   # render del texto en el panel
  Views/ScriptEditorView.swift               # TextEditor del guion
  Input/HotKeys.swift                        # Carbon hotkeys
NotchPrompterTests/
  NotchGeometryTests.swift
  PrompterEngineTests.swift
  UserDefaultsStoreTests.swift
```

---

### Task 1: Scaffold del proyecto con XcodeGen

**Files:**
- Create: `project.yml`
- Create: `NotchPrompter/Info.plist`
- Create: `NotchPrompter/NotchPrompterApp.swift`
- Create: `NotchPrompterTests/SmokeTests.swift`
- Create: `.gitignore`

**Interfaces:**
- Produces: proyecto `NotchPrompter.xcodeproj` generado, scheme `NotchPrompter` con tests. Los demás tasks solo agregan archivos bajo `NotchPrompter/` y `NotchPrompterTests/` y regeneran con `xcodegen`.

- [ ] **Step 1: Instalar XcodeGen**

Run: `brew install xcodegen`
Expected: `xcodegen --version` imprime una versión.

- [ ] **Step 2: Crear `project.yml`**

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

- [ ] **Step 3: Crear `.gitignore`**

```
*.xcodeproj
DerivedData/
xcuserdata/
.DS_Store
```

- [ ] **Step 4: Crear `NotchPrompter/Info.plist`**

XcodeGen genera el plist desde `info.properties`, pero necesita que el archivo exista. Crear con contenido mínimo, XcodeGen lo sobreescribe:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 5: Crear app mínima `NotchPrompter/NotchPrompterApp.swift`**

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button("Salir") { NSApplication.shared.terminate(nil) }
        }
    }
}
```

- [ ] **Step 6: Crear test de humo `NotchPrompterTests/SmokeTests.swift`**

```swift
import XCTest
@testable import NotchPrompter

final class SmokeTests: XCTestCase {
    func testModuleLinks() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 7: Generar el proyecto y correr tests**

Run:
```bash
xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case|error:|TEST (SUCCEEDED|FAILED)"
```
Expected: `Test Case '-[NotchPrompterTests.SmokeTests testModuleLinks]' passed` y `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add project.yml .gitignore NotchPrompter NotchPrompterTests
git commit -m "chore: scaffold NotchPrompter con XcodeGen"
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
  Coordenadas AppKit (origen abajo a la izquierda). El frame queda pegado al borde superior (`maxY`) de `screenFrame`.

- [ ] **Step 1: Escribir los tests que fallan**

```swift
import XCTest
@testable import NotchPrompter

final class NotchGeometryTests: XCTestCase {
    // MacBook Pro 14": pantalla 1512x982, notch de 38 pt entre las áreas auxiliares.
    let mbp14 = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let leftArea = CGRect(x: 0, y: 944, width: 700, height: 38)
    let rightArea = CGRect(x: 820, y: 944, width: 692, height: 38)

    func testPanelIsCenteredOnNotchAndPinnedToTop() {
        let frame = NotchGeometry.panelFrame(screenFrame: mbp14, topLeftArea: leftArea, topRightArea: rightArea)
        // Centro del notch = (700 + 820) / 2 = 760
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

- [ ] **Step 2: Correr para verificar que falla**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: error de compilación `cannot find 'NotchGeometry' in scope`.

- [ ] **Step 3: Implementar `NotchPrompter/Window/NotchGeometry.swift`**

```swift
import CoreGraphics

/// Cálculo puro del frame del panel a partir de la geometría de la pantalla.
/// Coordenadas AppKit: origen abajo a la izquierda, Y crece hacia arriba.
enum NotchGeometry {
    static let panelSize = CGSize(width: 560, height: 130)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea` (nil si no hay notch).
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea` (nil si no hay notch).
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

- [ ] **Step 4: Correr para verificar que pasa**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*NotchGeometry|TEST (SUCCEEDED|FAILED)"`
Expected: 4 tests `passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add NotchPrompter/Window/NotchGeometry.swift NotchPrompterTests/NotchGeometryTests.swift
git commit -m "feat: geometría del panel sobre el notch"
```

---

### Task 3: FrameClock, SettingsStore y PrompterEngine

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
  final class DisplayLinkClock: FrameClock   // producción, usa NSScreen.displayLink

  protocol SettingsStore: AnyObject {
      var text: String { get set }
      var speed: Double { get set }
  }
  final class InMemoryStore: SettingsStore   // solo tests (vive en el target de tests)

  @MainActor final class PrompterEngine: ObservableObject {
      static let speedRange: ClosedRange<Double>  // 20...200
      static let speedStep: Double                // 10
      static let defaultSpeed: Double             // 60
      @Published var text: String
      @Published private(set) var offset: CGFloat
      @Published private(set) var speed: Double
      @Published private(set) var isPlaying: Bool
      var contentHeight: CGFloat                  // lo setea la vista
      init(clock: FrameClock, store: SettingsStore)
      func tick(dt: TimeInterval)
      func togglePlay()
      func increaseSpeed()
      func decreaseSpeed()
      func reset()
  }
  ```

- [ ] **Step 1: Escribir los tests que fallan**

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
        store.text = "hola"
        store.speed = 90
        let e = PrompterEngine(clock: clock, store: store)
        XCTAssertEqual(e.text, "hola")
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
        engine.text = "nuevo guion"
        XCTAssertEqual(store.text, "nuevo guion")
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
        engine.text = "otro"
        XCTAssertEqual(engine.offset, 0)
        XCTAssertFalse(engine.isPlaying)
    }
}
```

- [ ] **Step 2: Correr para verificar que falla**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"`
Expected: errores `cannot find type 'FrameClock'`, `'SettingsStore'`, `'PrompterEngine'`.

- [ ] **Step 3: Implementar `NotchPrompter/Engine/FrameClock.swift`**

```swift
import AppKit
import QuartzCore

/// Fuente de ticks por frame. Inyectable para testear el motor sin UI.
protocol FrameClock: AnyObject {
    func start(onTick: @escaping (TimeInterval) -> Void)
    func stop()
}

/// Implementación real sobre CADisplayLink de NSScreen (macOS 14+).
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

- [ ] **Step 4: Implementar `NotchPrompter/Engine/SettingsStore.swift`**

```swift
import Foundation

/// Persistencia de texto y velocidad. Inyectable para tests.
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

- [ ] **Step 5: Implementar `NotchPrompter/Engine/PrompterEngine.swift`**

```swift
import Foundation
import CoreGraphics

/// Estado y reglas del teleprompter. Sin dependencias de UI.
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

    /// Altura total del contenido desplazable. La vista la informa al medirse.
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

Nota: `text.didSet` llama a `reset()`, que llama a `pause()`. `pause()` solo detiene el reloj si estaba reproduciendo, así `stopCount` no se infla en los tests.

- [ ] **Step 6: Correr para verificar que pasa**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*PrompterEngine|error:|TEST (SUCCEEDED|FAILED)"`
Expected: 12 tests `passed`, `** TEST SUCCEEDED **`. Si `clock.start` dentro de `init` da error de concurrencia, el closure ya captura `self` débil dentro de un contexto `@MainActor`; agregar `@MainActor` al closure: `clock.start { [weak self] dt in Task { @MainActor in self?.tick(dt: dt) } }` NO es aceptable porque rompe el test `testClockTicksReachEngine` (sincrónico). Usar `MainActor.assumeIsolated { self?.tick(dt: dt) }` en su lugar si el compilador lo exige.

- [ ] **Step 7: Commit**

```bash
git add NotchPrompter/Engine NotchPrompterTests/PrompterEngineTests.swift
git commit -m "feat: motor de scroll con reloj y store inyectables"
```

---

### Task 4: Tests de UserDefaultsStore

**Files:**
- Test: `NotchPrompterTests/UserDefaultsStoreTests.swift`

**Interfaces:**
- Consumes: `UserDefaultsStore(defaults:)` de Task 3.

- [ ] **Step 1: Escribir los tests**

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
        store.text = "guion"
        store.speed = 120
        let reloaded = UserDefaultsStore(defaults: defaults)
        XCTAssertEqual(reloaded.text, "guion")
        XCTAssertEqual(reloaded.speed, 120)
    }
}
```

- [ ] **Step 2: Correr para verificar que pasa**

Run: `xcodegen generate && xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case.*UserDefaultsStore|error:|TEST (SUCCEEDED|FAILED)"`
Expected: 2 tests `passed`. Si falla, la implementación de Task 3 tiene un bug; arreglar ahí.

- [ ] **Step 3: Commit**

```bash
git add NotchPrompterTests/UserDefaultsStoreTests.swift
git commit -m "test: cobertura de UserDefaultsStore"
```

---

### Task 5: PrompterView

**Files:**
- Create: `NotchPrompter/Views/PrompterView.swift`

**Interfaces:**
- Consumes: `PrompterEngine` (`text`, `offset`, `speed`, `isPlaying`, `contentHeight`).
- Produces: `struct PrompterView: View { init(engine: PrompterEngine) }`.

Sin tests unitarios: es render puro. Se verifica visualmente en Task 6 y en la verificación manual final.

- [ ] **Step 1: Implementar `NotchPrompter/Views/PrompterView.swift`**

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
        Text("Escribe tu guion desde el menú")
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

Nota sobre `contentHeight`: incluye el padding superior igual al viewport, así el texto entra desde abajo y el scroll termina cuando la última línea sale por arriba.

- [ ] **Step 2: Verificar que compila**

Run: `xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add NotchPrompter/Views/PrompterView.swift
git commit -m "feat: vista del teleprompter con fades y badge de velocidad"
```

---

### Task 6: PrompterPanel y AppDelegate que lo muestra

**Files:**
- Create: `NotchPrompter/Window/PrompterPanel.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (reemplazar completo)

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

- [ ] **Step 1: Implementar `NotchPrompter/Window/PrompterPanel.swift`**

```swift
import AppKit
import SwiftUI
import Combine

/// Panel sin borde, no activante, que flota sobre todo pegado al notch.
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

        // El panel no tiene contenido interactivo, así que siempre ignora el mouse.
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

- [ ] **Step 2: Reemplazar `NotchPrompter/NotchPrompterApp.swift`**

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button(delegate.isPanelVisible ? "Ocultar panel" : "Mostrar panel") {
                delegate.togglePanel()
            }
            Divider()
            Button("Salir") { NSApplication.shared.terminate(nil) }
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

- [ ] **Step 3: Compilar y correr la app**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected: `BUILD SUCCEEDED`. Aparece el ícono en la barra de menú y un panel negro con el placeholder "Escribe tu guion desde el menú" colgando del notch, centrado. "Ocultar panel" lo esconde, "Mostrar panel" lo vuelve a mostrar. Cerrar la app desde el menú antes de seguir.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Window/PrompterPanel.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: panel flotante sobre el notch y menú de barra"
```

---

### Task 7: HotKeys globales con Carbon

**Files:**
- Create: `NotchPrompter/Input/HotKeys.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (AppDelegate: registrar y despachar; menú: submenú de atajos con fallos)

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

- [ ] **Step 1: Implementar `NotchPrompter/Input/HotKeys.swift`**

```swift
import Carbon
import Foundation

/// Atajos globales vía Carbon. No requiere permiso de Accesibilidad.
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
            case .togglePlay: return "⌃⌥ Espacio  Play / pausa"
            case .speedUp: return "⌃⌥ ↑  Velocidad +10"
            case .speedDown: return "⌃⌥ ↓  Velocidad -10"
            case .reset: return "⌃⌥ R  Volver al inicio"
            case .toggleVisibility: return "⌃⌥ T  Mostrar / ocultar panel"
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

- [ ] **Step 2: Conectar en `AppDelegate` y agregar submenú de atajos**

Reemplazar `NotchPrompter/NotchPrompterApp.swift` completo:

```swift
import SwiftUI

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button(delegate.isPanelVisible ? "Ocultar panel" : "Mostrar panel") {
                delegate.togglePanel()
            }
            Menu("Atajos") {
                ForEach(HotKeyCenter.Action.allCases, id: \.rawValue) { action in
                    if delegate.failedHotKeys.contains(action) {
                        Text("\(action.label)  (no disponible)")
                    } else {
                        Text(action.label)
                    }
                }
            }
            Divider()
            Button("Salir") { NSApplication.shared.terminate(nil) }
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

- [ ] **Step 3: Compilar y probar a mano**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected: con otra app en foco (por ejemplo Finder), ⌃⌥T oculta y muestra el panel. El submenú Atajos lista los 5 sin "(no disponible)". Play y velocidad no se pueden ver todavía porque no hay texto; eso se prueba en Task 8. Cerrar la app.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Input/HotKeys.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: atajos globales con Carbon"
```

---

### Task 8: Editor de guion

**Files:**
- Create: `NotchPrompter/Views/ScriptEditorView.swift`
- Modify: `NotchPrompter/NotchPrompterApp.swift` (agregar `Window` scene y botón "Editar guion…")

**Interfaces:**
- Consumes: `PrompterEngine.text`.
- Produces: `struct ScriptEditorView: View { init(engine: PrompterEngine) }`.

- [ ] **Step 1: Implementar `NotchPrompter/Views/ScriptEditorView.swift`**

```swift
import SwiftUI

/// Buffer temporal del guion mientras la ventana de edición está abierta.
/// El motor solo se actualiza cuando la ventana se cierra (ver `AppDelegate.windowWillClose`).
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
            Text("Guion")
                .font(.headline)
            TextEditor(text: $draft.text)
                .font(.system(size: 15))
                .frame(minWidth: 420, minHeight: 280)
            Text("Se guarda al cerrar esta ventana. El panel vuelve al inicio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
```

Nota: el guion se confirma en `engine.text` solo al cerrar la ventana (`windowWillClose`), no en cada tecla; `engine.text.didSet` guarda en el store y resetea el offset en ese momento.

- [ ] **Step 2: Abrir el editor como `NSWindow` desde el `AppDelegate`**

No usar un `Window` scene de SwiftUI: con `LSUIElement` puede abrirse solo al lanzar. El editor se maneja a mano.

En `NotchPrompter/NotchPrompterApp.swift`, agregar al inicio del `MenuBarExtra` el botón:

```swift
            Button("Editar guion…") { delegate.openEditor() }
```

Y en `AppDelegate` (que ahora también conforma `NSWindowDelegate`), agregar la propiedad `draft`, el método `openEditor()` y `windowWillClose(_:)`:

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
            window.title = "Guion"
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

El `body` completo del `App` queda:

```swift
    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button("Editar guion…") { delegate.openEditor() }
            Button(delegate.isPanelVisible ? "Ocultar panel" : "Mostrar panel") {
                delegate.togglePanel()
            }
            Menu("Atajos") {
                ForEach(HotKeyCenter.Action.allCases, id: \.rawValue) { action in
                    if delegate.failedHotKeys.contains(action) {
                        Text("\(action.label)  (no disponible)")
                    } else {
                        Text(action.label)
                    }
                }
            }
            Divider()
            Button("Salir") { NSApplication.shared.terminate(nil) }
        }
    }
```

- [ ] **Step 3: Compilar y probar el flujo completo**

Run:
```bash
xcodegen generate && xcodebuild build -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' -derivedDataPath DerivedData 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" && open DerivedData/Build/Products/Debug/NotchPrompter.app
```
Expected:
1. Menú > Editar guion… abre la ventana. Pegar 6 o 7 párrafos.
2. El panel muestra el texto en blanco a 60 % (en pausa).
3. Cerrar el editor, hacer clic en Finder, ⌃⌥Espacio: el texto sube y queda a 100 %.
4. ⌃⌥↑ muestra "70" en la esquina por un segundo y el texto acelera.
5. ⌃⌥R vuelve al inicio y pausa.
6. Cerrar la app y volver a abrirla: el guion y la velocidad persisten.

- [ ] **Step 4: Commit**

```bash
git add NotchPrompter/Views/ScriptEditorView.swift NotchPrompter/NotchPrompterApp.swift
git commit -m "feat: editor de guion con persistencia"
```

---

### Task 9: Verificación manual con grabación y README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Correr la suite completa**

Run: `xcodebuild test -project NotchPrompter.xcodeproj -scheme NotchPrompter -destination 'platform=macOS' 2>&1 | grep -E "Test Case|TEST (SUCCEEDED|FAILED)"`
Expected: 19 tests `passed` (4 geometría + 13 motor + 2 store; sin `SmokeTests`, cuya única prueba no verificaba nada), `** TEST SUCCEEDED **`.

- [ ] **Step 2: Prueba con QuickTime**

1. Abrir QuickTime Player > Archivo > Nueva grabación de video.
2. Abrir NotchPrompter. El panel debe verse encima de QuickTime.
3. Con QuickTime en foco, ⌃⌥Espacio arranca el scroll. QuickTime no pierde el foco.
4. Poner QuickTime en pantalla completa (botón verde). El panel sigue visible.
5. Leer un guion de 1 minuto a velocidad 60. Anotar si 60 es cómodo o hay que cambiar `PrompterEngine.defaultSpeed`.

Si alguno falla, es un bug: aplicar superpowers:systematic-debugging antes de tocar código.

- [ ] **Step 3: Escribir `README.md`**

```markdown
# NotchPrompter

Teleprompter para macOS que cuelga del notch. Pensado para grabar videos hablando a cámara: el texto queda justo bajo el lente.

## Requisitos

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

## Atajos (globales, con ⌃⌥)

| Atajo | Acción |
|---|---|
| ⌃⌥ Espacio | Play / pausa |
| ⌃⌥ ↑ / ↓ | Velocidad +10 / -10 |
| ⌃⌥ R | Volver al inicio |
| ⌃⌥ T | Mostrar / ocultar panel |

El guion se edita desde el ícono de la barra de menú y se guarda solo.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README con build, tests y atajos"
```
