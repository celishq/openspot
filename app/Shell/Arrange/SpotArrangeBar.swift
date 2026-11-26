import OpenspotCore
import SwiftUI

struct SpotArrangeBar: View {
    let model: SpotsModel
    @FocusState private var isFocused: Bool

    var body: some View {
        field
            .onAppear { isFocused = true }
    }

    private var field: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search your spots", text: Binding(get: { model.shelfQuery }, set: { model.searchShelf($0) }))
                .textFieldStyle(.plain)
                .focused($isFocused)
            SpotShelfCount(model: model)
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.glassInk)
        .padding(.horizontal, SpotTokens.padding)
        .frame(maxWidth: .infinity, minHeight: SpotTokens.cell, maxHeight: SpotTokens.cell)
        .spotGlass(in: Capsule())
    }
}

private struct SpotShelfCount: View {
    let model: SpotsModel

    var body: some View {
        if !model.shelfQuery.isEmpty {
            Text("\(model.shelf.count) of \(model.offGrid.count)")
                .font(SpotType.detail)
                .foregroundStyle(.secondary)
        }
    }
}
