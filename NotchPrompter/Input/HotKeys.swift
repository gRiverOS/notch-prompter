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
                      let action = HotKeyCenter.Action(rawValue: hotKeyID.id) else { return noErr }
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
