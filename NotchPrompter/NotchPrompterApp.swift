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
        engine.reset()
        isPanelVisible = false
    }
}
