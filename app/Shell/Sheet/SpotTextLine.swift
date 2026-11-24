import SwiftUI

struct SpotTextLine: View {
    let label: String
    let text: String
    let onSet: (String) -> Void
    @State private var selection: TextSelection?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(label, text: Binding(get: { text }, set: { onSet($0) }), selection: $selection, prompt: Text(""))
            .textFieldStyle(.plain)
            .labelsHidden()
            .focused($isFocused)
            .onChange(of: isFocused) { _, isFocused in
                if isFocused { selection = TextSelection(insertionPoint: text.endIndex) }
            }
    }
}
