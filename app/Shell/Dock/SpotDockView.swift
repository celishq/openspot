import OpenspotCore
import SwiftUI

/// The dock of Edit Spots, on the glass of the panel's surfaces: its title with the number of spots that are off, its
/// search, and those spots as their cards in rows that scroll down. The scroll reaches the dock's edges, and its margin lies
/// inside it.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool

    var body: some View {
        let dock = model.dock
        let columns = SpotTokens.dockColumns(width: size.width)
        let rects = dock.rects(columns: columns)
        VStack(alignment: .leading, spacing: 0) {
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
            .frame(height: SpotTokens.menuRowHeight)
            .padding([.horizontal, .top], SpotTokens.padding)
            .padding(.bottom, SpotTokens.rowGap)
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zip(dock.shown, rects)), id: \.0.id) { item, rect in
                        SpotDockTile(item: item, model: model)
                            .offset(x: rect.minX, y: rect.minY)
                    }
                }
                .frame(width: size.width - 2 * SpotTokens.padding, height: dock.height(columns: columns), alignment: .topLeading)
                .padding(.horizontal, SpotTokens.padding)
                .padding(.bottom, SpotTokens.padding)
            }
            .overlay(alignment: .topLeading) {
                if dock.shown.isEmpty {
                    Text(dock.query.isEmpty ? "Each spot is on." : "No spot has these words.")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                        .padding(.horizontal, SpotTokens.padding)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background { DropMark(model: model) }
        .modifier(SpotGlass(rimSize: size))
        .onChange(of: isSearching) { _, isOn in model.searchesDock(isOn) }
        .onChange(of: model.isSearchingDock) { _, isOn in if !isOn { isSearching = false } }
    }
}

/// The fill of the dock while a card that a release there turns off lies over it.
private struct DropMark: View {
    let model: SpotsModel

    var body: some View {
        let isOn = model.carry.map { $0.turnsOff && $0.isOverDock } ?? false
        RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous)
            .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            .opacity(isOn ? 1 : 0)
            .animation(SpotMotion.liftFade, value: isOn)
    }
}
