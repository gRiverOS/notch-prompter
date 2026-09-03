import SwiftUI

/// Temporary script buffer while the editor window is open.
/// The engine is only updated when the window closes (see `AppDelegate.windowWillClose`).
@MainActor
final class ScriptDraft: ObservableObject {
    @Published var text: String

    init(text: String) {
        self.text = text
    }
}

struct ScriptEditorView: View {
    @ObservedObject var draft: ScriptDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Script")
                .font(.headline)
            TextEditor(text: $draft.text)
                .font(.system(size: 15))
                .frame(minWidth: 420, minHeight: 280)
            Text("Saved when this window closes. The panel goes back to the start.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
