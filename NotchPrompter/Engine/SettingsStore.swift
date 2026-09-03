import Foundation

/// Persists the script text and scroll speed. Injectable for tests.
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
