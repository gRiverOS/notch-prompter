import SwiftUI

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

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
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    let engine = PrompterEngine(clock: DisplayLinkClock(), store: UserDefaultsStore())
    private var panel: PrompterPanel?
    private var editorWindow: NSWindow?
    private let draft = ScriptDraft(text: "")
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
