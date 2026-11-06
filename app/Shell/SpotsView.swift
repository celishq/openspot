import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @FocusState private var searchFocused: Bool
    @State private var edges = SpotScrollEdges()
    @State private var scroll = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var sheetID: String?
    @State private var sheetOpen = false
    @State private var gridHint = ""
    @State private var sheetHint = ""
    @State private var dropTarget: String?
    @State private var dragged: (id: String, offset: CGSize)?
    @State private var hintIsForEdit = false
    @State private var showsDrop = false
    @State private var lastDrop: SpotDrop?
    @State private var partsLanded = false
    @State private var installIsFromDrop = false

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
                    .scaleEffect(showsDrop ? SpotMotion.pushedScale : 1)
                    .offset(y: gridPush)
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
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: !coversGrid)) { $0.opacity(coversGrid ? 0 : 1) }
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
                    panel: shownPanel,
                    work: { model.work(of: $0) },
                    onSet: { model.setPart($0, to: $1) },
                    onPress: { model.pressPart($0) },
                    recording: model.recording,
                    onRecord: { model.toggleRecording($0) },
                    createTitle: model.createAction.map { "\($0.title): \(model.searchText)" },
                    onCreate: { model.createFromSearch() },
                    onFormValue: { model.setFormValue($0, for: $1) },
                    onRun: { model.runItem($0) },
                    closeShift: cardShows(arrowOf: entry) ? (openFrame?.width ?? sheetRect.width) - sheetRect.width : nil,
                    onClose: {
                        model.allowSheetMotion()
                        model.closeList()
                    }
                )
                .background(Color.white.opacity(entry.state.on == true && !sheetOpen ? 1 : 0))
                .modifier(SpotSheetFrame(
                    rect: sheetOpen ? sheetRect : isInstall(entry) ? (installIsFromDrop ? dropRect : fieldRect) : openFrame ?? sheetRect,
                    radius: sheetOpen || (isInstall(entry) && installIsFromDrop) ? SpotTokens.radius : isInstall(entry) ? SpotTokens.corner(for: .strip) : SpotTokens.corner(for: entry.size),
                    ringOpacity: !sheetOpen && cardIsSelected(entry) ? 1 : 0,
                    arrow: cardShows(arrowOf: entry) ? AnyView(sheetArrow(of: entry)) : nil
                ))
            }
            if let lastDrop {
                SpotDropView(drop: lastDrop)
                    .frame(width: dropRect.width, height: dropRect.height)
                    .modifier(SpotSheetFrame(
                        rect: showsDrop ? dropRect : fieldRect,
                        radius: showsDrop ? SpotTokens.radius : SpotTokens.corner(for: .strip),
                        ringOpacity: 0
                    ))
                    .allowsHitTesting(showsDrop)
            }
            searchField
                .padding(.horizontal, sheetOpen ? SpotTokens.halo + SpotTokens.padding : SpotTokens.halo)
                .padding(.top, SpotTokens.halo)
                .offset(y: sheetOpen ? SpotTokens.sheetFieldDrop : 0)
                .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: showsSearchField)) { $0.opacity(showsSearchField ? 1 : 0) }
                .opacity(model.isEditing ? 0 : 1)
                .allowsHitTesting(showsSearchField && !model.isEditing)
            promptLayer
                .opacity(model.isEditing ? 0 : 1)
            if model.isEditing {
                editHeader
                    .transition(.opacity)
            }
            if let menu = model.menu {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeMenu() }
                SpotActionMenuView(menu: menu, work: { model.work(of: $0) }, onPress: { model.pressMenu(row: $0) })
                    .offset(x: SpotTokens.halo, y: menuTop(menu))
            }
        }
        .onDrop(of: [.fileURL], delegate: SpotAddDrop(model: model))
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
        .onChange(of: model.spotDrop) { _, drop in
            if drop == nil, model.isReviewing {
                installIsFromDrop = true
                showsDrop = false
                lastDrop = nil
            } else if let drop {
                lastDrop = drop
                DispatchQueue.main.async {
                    withAnimation(SpotMotion.sheet(isOpen: true)) { showsDrop = true }
                }
            } else {
                withAnimation(SpotMotion.sheet(isOpen: false), completionCriteria: .removed) {
                    showsDrop = false
                } completion: {
                    if !showsDrop { lastDrop = nil }
                }
            }
        }
        .onChange(of: model.sheets[sheetID ?? ""]?.panel != nil) { _, hasParts in
            guard sheetOpen else {
                partsLanded = hasParts
                return
            }
            withAnimation(SpotMotion.sheet(isOpen: true)) { partsLanded = hasParts }
        }
        .onChange(of: model.selected) {
            showSelected()
        }
        .onChange(of: model.showsSearch) { _, shows in
            searchFocused = shows
        }
        .onChange(of: model.hint, initial: true) { _, hint in
            let motion = model.isEditing || hintIsForEdit ? SpotMotion.hintFade : nil
            hintIsForEdit = model.isEditing
            withAnimation(motion) {
                if model.openList == nil, model.spotDrop == nil { gridHint = hint } else { sheetHint = hint }
            }
        }
        .onChange(of: model.openList) { _, list in
            if list != nil { sheetHint = model.hint }
            guard model.sheetMoves else {
                sheetID = list
                sheetOpen = list != nil
                model.allowSheetMotion()
                if list == nil { model.endReview() }
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
                    installIsFromDrop = false
                } completion: {
                    if model.openList == nil {
                        sheetID = nil
                        model.endReview()
                    }
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
        if let shownPanel { return SpotTokens.panelRect(shownPanel) }
        return SpotTokens.sheetRect(rows: model.sheets[sheetID ?? ""]?.list.shown.count ?? 0)
    }

    /// Whether the card of this open sheet draws an arrow. A 1x1 card shows its glyph alone.
    private func cardShows(arrowOf entry: SpotsModel.Entry) -> Bool {
        entry.kind == .list && (openFrame?.width ?? 0) > SpotTokens.cell
    }

    /// The arrow of the card while its sheet moves. It stays in view until the close button takes its place at the edge.
    private func sheetArrow(of entry: SpotsModel.Entry) -> some View {
        SpotCardArrow(isOnWhite: entry.state.on == true && !sheetOpen)
            .placed(isTall: (openFrame?.height ?? 0) > SpotTokens.rowHeight)
            .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: sheetOpen)) { $0.opacity(sheetOpen ? 0 : 1) }
            .allowsHitTesting(false)
    }

    /// The parts of the open sheet, once they have landed. They arrive in one change with the sheet's new size, on its spring.
    private var shownPanel: SpotPanel? {
        partsLanded ? model.sheets[sheetID ?? ""]?.panel : nil
    }

    /// Where the search field lies at rest. A surface with no card, such as the drop state, grows out of it and collapses into it.
    private var fieldRect: CGRect {
        CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
    }

    /// How far a surface that grows out of the field pushes the grid: as far as the surface's lower edge moves.
    private var gridPush: CGFloat {
        if showsDrop { return dropRect.maxY - fieldRect.maxY }
        return sheetOpen && sheetID == ShippedSpot.installID ? sheetRect.maxY - fieldRect.maxY : 0
    }

    /// Whether a sheet or the drop state is out, which sets the time of each fade on their one motion.
    private var surfaceIsOut: Bool {
        sheetOpen || showsDrop
    }

    /// Where the drop state lies. The install screen grows out of it.
    private var dropRect: CGRect {
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        let height = SpotTokens.backdropHeight(rows: max(rows, SpotsModel.dropRows)) - 2 * SpotTokens.halo - SpotTokens.hintBlock
        return CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: height)
    }

    private func isInstall(_ entry: SpotsModel.Entry) -> Bool {
        entry.id == ShippedSpot.installID
    }

    private var contentHeight: CGFloat {
        guard !sheetOpen else { return sheetRect.height + 2 * SpotTokens.halo + SpotTokens.hintBlock }
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        return SpotTokens.backdropHeight(rows: showsDrop ? max(rows, SpotsModel.dropRows) : rows)
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
                .opacity(surfaceIsOut ? 0 : 1)
                .offset(y: surfaceIsOut ? -Self.wordRoll : 0)
            SpotHint(text: sheetWords)
                .opacity(surfaceIsOut ? 1 : 0)
                .offset(y: surfaceIsOut ? 0 : Self.wordRoll)
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.hintHeight)
        .clipped()
    }

    /// What the hint says while a sheet shows: a form has its own keys.
    private var sheetWords: String {
        if model.form != nil { return "⌘⏎ Save   Esc Cancel" }
        return sheetHint
    }

    /// Whether the drop state or the install screen takes the place of the grid and the field.
    private var coversGrid: Bool {
        showsDrop || (sheetOpen && sheetID == ShippedSpot.installID)
    }

    /// Whether the search field is drawn. A form, a sheet of parts and the drop state replace it.
    private var showsSearchField: Bool {
        guard model.form == nil, !coversGrid else { return false }
        guard sheetOpen else { return true }
        return shownPanel == nil && model.sheets[sheetID ?? ""]?.awaitsFirstAnswer != true
    }

    /// Where the card of the open sheet lies in the panel, which the grid and its scroll say.
    private var openFrame: CGRect? {
        guard let spot = model.placements.first(where: { model.visible[$0.index].id == sheetID }) else { return nil }
        return CGRect(
            x: SpotTokens.halo + CGFloat(spot.column) * (SpotTokens.cell + SpotTokens.columnGap),
            y: Self.gridTop + CGFloat(spot.row) * (SpotTokens.rowHeight + SpotTokens.rowGap) - scrollOffset,
            width: SpotTokens.width(columns: spot.size.columns),
            height: SpotTokens.height(rows: spot.size.rows)
        )
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
                    showsChain: model.showsChain,
                    onTap: { model.tap(entry.id) },
                    onLevel: { model.setLevel(entry.id, to: $0) }
                )
                .onDrop(of: [.fileURL], delegate: SpotCardDrop(id: entry.id, model: model, target: $dropTarget))
                .scaleEffect(sheetOpen && entry.id != sheetID ? SpotMotion.pushedScale : 1)
                .offset(
                    x: CGFloat(placement.column) * (SpotTokens.cell + SpotTokens.columnGap) + pushed.width + (dragged?.id == entry.id ? dragged?.offset.width ?? 0 : 0),
                    y: CGFloat(placement.row) * (SpotTokens.rowHeight + SpotTokens.rowGap) + pushed.height + (dragged?.id == entry.id ? dragged?.offset.height ?? 0 : 0)
                )
                .zIndex(dragged?.id == entry.id ? 1 : 0)
                .highPriorityGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .contextMenu { spotMenu(of: entry) }
                .opacity(entry.id == sheetID || sheetOpen ? 0 : entry.isOnGrid ? 1 : SpotTokens.offGridLight)
            }
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows), alignment: .topLeading)
        .contentShape(Rectangle())
    }

    /// What a card offers on a right click: its preferred size, its place on the grid and Edit Spots.
    @ViewBuilder
    private func spotMenu(of entry: SpotsModel.Entry) -> some View {
        let sizes = model.sizes(of: entry)
        if !sizes.isEmpty {
            Picker("Size", selection: Binding(get: { entry.size.name }, set: { name in
                if let size = SpotSize(name: name) { model.prefer(size, for: entry.id) }
            })) {
                ForEach(sizes.map(\.name), id: \.self) { Text($0.capitalized).tag($0) }
            }
        }
        if entry.item == nil {
            Button(entry.isOnGrid ? "Hide from Grid" : "Show on Grid") { model.setOnGrid(!entry.isOnGrid, for: entry.id) }
            Button("Edit Spots") { model.beginEditing() }
        }
    }

    /// Moves a card in Edit Spots: it follows the pointer, and takes the place of the card it lands on.
    private func moveGesture(of entry: SpotsModel.Entry) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.panelSpace))
            .onChanged { dragged = (entry.id, $0.translation) }
            .onEnded { drag in
                withAnimation(SpotMotion.edit) { dragged = nil }
                let point = CGPoint(
                    x: drag.location.x - SpotTokens.halo,
                    y: drag.location.y + scrollOffset - Self.gridTop
                )
                let column = Int(point.x / (SpotTokens.cell + SpotTokens.columnGap))
                let row = Int(point.y / (SpotTokens.rowHeight + SpotTokens.rowGap))
                let target = model.placements.first { place in
                    (place.column..<(place.column + place.size.columns)).contains(column) && (place.row..<(place.row + place.size.rows)).contains(row)
                }
                if let target { model.moveSpot(entry.id, to: target.index) }
            }
    }

    /// The top of the grid in Edit Spots, in the place of the search field.
    private var editHeader: some View {
        HStack {
            Text("Edit Spots")
                .font(SpotType.input)
                .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            Spacer()
            SpotRoundButton(symbol: "checkmark", label: "Done") { model.endEditing() }
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
        .offset(x: SpotTokens.halo, y: SpotTokens.halo)
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
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: showsSearchField)) { $0.opacity(showsSearchField ? 1 : 0) }
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
