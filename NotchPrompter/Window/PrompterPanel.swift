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

        engine.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in self?.ignoresMouseEvents = playing }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)

        reposition()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        // NSScreen.main puede ser nil transitoriamente (reconfiguración de pantalla, sleep/wake)
        // en una app LSUIElement no activante; usamos el primer screen disponible como respaldo.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen.frame,
            topLeftArea: screen.auxiliaryTopLeftArea,
            topRightArea: screen.auxiliaryTopRightArea
        )
        setFrame(frame, display: true)
    }
}
