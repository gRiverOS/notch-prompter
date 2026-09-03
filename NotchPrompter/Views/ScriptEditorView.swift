import SwiftUI

/// Buffer temporal del guion mientras la ventana de edición está abierta.
/// El motor solo se actualiza cuando la ventana se cierra (ver `AppDelegate.windowWillClose`).
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
            Text("Guion")
                .font(.headline)
            TextEditor(text: $draft.text)
                .font(.system(size: 15))
                .frame(minWidth: 420, minHeight: 280)
            Text("Se guarda al cerrar esta ventana. El panel vuelve al inicio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
