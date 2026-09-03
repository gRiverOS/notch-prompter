import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating panel that floats above everything, pinned to the notch.
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

        // The panel has no interactive content, so it always ignores the mouse
        // (avoids stealing clicks from the menu bar or other apps while visible).
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
        // NSScreen.main can transiently be nil (display reconfiguration, sleep/wake)
        // in a non-activating LSUIElement app; fall back to the first available screen.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen.frame,
            topLeftArea: screen.auxiliaryTopLeftArea,
            topRightArea: screen.auxiliaryTopRightArea
        )
        setFrame(frame, display: true)
    }
}
