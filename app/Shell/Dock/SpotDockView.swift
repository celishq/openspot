import OpenspotCore
import SwiftUI

/// The store of Edit Spots, on the glass of the panel's surfaces: its filter by origin, its search, and the spots in groups
/// by state under their titles, in rows that scroll under the filter and fade at each end they pass. The scroll reaches the
/// store's edges, and its margins lie inside it. A card dragged out of the store leaves its place empty until it lands.
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
                    ForEach(dock.groups(columns: columns), id: \.state) { group in
                        HStack(spacing: SpotTokens.padding) {
                            SpotGroupTitle(name: Self.title(of: group.state), count: group.count)
                            if group.state == .off { TextButton(title: "Turn On All") { model.turnOnAll() } }
                        }
                        .offset(y: group.top)
                    }
                    ForEach(Array(zip(dock.shown, rects)), id: \.0.id) { item, rect in
                        SpotDockTile(item: item)
                            .simultaneousGesture(carry(item), isEnabled: item.state != .onGrid)
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
                .contentShape(Rectangle())
                .onContinuousHover { phase in hover(phase, columns: columns) }
                .simultaneousGesture(SpatialTapGesture().onEnded { press(at: $0.location, columns: columns) })
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
                Picker("Spots", selection: Binding(get: { dock.filter }, set: { model.filterDock($0) })) {
                    ForEach(SpotDock.Filter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer(minLength: 0)
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

    /// The title of the group of the spots in a state.
    static func title(of state: SpotDock.State) -> String {
        switch state {
        case .onGrid: "On grid"
        case .searchOnly: "Search only"
        case .off: "Off"
        }
    }

    /// Shows the tip of the part of a card that the pointer lies over: what its Add or its cross does, or its description,
    /// with its name on a 1x1 card.
    private func hover(_ phase: HoverPhase, columns: Int) {
        guard case .active(let point) = phase, let (id, part) = model.dock.part(at: point, columns: columns),
              let item = model.dock.shown.first(where: { $0.id == id }) else {
            if model.tip?.anchor == .dockCard || model.tip?.anchor == .dockCorner { model.tip = nil }
            return
        }
        let changed = item.publication == .changed ? "Changes not published" : nil
        let words = (item.size == .small ? [item.spot.name, item.spot.subtitle] : [item.spot.subtitle]).compactMap { $0 } + [changed].compactMap { $0 }
        let tip: SpotTip? = switch part {
        case .add: SpotTip(id: id, anchor: .dockCard, text: item.state == .off ? "Turn on" : "Put on the grid")
        case .delete: SpotTip(id: id, anchor: .dockCard, text: "Delete")
        case .card: words.isEmpty ? nil : SpotTip(id: id, anchor: .dockCard, text: words.joined(separator: " · "))
        }
        if model.tip != tip { model.tip = tip }
    }

    /// Acts on a click in the rows: Add puts a spot on the grid, the cross deletes, and the rest of a card opens its listing.
    private func press(at point: CGPoint, columns: Int) {
        guard model.carry == nil, let (id, part) = model.dock.part(at: point, columns: columns),
              let item = model.dock.shown.first(where: { $0.id == id }) else { return }
        switch part {
        case .add: model.setState(.onGrid, of: id)
        case .delete: model.delete(id)
        case .card: model.openListing(id)
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

/// A button that is its words alone, such as Turn On All beside the title of the spots that are off.
private struct TextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SpotType.detail)
                .modifier(SpotSecondaryText())
        }
        .buttonStyle(.plain)
    }
}
