import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @FocusState private var searchFocused: Bool
    @State private var edges = SpotScrollEdges()
    @State private var scroll = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var sheetID: String?
    @State private var sheetOpen = false
    @State private var gridHint = ""
    @State private var sheetHint = ""
    @State private var dropTarget: String?

    private static let panelSpace = "panel"
    private static let wordRoll: CGFloat = 20
    private static let fieldGap: CGFloat = 8
    private static let blurSteps: [(inset: CGFloat, radius: CGFloat)] = [
        (SpotTokens.halo - 30, SpotTokens.backdropBlur / 4),
        (SpotTokens.halo - 20, SpotTokens.backdropBlur / 2),
        (SpotTokens.halo - 10, SpotTokens.backdropBlur)
    ]
    private static let blurEdgeSoftness: CGFloat = 11
    private static let scrollEdgeInset: CGFloat = SpotTokens.halo - 18
    private static let scrollEdgeSoftness: CGFloat = 7
    private static let gridTop: CGFloat = SpotTokens.halo + SpotTokens.rowHeight + SpotTokens.rowGap
    private static let gridBottom: CGFloat = SpotTokens.halo + SpotTokens.hintBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                grid
                    .padding(.horizontal, SpotTokens.halo)
                    .padding(.top, Self.gridTop)
                    .padding(.bottom, Self.gridBottom)
            }
            .scrollPosition($scroll)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
                scrollOffset = offset
            })
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edges.gradient)
            .mask(softEdge(inset: Self.scrollEdgeInset, softness: Self.scrollEdgeSoftness, height: backdropHeight - SpotTokens.hintBlock))
            hintLine
                .offset(x: SpotTokens.halo, y: contentHeight - SpotTokens.halo - SpotTokens.hintHeight)
                .opacity(model.isShown ? 1 : 0)
                .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            if let entry = model.entries.first(where: { $0.id == sheetID }) {
                SpotSheetView(
                    entry: entry,
                    isOpen: sheetOpen,
                    list: model.sheets[entry.id]?.list ?? ItemList(),
                    rect: sheetRect,
                    form: model.form?.entry.id == entry.id ? model.form?.draft : nil,
                    panel: model.sheets[entry.id]?.panel,
                    work: { model.work(of: $0) },
                    onSet: { model.setPart($0, to: $1) },
                    onPress: { model.pressPart($0) },
                    recordingPart: model.recordingPart,
                    onRecord: { model.toggleRecording($0) },
                    createTitle: model.createAction.map { "\($0.title): \(model.searchText)" },
                    onCreate: { model.createFromSearch() },
                    onFormValue: { model.setFormValue($0, for: $1) },
                    onRun: { model.runItem($0) },
                    onClose: {
                        model.allowSheetMotion()
                        model.closeList()
                    }
                )
                .background(Color.white.opacity(entry.state.on == true && !sheetOpen ? 1 : 0))
                .modifier(SpotSheetFrame(
                    rect: sheetOpen ? sheetRect : openFrame ?? sheetRect,
                    radius: sheetOpen ? SpotTokens.radius : SpotTokens.corner(for: entry.size),
                    ringOpacity: !sheetOpen && cardIsSelected(entry) ? 1 : 0
                ))
            }
            searchField
                .padding(.horizontal, sheetOpen ? SpotTokens.halo + SpotTokens.padding : SpotTokens.halo)
                .padding(.top, SpotTokens.halo)
                .offset(y: sheetOpen ? SpotTokens.sheetFieldDrop : 0)
                .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: !sheetOpen)) { $0.opacity(showsSearchField ? 1 : 0) }
                .allowsHitTesting(showsSearchField)
            promptLayer
            if let menu = model.menu {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeMenu() }
                SpotActionMenuView(menu: menu, work: { model.work(of: $0) }, onPress: { model.pressMenu(row: $0) })
                    .offset(x: SpotTokens.halo, y: menuTop(menu))
            }
        }
        .coordinateSpace(name: Self.panelSpace)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        .overlay {
            SpotWholeRedraw(isActive: model.isShown, radius: SpotTokens.radius + SpotTokens.halo - Self.blurSteps[0].inset)
                .padding(Self.blurSteps[0].inset)
                .allowsHitTesting(false)
        }
        .background(softBlur)
        .environment(\.spotIsShown, model.isShown)
        .preferredColorScheme(.dark)
        .onChange(of: model.isShown) { _, isShown in
            guard isShown else {
                searchFocused = false
                dropTarget = nil
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + SpotMotion.fadeInDuration) {
                if model.isShown, model.showsSearch, !model.isOpenForDrag { searchFocused = true }
            }
        }
        .onChange(of: model.selected) {
            showSelected()
        }
        .onChange(of: model.showsSearch) { _, shows in
            searchFocused = shows
        }
        .onChange(of: model.hint, initial: true) { _, hint in
            if model.openList == nil { gridHint = hint } else { sheetHint = hint }
        }
        .onChange(of: model.openList) { _, list in
            if list != nil { sheetHint = model.hint }
            guard model.sheetMoves else {
                sheetID = list
                sheetOpen = list != nil
                model.allowSheetMotion()
                return
            }
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

    /// Scrolls the grid until the selected spot lies clear of the fades at its two ends.
    private func showSelected() {
        let placements = model.placements
        guard model.openList == nil, let spot = placements.first(where: { $0.index == model.selected }) else { return }
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        let top = Self.gridTop + CGFloat(spot.row) * (SpotTokens.rowHeight + SpotTokens.rowGap)
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.panelHeight - Self.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: Self.gridTop + SpotTokens.height(rows: rows) + Self.gridBottom
        )
        let offset = window.offset(showing: top...(top + SpotTokens.height(rows: spot.size.rows)), from: scrollOffset)
        guard offset != scrollOffset else { return }
        withAnimation(SpotMotion.follow) { scroll.scrollTo(y: offset) }
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

    private var sheetRect: CGRect {
        if let form = model.form { return SpotTokens.formRect(form.draft.form) }
        if let panel = model.sheets[sheetID ?? ""]?.panel { return SpotTokens.panelRect(panel) }
        return SpotTokens.sheetRect(rows: model.sheets[sheetID ?? ""]?.list.shown.count ?? 0)
    }

    private var contentHeight: CGFloat {
        guard !sheetOpen else { return sheetRect.height + 2 * SpotTokens.halo + SpotTokens.hintBlock }
        return SpotTokens.backdropHeight(rows: model.placements.map { $0.row + $0.size.rows }.max() ?? 0)
    }

    private var backdropHeight: CGFloat {
        let menu = model.menu.map { SpotTokens.menuHeight(rows: $0.rows.count) + 2 * SpotTokens.halo } ?? 0
        return max(contentHeight, menu)
    }

    /// Where the menu starts: its bottom meets the bottom of the content.
    private func menuTop(_ menu: ActionMenu) -> CGFloat {
        max(SpotTokens.halo, contentHeight - SpotTokens.halo - SpotTokens.hintBlock - SpotTokens.menuHeight(rows: menu.rows.count))
    }

    private func cardIsSelected(_ entry: SpotsModel.Entry) -> Bool {
        model.placements.first { model.visible[$0.index].id == entry.id }?.index == model.selected
    }

    /// The one hint under the content. Its words roll out of the line as the sheet's or the grid's roll in.
    private var hintLine: some View {
        ZStack {
            SpotHint(text: gridHint)
                .opacity(sheetOpen ? 0 : 1)
                .offset(y: sheetOpen ? -Self.wordRoll : 0)
            SpotHint(text: sheetWords)
                .opacity(sheetOpen ? 1 : 0)
                .offset(y: sheetOpen ? 0 : Self.wordRoll)
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.hintHeight)
        .clipped()
    }

    /// What the hint says while a sheet shows: a form has its own keys.
    private var sheetWords: String {
        if model.form != nil { return "⌘⏎ Save   Esc Cancel" }
        return sheetHint
    }

    /// Whether the search field is drawn. A form and a sheet of parts replace it.
    private var showsSearchField: Bool {
        guard model.form == nil else { return false }
        return !(sheetOpen && model.sheets[sheetID ?? ""]?.panel != nil)
    }

    private var openFrame: CGRect? {
        sheetID.flatMap { cardFrames[$0] }
    }

    private func push(of placement: SpotPlacement) -> CGSize {
        guard sheetOpen, let from = openFrame,
              let open = model.placements.first(where: { model.visible[$0.index].id == sheetID })
        else { return .zero }
        let away = placement.direction(awayFrom: open)
        let sheet = sheetRect
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
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    readings: entry.kind == .widget ? model.readings : [:],
                    chainLetter: model.chainLetter(of: entry),
                    onTap: { model.tap(entry.id) },
                    onLevel: { model.setLevel(entry.id, to: $0) }
                )
                .onDrop(of: [.fileURL], delegate: SpotCardDrop(id: entry.id, model: model, target: $dropTarget))
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(Self.panelSpace)) }, action: { frame in
                    if entry.kind.opensSheet { cardFrames[entry.id] = frame }
                })
                .scaleEffect(sheetOpen && entry.id != sheetID ? SpotMotion.pushedScale : 1)
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
        HStack(spacing: Self.fieldGap) {
            Image(systemName: "magnifyingglass")
                .modifier(SpotSecondaryText())
                .frame(width: sheetOpen ? SpotTokens.listIconSize : SpotTokens.glyphSize)
            TextField("\(SearchPrompt.verb) \(sheetOpen ? sheetWord : SearchPrompt.grid)", text: Binding(get: { model.searchText }, set: { model.searchText = $0 }), prompt: Text(""))
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
        .background(Color.white.opacity(sheetOpen ? SpotTokens.fill : 0), in: RoundedRectangle(cornerRadius: fieldRadius, style: .continuous))
        .modifier(SpotGlass(radius: fieldRadius, isBare: sheetOpen))
    }

    /// The empty field's words, as a layer of their own that moves with the field by offsets alone, which stay smooth where
    /// layout rounds to whole pixels.
    private var promptLayer: some View {
        let top = SpotTokens.halo + (sheetOpen ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let left = sheetOpen
            ? SpotTokens.halo + 2 * SpotTokens.padding + SpotTokens.listIconSize + Self.fieldGap
            : SpotTokens.halo + SpotTokens.padding + SpotTokens.glyphSize + Self.fieldGap
        return promptWords
            .frame(height: SpotTokens.rowHeight)
            .offset(x: left, y: top)
            .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
            .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: !sheetOpen)) { $0.opacity(showsSearchField ? 1 : 0) }
            .opacity(model.isShown ? 1 : 0)
            .scaleEffect(model.isShown ? 1 : SpotMotion.hiddenScale, anchor: UnitPoint(x: 0.5, y: (SpotTokens.halo + SpotTokens.rowHeight / 2) / SpotTokens.panelHeight))
            .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            .allowsHitTesting(false)
    }

    /// One line on one path: the first word stays, and the last fades into the other in its place.
    private var promptWords: some View {
        HStack(spacing: 0) {
            Text("\(SearchPrompt.verb) ")
            ZStack(alignment: .leading) {
                Text(SearchPrompt.grid)
                    .opacity(sheetOpen ? 0 : 1)
                Text(sheetWord)
                    .opacity(sheetOpen ? 1 : 0)
            }
        }
        .font(SpotType.input)
        .foregroundStyle(.white.opacity(SpotTokens.secondaryLight))
        .lineLimit(1)
        .opacity(model.searchText.isEmpty ? 1 : 0)
    }

    private var fieldRadius: CGFloat {
        sheetOpen ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

    private var sheetWord: String {
        SearchPrompt.word(for: model.entries.first { $0.id == sheetID }?.state.title ?? "")
    }
}
