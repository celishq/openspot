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
    @State private var installIsClosing = false
    @State private var fieldWordsAreHidden = false
    @State private var sheetHasLeftCard = false

    private static let panelSpace = "panel"
    private static let fieldGap: CGFloat = 8
    private static let gridTop: CGFloat = SpotTokens.halo + SpotTokens.rowHeight + SpotTokens.rowGap
    private static let gridBottom: CGFloat = SpotTokens.halo + SpotTokens.hintBlock

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                grid
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
            .mask(edges.gradient(height: cardHeight))
            .mask(alignment: .top) {
                SpotSoftBlur.cardMask(height: cardHeight)
                    .resizable()
                    .frame(height: cardHeight)
            }
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: !coversGrid)) { $0.opacity(coversGrid ? 0 : 1) }
            hintLine
                .opacity(model.isShown ? 1 : 0)
                .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            if let entry = model.entries.first(where: { $0.id == sheetID }) {
                SpotSheetView(
                    entry: entry,
                    cardSize: cardSize(of: entry),
                    isOpen: sheetOpen,
                    isOn: entry.state.on == true,
                    fillCovers: !sheetHasLeftCard,
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
                    closeShift: isInstall(entry) ? 0 : cardShows(arrowOf: entry) ? (openFrame?.width ?? sheetRect.width) - sheetRect.width : nil,
                    onClose: {
                        model.allowSheetMotion()
                        model.closeList()
                    }
                )
                .modifier(SpotSheetFrame(
                    rect: sheetOpen ? sheetRect : isInstall(entry) ? fieldRect : openFrame ?? sheetRect,
                    radius: sheetOpen ? SpotTokens.radius : isInstall(entry) ? SpotTokens.corner(for: .strip) : SpotTokens.corner(for: cardSize(of: entry)),
                    ringOpacity: !sheetOpen && cardIsSelected(entry) ? 1 : 0,
                    arrow: cardShows(arrowOf: entry) ? AnyView(sheetArrow(of: entry)) : nil
                ))
            }
            searchField
                .padding(.horizontal, fieldIsInSheet ? SpotTokens.halo + SpotTokens.padding : SpotTokens.halo)
                .padding(.top, SpotTokens.halo)
                .offset(y: fieldIsInSheet ? SpotTokens.sheetFieldDrop : 0)
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
        .background(softBlur)
        .environment(\.spotIsShown, model.isShown)
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
            if let drop {
                lastDrop = drop
                withAnimation(SpotMotion.sheet(isOpen: true)) { showsDrop = true }
            } else if !model.isReviewing {
                hideDrop()
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
            let motion = model.isEditing || hintIsForEdit || lastDrop != nil ? SpotMotion.hintFade : nil
            hintIsForEdit = model.isEditing
            withAnimation(motion) {
                if model.openList == nil, model.spotDrop == nil { gridHint = hint } else { sheetHint = hint }
            }
        }
        .onChange(of: model.openList) { _, list in
            if list != nil { sheetHint = model.hint }
            guard model.sheetMoves else {
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    sheetID = list
                    sheetOpen = list != nil
                    sheetHasLeftCard = list != nil
                    showsDrop = false
                    lastDrop = nil
                }
                model.allowSheetMotion()
                if list == nil { model.endReview() }
                return
            }
            if let list {
                sheetID = list
                holdDropInField()
                DispatchQueue.main.async {
                    letFieldCrossHeader(isOpen: true)
                    withAnimation(SpotMotion.sheet(isOpen: true), completionCriteria: .removed) {
                        sheetOpen = true
                    } completion: {
                        if sheetOpen, sheetID == ShippedSpot.installID {
                            showsDrop = false
                            lastDrop = nil
                        }
                    }
                }
            } else {
                holdDropInField()
                installIsClosing = sheetID == ShippedSpot.installID
                letFieldCrossHeader(isOpen: false)
                withAnimation(SpotMotion.sheet(isOpen: false), completionCriteria: .removed) {
                    sheetOpen = false
                } completion: {
                    if model.openList == nil {
                        sheetID = nil
                        model.endReview()
                        if installIsClosing { hideDrop() }
                        installIsClosing = false
                    }
                }
            }
        }
    }

    /// Hides the field's words while the field passes the sheet's header on the way into or out of the sheet, and changes the
    /// colours of the header with the fill of its card.
    private func letFieldCrossHeader(isOpen: Bool) {
        withAnimation(SpotMotion.sheetFade(isOpen: isOpen, isLate: !isOpen)) { sheetHasLeftCard = isOpen }
        guard sheetID != ShippedSpot.installID else { return }
        withAnimation(SpotMotion.wordsOut(isOpen: isOpen)) {
            fieldWordsAreHidden = true
        } completion: {
            withAnimation(SpotMotion.wordsIn(isOpen: isOpen)) { fieldWordsAreHidden = false }
        }
    }

    /// Keeps the words of a review in the field, where they lie under the sheet's header as the sheet grows out of the field or
    /// closes back into it.
    private func holdDropInField() {
        guard let drop = model.reviewDrop else { return }
        lastDrop = drop
        withAnimation(SpotMotion.sheetFade(isOpen: true, isLate: false)) { showsDrop = true }
    }

    /// Gives the field back its search.
    private func hideDrop() {
        withAnimation(SpotMotion.sheet(isOpen: false), completionCriteria: .removed) {
            showsDrop = false
        } completion: {
            if !showsDrop { lastDrop = nil }
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

    /// The blur of the grid and the blur of the sheet, each with a fixed size, which crossfade as the sheet moves.
    private var softBlur: some View {
        ZStack(alignment: .top) {
            blur(height: gridHeight, isShown: !sheetOpen)
            blur(height: sheetHeight, isShown: sheetOpen)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(model.isShown ? 1 : 0)
        .scaleEffect(model.isShown ? 1 : SpotMotion.backdropHiddenScale)
        .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
    }

    private func blur(height: CGFloat, isShown: Bool) -> some View {
        let height = max(height, menuBackdropHeight)
        return SpotSoftBlur(height: height)
            .frame(height: height)
            .transaction { $0.animation = nil }
            .animation(SpotMotion.blurFade(isSheetOpen: sheetOpen)) { $0.opacity(isShown ? 1 : 0) }
    }

    private var sheetRect: CGRect {
        if let form = model.form { return SpotTokens.formRect(form.draft.form) }
        if let shownPanel { return SpotTokens.panelRect(shownPanel) }
        let list = model.sheets[sheetID ?? ""]?.list
        return SpotTokens.sheetRect(rows: list?.shown.count ?? 0, perLine: list?.perLine ?? 1)
    }

    /// Whether the card of this open sheet draws an arrow. A 1x1 card shows its glyph alone.
    private func cardShows(arrowOf entry: SpotsModel.Entry) -> Bool {
        entry.kind == .list && (openFrame?.width ?? 0) > SpotTokens.cell
    }

    /// The arrow of the card while its sheet moves. It stays in view until the close button takes its place at the edge.
    private func sheetArrow(of entry: SpotsModel.Entry) -> some View {
        let frame = sheetOpen ? sheetRect : openFrame ?? sheetRect
        return ZStack {
            SpotCardArrow(isOnSolid: false)
                .placed(isTall: (openFrame?.height ?? 0) > SpotTokens.rowHeight)
            if entry.state.on == true {
                SpotCardArrow(isOnSolid: true)
                    .placed(isTall: (openFrame?.height ?? 0) > SpotTokens.rowHeight)
                    .frame(width: frame.width, height: frame.height, alignment: .topTrailing)
                    .modifier(SpotFillReach(size: frame.size, center: SpotSheetView.glyphCenter(isSmall: false), covers: !sheetHasLeftCard))
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .topTrailing)
            .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: !sheetOpen)) { $0.opacity(sheetOpen ? 0 : 1) }
            .allowsHitTesting(false)
    }

    /// The parts of the open sheet, once they have landed. They arrive in one change with the sheet's new size, on its spring.
    private var shownPanel: SpotPanel? {
        partsLanded ? model.sheets[sheetID ?? ""]?.panel : nil
    }

    /// Where the search field lies at rest. The install screen grows out of it and collapses into it.
    private var fieldRect: CGRect {
        CGRect(x: SpotTokens.halo, y: SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
    }

    /// How far the install screen pushes the grid: as far as its lower edge moves.
    private var gridPush: CGFloat {
        coversGrid ? sheetRect.maxY - fieldRect.maxY : 0
    }

    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    private var surfaceIsOut: Bool {
        sheetOpen || (showsDrop && !installIsClosing)
    }

    /// Whether the field lies in the open sheet. The install screen grows out of the field, which stays where it is.
    private var fieldIsInSheet: Bool {
        sheetOpen && sheetID != ShippedSpot.installID
    }

    private func isInstall(_ entry: SpotsModel.Entry) -> Bool {
        entry.id == ShippedSpot.installID
    }

    private var contentHeight: CGFloat {
        sheetOpen ? sheetHeight : gridHeight
    }

    private var sheetHeight: CGFloat {
        sheetRect.height + 2 * SpotTokens.halo + SpotTokens.hintBlock
    }

    private var gridHeight: CGFloat {
        SpotTokens.backdropHeight(rows: model.placements.map { $0.row + $0.size.rows }.max() ?? 0)
    }

    /// The height of the shape that ends the cards. It follows only the grid, so that a sheet's motion swaps no image.
    private var cardHeight: CGFloat {
        max(gridHeight, menuBackdropHeight)
    }

    private var menuBackdropHeight: CGFloat {
        model.menu.map { SpotTokens.menuHeight(rows: $0.rows.count) + 2 * SpotTokens.halo } ?? 0
    }

    /// Where the menu starts: its bottom meets the bottom of the content.
    private func menuTop(_ menu: ActionMenu) -> CGFloat {
        max(SpotTokens.halo, contentHeight - SpotTokens.halo - SpotTokens.hintBlock - SpotTokens.menuHeight(rows: menu.rows.count))
    }

    private func cardIsSelected(_ entry: SpotsModel.Entry) -> Bool {
        model.placements.first { model.visible[$0.index].id == entry.id }?.index == model.selected
    }

    /// The hint under the grid and the hint under the sheet. Each stays at its own place, and one fades out before the other fades in.
    private var hintLine: some View {
        ZStack(alignment: .top) {
            hint(gridHint, isShown: !surfaceIsOut, height: gridHeight)
            hint(sheetWords, isShown: surfaceIsOut, height: sheetID == nil ? gridHeight : sheetHeight)
        }
    }

    private func hint(_ words: String, isShown: Bool, height: CGFloat) -> some View {
        SpotHint(text: words)
            .frame(width: SpotTokens.panelWidth)
            .offset(y: height - SpotTokens.halo - SpotTokens.hintHeight - SpotTokens.hintPillInset)
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: isShown)) { $0.opacity(isShown ? 1 : 0) }
    }

    /// What the hint says while a sheet shows: a form has its own keys.
    private var sheetWords: String {
        if model.form != nil { return "⌘⏎ Save   Esc Cancel" }
        return sheetHint
    }

    /// Whether the install screen takes the place of the grid and the field.
    private var coversGrid: Bool {
        sheetOpen && sheetID == ShippedSpot.installID
    }

    /// Whether the search field is drawn. A form, a sheet of parts and the install screen replace it.
    private var showsSearchField: Bool {
        guard model.form == nil, !coversGrid else { return false }
        guard sheetOpen else { return true }
        return shownPanel?.showsRows != false && model.sheets[sheetID ?? ""]?.awaitsFirstAnswer != true
    }

    /// The size that the grid gives the card of this sheet. Search and a short row can stretch a card past the size it prefers.
    private func cardSize(of entry: SpotsModel.Entry) -> SpotSize {
        model.placements.first { model.visible[$0.index].id == entry.id }?.size ?? entry.size
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

    /// How many rows lie between this card and the card of the sheet.
    private func rowsAway(of placement: SpotPlacement) -> Int {
        guard let open = model.placements.first(where: { model.visible[$0.index].id == sheetID }) else { return 0 }
        return abs(placement.row - open.row)
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
                    isHiddenFromGrid: model.isEditing && !entry.isOnGrid,
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
                .animation(SpotMotion.cardFade(isSheetOpen: sheetOpen, rowsAway: rowsAway(of: placement))) { $0.opacity(sheetOpen ? 0 : 1) }
                .opacity(entry.id == sheetID ? 0 : 1)
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
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.titleOpacity))
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
                .frame(width: fieldIsInSheet ? SpotTokens.listIconSize : SpotTokens.glyphSize)
            TextField("\(SearchPrompt.verb) \(sheetOpen ? sheetWord : SearchPrompt.grid)", text: Binding(get: { model.searchText }, set: { model.searchText = $0 }), prompt: Text(""))
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { model.runSelected() }
                .onKeyPress(.downArrow) {
                    if model.openList != nil {
                        model.moveItemLine(by: 1)
                    } else {
                        model.moveSelection(dx: 0, dy: 1)
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if model.openList != nil {
                        model.moveItemLine(by: -1)
                    } else {
                        model.moveSelection(dx: 0, dy: -1)
                    }
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    if model.openList != nil {
                        guard (model.openItems?.perLine ?? 1) > 1 else { return .ignored }
                        model.moveItem(by: -1)
                        return .handled
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
                        guard (model.openItems?.perLine ?? 1) > 1 else { return .ignored }
                        model.moveItem(by: 1)
                        return .handled
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
        .opacity(showsDrop || fieldWordsAreHidden ? 0 : 1)
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.titleOpacity))
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: fieldIsInSheet ? SpotTokens.listRowHeight : SpotTokens.rowHeight)
        .overlay {
            if let lastDrop {
                SpotDropView(drop: lastDrop)
                    .padding(.horizontal, SpotTokens.padding)
                    .opacity(showsDrop ? 1 : 0)
            }
        }
        .background(SpotTheme.ink.opacity(fieldIsInSheet ? SpotTheme.fill : 0), in: RoundedRectangle(cornerRadius: fieldRadius, style: .continuous))
        .modifier(SpotGlass(radius: fieldRadius, isBare: fieldIsInSheet || sheetID == ShippedSpot.installID))
    }

    /// The empty field's words, as a layer of their own that moves with the field by offsets alone, which stay smooth where
    /// layout rounds to whole pixels.
    private var promptLayer: some View {
        let top = SpotTokens.halo + (fieldIsInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let left = fieldIsInSheet
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
                    .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: !sheetOpen)) { $0.opacity(sheetOpen ? 0 : 1) }
                Text(sheetWord)
                    .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: sheetOpen)) { $0.opacity(sheetOpen ? 1 : 0) }
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        .lineLimit(1)
        .opacity(model.searchText.isEmpty && !showsDrop && !fieldWordsAreHidden ? 1 : 0)
    }

    private var fieldRadius: CGFloat {
        fieldIsInSheet ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

    private var sheetWord: String {
        SearchPrompt.word(for: model.entries.first { $0.id == sheetID }?.state.title ?? "")
    }
}
