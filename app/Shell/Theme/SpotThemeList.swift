import OpenspotCore
import SwiftUI

struct SpotThemeList: View {
    @Bindable var model: SpotThemeModel
    @State private var name = ""
    @FocusState private var isNaming: Bool

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { model.inUse }, set: { if let name = $0 { model.use(name) } })) {
                ForEach(model.names, id: \.self) { theme in
                    row(theme).tag(theme)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onDeleteCommand { if !model.isBuiltIn { model.delete(model.inUse) } }
            Divider()
            HStack(spacing: SpotTokens.menuPadding) {
                button("plus", "New") { model.make() }
                button("plus.square.on.square", "Duplicate") { model.duplicate() }
                button("pencil", "Rename") { rename(model.inUse) }
                    .disabled(model.isBuiltIn)
                button("trash", "Move to Trash") { model.delete(model.inUse) }
                    .disabled(model.isBuiltIn)
                Spacer(minLength: 0)
            }
            .buttonStyle(.borderless)
            .padding(SpotTokens.menuPadding)
        }
    }

    @ViewBuilder
    private func row(_ theme: String) -> some View {
        if model.renaming == theme {
            TextField("Name", text: $name)
                .focused($isNaming)
                .onSubmit { model.rename(theme, to: name) }
                .onExitCommand { model.renaming = nil }
        } else {
            HStack {
                Text(theme).lineLimit(1)
                Spacer(minLength: 0)
                if theme == model.inUse { Image(systemName: "checkmark") }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { if !ThemeFolder.isBuiltIn(theme) { rename(theme) } }
        }
    }

    private func button(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: { Image(systemName: symbol) }
            .help(label)
            .accessibilityLabel(label)
    }

    private func rename(_ theme: String) {
        name = theme
        model.renaming = theme
        isNaming = true
    }
}
