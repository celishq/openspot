import OpenspotCore
import SwiftUI

/// The store of Edit Spots, on the glass of the panel's surfaces: a sidebar as wide as the panel's grid with the search and
/// the sections, and right of it, on a darker tint past a line, the rows of the shown spots, two to a line under the titles
/// of their states, with a line between groups. The rows scroll and fade at each end they pass. A row dragged out of the
/// store leaves its place empty until it lands.
struct SpotDockView: View {
    let model: SpotsModel
    let size: CGSize
    @FocusState private var isSearching: Bool
    @State private var edges = SpotScrollEdges()
    @State private var scroll = ScrollPosition()

    var body: some View {
        let dock = model.dock
        let rects = dock.rects
        let origin = SpotDock.rowsOrigin
        ZStack(alignment: .topLeading) {
            rowsTint
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(dock.groups.dropFirst(), id: \.title) { group in
                        Rectangle()
                            .fill(SpotTheme.ink.opacity(SpotTheme.track))
                            .frame(width: SpotTokens.width(columns: 8), height: 1)
                            .offset(y: group.top - SpotTokens.groupGap / 2)
                    }
                    ForEach(dock.groups, id: \.title) { group in
                        HStack(spacing: SpotTokens.padding) {
                            SpotGroupTitle(name: group.title, count: group.count)
                            if group.title == "Not Added", dock.query.isEmpty { TextButton(title: "Add All") { model.turnOnAll() } }
                        }
                        .offset(y: group.top)
                    }
                    ForEach(Array(zip(dock.shown, rects)), id: \.0.id) { item, rect in
                        SpotStoreRow(item: item)
                            .equatable()
                            .simultaneousGesture(carry(item), isEnabled: item.state != .onGrid)
                            .animation(nil) { $0.opacity(model.carry?.entry.id == item.id ? 0.001 : 1) }
                            .offset(x: rect.minX, y: rect.minY)
                    }
                    if let sheet = dock.sheetRect, let index = dock.shown.firstIndex(where: { $0.id == dock.opened }), let listing = model.dockListing {
                        let row = rects[index]
                        SpotListingSheet(item: dock.shown[index], listing: listing, model: model)
                            .frame(width: sheet.width, height: sheet.height)
                            .modifier(SheetGrowth(rect: dock.isSheetOut ? CGRect(origin: .zero, size: sheet.size) : CGRect(x: row.minX, y: 0, width: row.width, height: 0)))
                            .offset(x: sheet.minX, y: sheet.minY)
                            .id(dock.opened)
                    }
                }
                .frame(width: SpotTokens.width(columns: 8), height: dock.height, alignment: .topLeading)
                .contentShape(Rectangle())
                .simultaneousGesture(SpatialTapGesture().onEnded { press(at: $0.location) })
                .padding(.leading, SpotTokens.columnGap)
                .padding(.trailing, SpotTokens.padding)
                .padding(.vertical, origin.y)
            }
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in model.dockScrolled(to: offset) })
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edgeFade)
            .frame(width: size.width - origin.x + SpotTokens.columnGap)
            .offset(x: origin.x - SpotTokens.columnGap)
            if dock.shown.isEmpty {
                Text(dock.query.isEmpty ? "No spot is here." : "No spot has these words.")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                    .offset(x: origin.x, y: origin.y)
            }
            sidebar(dock)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass(rimSize: size))
        .onChange(of: dock.isSheetOut) { _, isOut in if isOut { reveal(dock.opened) } }
        .onChange(of: isSearching) { _, isOn in model.searchesDock(isOn) }
        .onChange(of: model.isSearchingDock) { _, isOn in if !isOn { isSearching = false } }
    }

    /// The search, and under it a row for each section with its picture and the number of its spots. The selected section
    /// shows on the fill of a selected row, while no search hides it.
    private func sidebar(_ dock: SpotDock) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.menuRowGap) {
            SpotSearchField(prompt: "Search spots", text: dock.query, onSearch: { model.searchDock($0) }, isFocused: $isSearching)
                .padding(.bottom, SpotTokens.placeGap)
            ForEach(SpotDock.Section.allCases, id: \.self) { section in
                SectionRow(section: section, count: dock.count(of: section), isSelected: dock.query.isEmpty && dock.section == section) {
                    model.searchDock("")
                    model.showStoreSection(section)
                }
            }
        }
        .frame(width: SpotTokens.gridWidth)
        .padding([.leading, .top], SpotTokens.padding)
    }

    /// The tint of the rows' side of the store, from the middle of the gap after the sidebar to the store's trailing edge,
    /// with a line at its leading edge.
    private var rowsTint: some View {
        let radius = SpotTokens.radius
        return UnevenRoundedRectangle(bottomTrailingRadius: radius, topTrailingRadius: radius, style: .continuous)
            .fill(SpotTheme.well)
            .overlay(alignment: .leading) { Rectangle().fill(SpotTheme.ink.opacity(SpotTheme.track)).frame(width: 1) }
            .frame(width: size.width - Self.tintEdge, height: size.height)
            .offset(x: Self.tintEdge)
    }

    private static let tintEdge = (SpotDock.rowsOrigin.x - SpotTokens.columnGap / 2).rounded()

    /// The fade of the rows at each end, as strong as the rows have scrolled past that end, as on the panel's grid.
    private var edgeFade: some View {
        VStack(spacing: 0) {
            SpotScrollEdges.end(fading: edges.top, from: .top)
                .frame(height: SpotScrollEdges.fadeLength)
            Color.black
            SpotScrollEdges.end(fading: edges.bottom, from: .bottom)
                .frame(height: SpotScrollEdges.fadeLength)
        }
    }

    /// Scrolls the rows, on the sheet's motion, as little as shows the whole sheet of the opened spot, and never past the top
    /// of its row.
    private func reveal(_ id: String?) {
        let dock = model.dock
        guard let id, let index = dock.shown.firstIndex(where: { $0.id == id }), let sheet = dock.sheetRect else { return }
        let bottom = sheet.maxY + 2 * SpotDock.rowsOrigin.y - size.height
        guard bottom > model.dockScroll else { return }
        withAnimation(SpotMotion.edit) { scroll.scrollTo(y: min(dock.rects[index].minY, bottom)) }
    }

    /// Acts on a click in the rows: the button does the next step, its arrow opens the menu, and the rest of a row opens its
    /// listing.
    private func press(at point: CGPoint) {
        guard model.carry == nil, let (id, part) = model.dock.part(at: point), let item = model.dock.items.first(where: { $0.id == id }) else { return }
        switch part {
        case .step: model.takeStep(of: id)
        case .menu: SpotStoreMenu.show(SpotDock.menu(for: item)) { model.choose($0, for: id) }
        case .row: model.openListing(id)
        }
    }

    /// Carries a spot out of the store: its card follows the pointer, and a release on the grid turns it on there. Its moves
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

