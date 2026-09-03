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
            MainActor.assumeIsolated {
                self?.tick(dt: dt)
            }
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
