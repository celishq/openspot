import SwiftUI
import OpenspotCore

struct SpotsView: View {
    let model: SpotsModel
    let close: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var edges = SpotScrollEdges()
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var sheetID: String?
    @State private var sheetOpen = false

    private static let panelSpace = "panel"
    private static let blurSteps: [(inset: CGFloat, radius: CGFloat)] = [
        (SpotTokens.halo - 30, SpotTokens.backdropBlur / 4),
        (SpotTokens.halo - 20, SpotTokens.backdropBlur / 2),
        (SpotTokens.halo - 10, SpotTokens.backdropBlur)
    ]
    private static let blurEdgeSoftness: CGFloat = 11
    private static let scrollEdgeInset: CGFloat = SpotTokens.halo - 18
    private static let scrollEdgeSoftness: CGFloat = 7

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                grid
                    .padding(.horizontal, SpotTokens.halo)
                    .padding(.top, SpotTokens.halo + SpotTokens.rowHeight + SpotTokens.rowGap)
                    .padding(.bottom, SpotTokens.halo)
            }
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edges.gradient)
            .mask(softEdge(inset: Self.scrollEdgeInset, softness: Self.scrollEdgeSoftness, height: SpotTokens.panelHeight))
            if let entry = model.entries.first(where: { $0.id == sheetID }) {
                SpotSheetView(
                    entry: entry,
                    list: model.lists[entry.id] ?? ItemList(),
                    onRun: { model.runItem($0) },
                    onClose: { model.closeList() }
                )
                .modifier(SpotSheetFrame(
                    rect: sheetOpen ? SpotTokens.sheetRect : openFrame ?? SpotTokens.sheetRect,
                    radius: sheetOpen ? SpotTokens.radius : SpotTokens.corner(for: entry.size)
                ))
            }
            searchField
                .padding(.horizontal, sheetOpen ? SpotTokens.halo + SpotTokens.padding : SpotTokens.halo)
                .padding(.top, SpotTokens.halo)
                .offset(y: sheetOpen ? SpotTokens.sheetFieldDrop : 0)
        }
        .coordinateSpace(name: Self.panelSpace)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        .background(softBlur)
        .environment(\.spotIsShown, model.isShown)
        .preferredColorScheme(.dark)
        .onChange(of: model.isShown) { _, isShown in
            guard isShown else {
                searchFocused = false
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration) {
                if model.isShown { searchFocused = true }
            }
        }
        .onChange(of: model.openList) { _, list in
            if let list {
                sheetID = list
                DispatchQueue.main.async {
                    withAnimation(SpotMotion.sheet(isOpen: true)) { sheetOpen = true }
                }
            } else {
                withAnimation(SpotMotion.sheet(isOpen: false), completionCriteria: .removed) {
                    sheetOpen = false
                } completion: {
                    if model.openList == nil { sheetID = nil }
                }
            }
        }
    }

    private var softBlur: some View {
        ZStack {
            ForEach(Self.blurSteps, id: \.inset) { step in
                SpotBlur(radius: model.isShown ? step.radius : 0)
                    .mask(softEdge(inset: step.inset, softness: Self.blurEdgeSoftness, height: backdropHeight))
            }
            Color.black.opacity(SpotTokens.backdropShade)
                .mask(softEdge(inset: Self.blurSteps[1].inset, softness: Self.blurEdgeSoftness, height: backdropHeight))
        }
        .animation(SpotMotion.backdrop, value: contentHeight)
        .opacity(model.isShown ? 1 : 0)
        .scaleEffect(model.isShown ? 1 : SpotMotion.backdropHiddenScale)
        .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
    }

    private func softEdge(inset: CGFloat, softness: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: SpotTokens.radius + SpotTokens.halo - inset, style: .continuous)
            .fill(Color.black)
            .padding(inset)
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .top)
            .blur(radius: softness)
    }

    private var contentHeight: CGFloat {
        SpotTokens.backdropHeight(rows: model.placements.map { $0.row + $0.size.rows }.max() ?? 0)
    }

    private var backdropHeight: CGFloat {
        sheetOpen ? SpotTokens.panelHeight : contentHeight
    }

    private var openFrame: CGRect? {
        sheetID.flatMap { cardFrames[$0] }
    }

    private func push(of placement: SpotPlacement) -> CGSize {
        guard sheetOpen, let from = openFrame,
              let open = model.placements.first(where: { model.visible[$0.index].id == sheetID })
        else { return .zero }
        let away = placement.direction(awayFrom: open)
        let sheet = SpotTokens.sheetRect
        return CGSize(
            width: away.columns < 0 ? sheet.minX - from.minX : away.columns > 0 ? sheet.maxX - from.maxX : 0,
            height: away.rows < 0 ? sheet.minY - from.minY : away.rows > 0 ? sheet.maxY - from.maxY : 0
        )
    }

    private var grid: some View {
        let placements = model.placements
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        return ZStack(alignment: .topLeading) {
            ForEach(placements.map { (id: model.visible[$0.index].id, placement: $0) }, id: \.id) { spot in
                let placement = spot.placement
                let entry = model.visible[placement.index]
                let pushed = push(of: placement)
                SpotCardView(
                    entry: entry,
                    size: placement.size,
                    isSelected: placement.index == model.selected,
                    onTap: { model.tap(entry.id) },
                    onLevel: { model.setLevel(entry.id, to: $0) }
                )
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(Self.panelSpace)) }, action: { frame in
                    if entry.kind == .list { cardFrames[entry.id] = frame }
                })
                .offset(
                    x: CGFloat(placement.column) * (SpotTokens.cell + SpotTokens.columnGap) + pushed.width,
                    y: CGFloat(placement.row) * (SpotTokens.rowHeight + SpotTokens.rowGap) + pushed.height
                )
                .opacity(entry.id == sheetID || sheetOpen ? 0 : 1)
            }
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows), alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
                .frame(width: SpotTokens.glyphSize)
            TextField(searchPrompt, text: Binding(get: { model.searchText }, set: { model.searchText = $0 }), prompt: Text(searchPrompt).foregroundStyle(.white.opacity(SpotTokens.secondaryLight)))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { model.runSelected() }
                .onKeyPress(.downArrow) {
                    if model.openList != nil {
                        model.moveItem(by: 1)
                    } else {
                        model.moveSelection(dx: 0, dy: 1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if model.openList != nil {
                        model.moveItem(by: -1)
                    } else {
                        model.moveSelection(dx: 0, dy: -1)
                    }
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    if model.openList != nil {
                        return .ignored
                    }
                    if model.selectedIsSlider {
                        model.adjustSelected(by: -5)
                    } else {
                        model.moveSelection(dx: -1, dy: 0)
                    }
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if model.openList != nil {
                        return .ignored
                    }
                    if model.selectedIsSlider {
                        model.adjustSelected(by: 5)
                    } else {
                        model.moveSelection(dx: 1, dy: 0)
                    }
                    return .handled
                }
                .onKeyPress(.escape) {
                    if !model.stepBack() { close() }
                    return .handled
                }
                .onKeyPress(keys: [.return]) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.openBigView()
                    return .handled
                }
        }
        .font(SpotType.input)
        .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: sheetOpen ? SpotTokens.listRowHeight : SpotTokens.rowHeight)
        .background(Color.white.opacity(sheetOpen ? 0.12 : 0), in: RoundedRectangle(cornerRadius: fieldRadius, style: .continuous))
        .modifier(SpotGlass(radius: fieldRadius, isBare: sheetOpen))
    }

    private var fieldRadius: CGFloat {
        sheetOpen ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

    private var searchPrompt: String {
        model.openEntry.map { "Search \($0.state.title)" } ?? "Search spots"
    }
}
