import AppKit
import QuartzCore

/// Per-frame tick source. Injectable so the engine can be tested without UI.
protocol FrameClock: AnyObject {
    func start(onTick: @escaping (TimeInterval) -> Void)
    func stop()
}

/// Production implementation backed by NSScreen's CADisplayLink (macOS 14+).
final class DisplayLinkClock: FrameClock {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var onTick: ((TimeInterval) -> Void)?

    func start(onTick: @escaping (TimeInterval) -> Void) {
        stop()
        self.onTick = onTick
        lastTimestamp = nil
        // LSUIElement apps can transiently see `NSScreen.main` as nil
        // (e.g. right after launch, with no key window); fall back to the first screen.
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
