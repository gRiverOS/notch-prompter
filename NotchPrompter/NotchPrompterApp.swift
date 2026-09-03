import SwiftUI

@main
struct NotchPrompterApp: App {
    var body: some Scene {
        MenuBarExtra("NotchPrompter", systemImage: "text.alignleft") {
            Button("Salir") { NSApplication.shared.terminate(nil) }
        }
    }
}
