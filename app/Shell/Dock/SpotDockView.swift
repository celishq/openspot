import OpenspotCore
import SwiftUI

/// The store of Edit Spots, on the glass of the panel's surfaces: its filters with the number of spots that the chosen one
/// keeps, its search, and those spots as their cards in rows that scroll under the filters and fade at each end they pass.
/// The scroll reaches the store's edges, and its margins lie inside it. A card dragged out of the store leaves its place
/// empty until it lands.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool
    @State private var edges = SpotScrollEdges()

    var body: some View {
        let dock = model.dock
        let columns = SpotTokens.dockColumns(width: size.width)
        let rects = dock.rects(columns: columns)
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zip(dock.shown, rects)), id: \.0.id) { item, rect in
                        SpotDockTile(item: item, model: model)
                            .simultaneousGesture(carry(item))
                            .animation(nil) { $0.opacity(model.carry?.entry.id == item.id ? 0.001 : 1) }
                            .offset(x: rect.minX, y: rect.minY)
                    }
                    if let sheet = dock.sheetRect(columns: columns), let index = dock.shown.firstIndex(where: { $0.id == dock.opened }),
                       let listing = model.dockListing {
                        let card = dock.rects(columns: columns)[index]
                        SpotListingSheet(item: dock.shown[index], listing: listing, model: model)
                            .frame(width: sheet.width, height: sheet.height)
                            .transition(.modifier(
                                active: SheetGrowth(rect: CGRect(x: card.minX, y: 0, width: card.width, height: 0)),
                                identity: SheetGrowth(rect: CGRect(origin: .zero, size: sheet.size))
                            ))
                            .offset(x: sheet.minX, y: sheet.minY)
                            .id(dock.opened)
                    }
                }
                .frame(width: size.width - 2 * SpotTokens.padding, height: dock.height(columns: columns), alignment: .topLeading)
                .padding(.horizontal, SpotTokens.padding)
                .padding(.top, SpotTokens.dockRowsTop)
                .padding(.bottom, SpotTokens.padding)
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in model.dockScrolled(to: offset) })
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edgeFade)
            if dock.shown.isEmpty {
                Text(dock.query.isEmpty ? "No spot is here." : "No spot has these words.")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                    .padding(.horizontal, SpotTokens.padding)
                    .offset(y: SpotTokens.dockRowsTop)
            }
            HStack(spacing: SpotTokens.padding) {
                HStack(spacing: SpotTokens.padding) {
                    ForEach(SpotDock.Filter.allCases, id: \.self) { filter in
                        FilterButton(filter: filter, count: filter == dock.filter ? dock.shown.count : nil) { model.filterDock(filter) }
                    }
                }
                Spacer(minLength: 0)
                if dock.filter == .off, !dock.shown.isEmpty {
                    Button("Turn On All") { model.turnOnAll() }
                        .buttonStyle(.plain)
                        .font(SpotType.body)
                        .foregroundStyle(SpotTheme.ink)
                }
                SpotSearchField(prompt: "Search spots", text: dock.query, onSearch: { model.searchDock($0) }, isFocused: $isSearching)
                    .frame(width: SpotTokens.gridWidth)
            }
            .frame(height: SpotTokens.menuRowHeight)
            .padding([.horizontal, .top], SpotTokens.padding)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass(rimSize: size))
        .onChange(of: isSearching) { _, isOn in model.searchesDock(isOn) }
        .onChange(of: model.isSearchingDock) { _, isOn in if !isOn { isSearching = false } }
    }

    /// The fade of the dock's rows under its title and at its bottom edge, as strong as the rows have scrolled past that end,
    /// as on the panel's grid. At rest a card's controls show over the gap under the title.
    private var edgeFade: some View {
        VStack(spacing: 0) {
            Color.black.opacity(1 - edges.top)
                .frame(height: SpotTokens.padding + SpotTokens.menuRowHeight)
            SpotScrollEdges.end(fading: edges.top, from: .top)
                .frame(height: SpotScrollEdges.fadeLength)
            Color.black
            SpotScrollEdges.end(fading: edges.bottom, from: .bottom)
                .frame(height: SpotScrollEdges.fadeLength)
        }
    }

    /// Carries a spot out of the dock: its card follows the pointer, and a release on the grid turns it on there. Its moves
    /// carry no speed, so a release lands the card from rest.
    private func carry(_ item: SpotDock.Item) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                var still = Transaction()
                still.tracksVelocity = false
                withTransaction(still) { model.dragDockSpot(item.id, by: value.translation) }
            }
            .onEnded { model.dropDockSpot(by: $0.translation) }
    }
}

/// The clip of a listing sheet, from a sliver under its card to its whole size.
private struct SheetGrowth: ViewModifier {
    let rect: CGRect

    func body(content: Content) -> some View {
        content.clipShape(SpotSheetClip(rect: rect))
    }
}

/// A filter of the store: its title, strong while it is chosen, with the number of spots that it keeps.
private struct FilterButton: View {
    let filter: SpotDock.Filter
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if count != nil {
                    Text(filter.title)
                        .font(SpotType.title)
                        .foregroundStyle(SpotTheme.ink)
                } else {
                    Text(filter.title)
                        .font(SpotType.title)
                        .modifier(SpotSecondaryText())
                }
                if let count {
                    Text("\(count)")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(count != nil ? .isSelected : [])
    }
}
