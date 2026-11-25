import OpenspotCore
import SwiftUI

struct SpotArrangeBar: View {
    let model: SpotsModel
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: SpotTokens.arrangeBarGap) {
                Text("Arranging spots")
                    .font(SpotType.input)
                    .foregroundStyle(SpotTheme.ink)
                Spacer(minLength: 0)
                Picker("Columns", selection: Binding(get: { model.grid.columns }, set: { model.set(columns: $0) })) {
                    ForEach(OpenspotCore.GridLayout.widths, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                SpotRoundButton(icon: .symbol("checkmark"), label: "Done", look: .strong) { model.endEditing() }
            }
            field
        }
        .padding(.horizontal, SpotTokens.arrangeMargin)
        .onAppear { isFocused = true }
    }

    private var field: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
            TextField("Search your spots", text: Binding(get: { model.arrangeQuery }, set: { model.searchShelf($0) }))
                .textFieldStyle(.plain)
                .focused($isFocused)
            SpotShelfCount(model: model)
        }
        .font(SpotType.body)
        .foregroundStyle(SpotTheme.ink)
        .padding(.horizontal, SpotTokens.windowRowPadding)
        .frame(width: SpotTokens.arrangeSearchWidth, height: SpotTokens.storeRowHeight)
        .background(SpotTheme.ink.opacity(SpotTheme.control), in: SpotRoundShape(radius: SpotTokens.storeRowRadius))
    }
}

private struct SpotShelfCount: View {
    let model: SpotsModel

    var body: some View {
        if !model.arrangeQuery.isEmpty {
            Text("\(model.shelf.count) of \(model.offGrid.count)")
                .font(SpotType.detail)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
        }
    }
}
