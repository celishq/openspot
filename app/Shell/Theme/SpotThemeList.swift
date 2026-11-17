import OpenspotCore
import SwiftUI

struct SpotThemeList: View {
    @Bindable var model: SpotThemeModel
    @State private var name = ""
    @FocusState private var isNaming: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpotTokens.menuRowGap) {
                ForEach(model.names.filter(ThemeFolder.isBuiltIn), id: \.self) { theme in
                    row(theme, symbol: "shippingbox")
                }
                SpotThemeHeader(title: "Yours")
                ForEach(model.names.filter { !ThemeFolder.isBuiltIn($0) }, id: \.self) { theme in
                    row(theme, symbol: "paintpalette")
                }
                SpotThemeLine(symbol: "plus", isDimmed: true) { Text("New Theme…") }
                    .onTapGesture { model.make() }
                    .accessibilityAddTraits(.isButton)
            }
        }
        .scrollIndicators(.never)
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand { if !model.isBuiltIn { model.delete(model.inUse) } }
    }

    @ViewBuilder
    private func row(_ theme: String, symbol: String) -> some View {
        let isChosen = theme == model.inUse
        if model.renaming == theme {
            SpotThemeLine(symbol: symbol, trailing: "In use", isChosen: isChosen) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .focused($isNaming)
                    .onSubmit { model.rename(theme, to: name) }
                    .onExitCommand { model.renaming = nil }
                    .onAppear {
                        name = theme
                        isNaming = true
                    }
            }
        } else {
            SpotThemeLine(symbol: symbol, trailing: isChosen ? "In use" : "", isChosen: isChosen) { Text(theme) }
                .onTapGesture { model.use(theme) }
                .simultaneousGesture(TapGesture(count: 2).onEnded { if !ThemeFolder.isBuiltIn(theme) { model.renaming = theme } })
                .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
        }
    }
}