/// A section of the store in the sidebar: its picture in a fixed column, its title and the number of its spots, as a row of
/// the actions menu draws them.
private struct SectionRow: View {
    let section: SpotDock.Section
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
        Button(action: action) {
            HStack(spacing: SpotTokens.placeGap) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                    .frame(width: SpotTokens.listIconSize)
                Text(section.title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText())
            }
            .padding(.leading, SpotTokens.padding - SpotTokens.menuPadding)
            .padding(.trailing, SpotTokens.padding - SpotTokens.menuPadding + 4)
            .frame(height: SpotTokens.menuRowHeight)
            .background(isSelected ? SpotTheme.ink.opacity(SpotTheme.selectedFill) : .clear, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch section {
        case .added: "square.grid.2x2"
        case .store: "bag"
        case .mine: "person.crop.circle"
        }
    }
}

/// The clip of a listing sheet: a sliver under its row while it is in, and its whole size while it is out. Its rect is
/// animatable, so that it grows and shrinks on the store's motion.
private struct SheetGrowth: ViewModifier, @preconcurrency Animatable {
    var rect: CGRect

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(rect.width, rect.height)) }
        set { rect = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func body(content: Content) -> some View {
        content.clipShape(SpotSheetClip(rect: rect))
    }
}

/// A button that is its words alone, such as Add All beside the title of the spots that are not added.
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
