import SwiftUI

struct SpotTextArea: View {
    let text: String
    let onSet: (String) -> Void
    @State private var typed = ""

    var body: some View {
        TextEditor(text: $typed)
            .scrollContentBackground(.hidden)
            .onAppear { typed = text }
            .onChange(of: text) { _, new in if new != typed { typed = new } }
            .onChange(of: typed) { _, new in if new != text { onSet(new) } }
    }
}
