import OpenspotCore
import SwiftUI

/// The dock of Edit Spots, on the glass of the panel's surfaces: its title with the number of spots that are off, its
/// search, and those spots as their cards in one row that scrolls to the side.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool

    var body: some View {
        let dock = model.dock
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            HStack(spacing: SpotTokens.padding) {
                HStack(spacing: 6) {
                    Text("Off")
                        .font(SpotType.title)
                        .foregroundStyle(SpotTheme.ink)
                    Text("\(dock.shown.count)")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                }
                Spacer(minLength: 0)
                SpotSearchField(prompt: "Search spots", text: dock.query, onSearch: { model.searchDock($0) }, isFocused: $isSearching)
                    .frame(width: SpotTokens.gridWidth)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: SpotTokens.columnGap) {
                    ForEach(dock.shown) { item in
                        SpotDockTile(item: item, model: model)
                    }
                }
            }
            .overlay(alignment: .leading) {
                if dock.shown.isEmpty {
                    Text(dock.query.isEmpty ? "Each spot is on." : "No spot has these words.")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                }
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass(rimSize: size))
        .onChange(of: isSearching) { _, isOn in model.searchesDock(isOn) }
        .onChange(of: model.isSearchingDock) { _, isOn in if !isOn { isSearching = false } }
    }
}
