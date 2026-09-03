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
        // Las apps LSUIElement pueden ver `NSScreen.main` nil transitoriamente
        // (p. ej. justo al lanzar, sin ventana key); usamos la primera pantalla como respaldo.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
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
