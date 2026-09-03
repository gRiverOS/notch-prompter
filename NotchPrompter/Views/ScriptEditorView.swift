import SwiftUI

struct ScriptEditorView: View {
    @ObservedObject var engine: PrompterEngine
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guion")
                .font(.headline)
            TextEditor(text: $draft)
                .font(.system(size: 15))
                .frame(minWidth: 420, minHeight: 280)
            Text("Se guarda solo. Al cerrar, el panel vuelve al inicio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .onAppear { draft = engine.text }
        .onChange(of: draft) { _, new in
            if new != engine.text { engine.text = new }
        }
    }
}
