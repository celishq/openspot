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
    @State private var sheetHasLeftCard = false

    static let panelSpace = "panel"
    private static let fieldGap: CGFloat = 8
    static let gridTop: CGFloat = SpotTokens.halo + SpotTokens.rowHeight + SpotTokens.rowGap
    private static let gridBottom: CGFloat = SpotTokens.halo + SpotTokens.hintBlock

    var body: some View {
        let card = sheetCard
        let frame = card.map(frame(of:))
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                SpotGridView(
                    model: model,
                    isSheetOpen: sheetOpen,
                    openID: card?.id,
                    open: card?.placement,
                    openFrame: frame,
                    sheetRect: sheetRect,
                    scrollOffset: $scrollOffset,
                    dropTarget: $dropTarget,
                    dragged: $dragged
                )
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
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: !coversGrid)) { $0.opacity(coversGrid ? 0 : 1) }
            hintLine
                .opacity(model.isShown ? 1 : 0)
                .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            if let entry = model.entries.first(where: { $0.id == sheetID }) {
                SpotSheetView(
                    entry: entry,
                    cardSize: card?.placement.size ?? entry.size,
                    isOpen: sheetOpen,
                    showsFill: entry.state.on == true && !sheetHasLeftCard,
                    sheet: model.sheets[entry.id],
                    rect: sheetRect,
                    form: model.form?.entry.id == entry.id ? model.form?.draft : nil,
                    panel: shownPanel,
                    work: { model.work(of: $0) },
                    onSet: { model.setPart($0, to: $1) },
                    onPress: { model.pressPart($0) },
                    recording: model.recording,
                    onRecord: { model.toggleRecording($0) },
                    createTitle: { model.createAction.map { "\($0.title): \(model.searchText)" } },
                    onCreate: { model.createFromSearch() },
                    onFormValue: { model.setFormValue($0, for: $1) },
                    onRun: { model.runItem($0) },
                    closeShift: isInstall(entry) ? 0 : cardShows(arrowOf: entry, card: card, frame: frame) ? (frame?.width ?? sheetRect.width) - sheetRect.width : nil,
                    onClose: {
                        model.allowSheetMotion()
                        model.closeList()
                    },
                    cardWidth: isInstall(entry) ? fieldRect.width : frame?.width ?? sheetRect.width,
                    nudge: { model.sheets[entry.id]?.nudge ?? SpotPanel.Nudge.rest }
                )
                .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: sheetOpen)) { $0.opacity(card?.widget == nil || sheetOpen ? 1 : 0) }
                .overlay(alignment: .topLeading) {
                    if let widget = card?.widget, let frame {
                        widgetLook(widget, size: card?.placement.size ?? widget.size)
                            .frame(width: frame.width, height: frame.height)
                            .animation(SpotMotion.sheetFade(isOpen: sheetOpen, isLate: !sheetOpen)) { $0.opacity(sheetOpen ? 0 : 1) }
                            .allowsHitTesting(false)
                    }
                }
                .background {
                    SpotTheme.solid
                        .animation(SpotMotion.fillFade(isOpen: sheetOpen)) { $0.opacity(entry.state.on == true && !sheetOpen ? 1 : 0) }
                }
                .modifier(SpotSheetFrame(
                    rect: sheetOpen ? sheetRect : closedRect(of: entry, frame: frame),
                    radius: sheetOpen ? SpotTokens.radius : isInstall(entry) ? SpotTokens.corner(for: .strip) : SpotTokens.corner(for: card?.placement.size ?? entry.size),
                    sheetRect: sheetRect,
                    shift: sheetOpen ? .zero : shift(to: closedRect(of: entry, frame: frame)),
                    showsRing: !sheetOpen && cardIsSelected(card?.widget ?? entry),
                    arrow: cardShows(arrowOf: entry, card: card, frame: frame) ? AnyView(sheetArrow(of: entry, frame: frame)) : nil,
                    arrowBox: frame?.size ?? .zero
                ))
            }
            searchField
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
        .background {
            SpotHintWatch(model: model) { hint in
                let motion = model.isEditing || hintIsForEdit || lastDrop != nil ? SpotMotion.hintFade : nil
                hintIsForEdit = model.isEditing
                withAnimation(motion) {
                    if model.openList == nil, model.spotDrop == nil { gridHint = hint } else { sheetHint = hint }
                }
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
                partsLanded = model.sheets[list]?.panel != nil
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
                        partsLanded = false
                        model.endReview()
                        if installIsClosing { hideDrop() }
                        installIsClosing = false
                    }
                }
            }
        }
    }

    /// Changes the colours of the sheet's header with the fill of its card.
    private func letFieldCrossHeader(isOpen: Bool) {
        withAnimation(SpotMotion.fillFade(isOpen: isOpen)) { sheetHasLeftCard = isOpen }
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
        let shape = model.sheets[sheetID ?? ""]?.shape
        return SpotTokens.sheetRect(rows: shape?.rows ?? 0, perLine: shape?.perLine ?? 1)
    }

    /// The rect that the sheet grows out of and collapses into: its card, or the field for the install screen.
    private func closedRect(of entry: SpotsModel.Entry, frame: CGRect?) -> CGRect {
        isInstall(entry) ? fieldRect : frame ?? sheetRect
    }

    /// How far the sheet's content lies from its open place when it lies on a closed rect.
    private func shift(to closed: CGRect) -> CGSize {
        CGSize(width: closed.minX - sheetRect.minX, height: closed.minY - sheetRect.minY)
    }

    /// Whether the card of this open sheet draws an arrow. A 1x1 card shows its glyph alone, and a widget draws none.
    private func cardShows(arrowOf entry: SpotsModel.Entry, card: SheetCard?, frame: CGRect?) -> Bool {
        entry.kind == .list && card?.widget == nil && (frame?.width ?? 0) > SpotTokens.cell
    }

    /// The arrow of the card while its sheet moves. It stays in view until the close button takes its place at the edge.
    private func sheetArrow(of entry: SpotsModel.Entry, frame: CGRect?) -> some View {
        SpotCardArrow(isOnSolid: entry.state.on == true && !sheetOpen)
            .placed(isTall: (frame?.height ?? 0) > SpotTokens.rowHeight)
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
            .offset(y: height - SpotTokens.halo - SpotTokens.hintPillHeight)
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

    /// The card that the open sheet grows from, on the grid. Its size can differ from the size it prefers.
    private struct SheetCard {
        let id: String
        let placement: SpotPlacement
        /// The widget that opens the sheet, whose look the sheet takes at the size of its card. Nil for the sheet's own card.
        let widget: SpotsModel.Entry?
    }

    /// The card that the open sheet grows from: its own card on the grid, or else a widget that opens it.
    private var sheetCard: SheetCard? {
        guard let sheetID else { return nil }
        let visible = model.visible
        let index = visible.firstIndex { $0.id == sheetID }
            ?? visible.firstIndex { $0.kind == .widget && $0.command.opens == sheetID }
        guard let index, let placement = model.placements.first(where: { $0.index == index }) else { return nil }
        let entry = visible[index]
        return SheetCard(id: entry.id, placement: placement, widget: entry.id == sheetID ? nil : entry)
    }

    /// The places of the widget without its glass, since the sheet draws the glass under them.
    @ViewBuilder
    private func widgetLook(_ widget: SpotsModel.Entry, size: SpotSize) -> some View {
        if let layout = widget.command.layout {
            SpotWidgetView(layout: layout, places: widget.command.places, readings: model.readings, card: size)
                .padding(SpotTokens.cardPadding(for: size, isWidget: true))
        }
    }

    /// Where the card of the open sheet lies in the panel, which the grid and its scroll say.
    private func frame(of card: SheetCard) -> CGRect {
        let spot = card.placement
        return CGRect(
            x: SpotTokens.halo + CGFloat(spot.column) * (SpotTokens.cell + SpotTokens.columnGap),
            y: Self.gridTop + CGFloat(spot.row) * (SpotTokens.rowHeight + SpotTokens.rowGap) - scrollOffset,
            width: SpotTokens.width(columns: spot.size.columns),
            height: SpotTokens.height(rows: spot.size.rows)
        )
    }

    /// The top of the grid in Edit Spots, in the place of the search field.
    private var editHeader: some View {
        HStack {
            Text("Edit Spots")
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.ink)
            Spacer()
            SpotRoundButton(symbol: "checkmark", label: "Done") { model.endEditing() }
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
        .offset(x: SpotTokens.halo, y: SpotTokens.halo)
    }

    /// The field: a surface that grows from its place at rest to its row in the sheet, with its glyph and its words on top,
    /// which keep one size and move by offsets alone.
    private var searchField: some View {
        let place = fieldIsInSheet ? fieldRowRect : fieldRect
        let top = SpotTokens.halo + (fieldIsInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let glyphLeft = SpotTokens.halo + SpotTokens.padding + (fieldIsInSheet ? SpotTokens.padding + (SpotTokens.listIconSize - SpotTokens.glyphSize) / 2 : 0)
        return ZStack(alignment: .topLeading) {
            SpotSurface(rect: place, radius: fieldRadius, glass: fieldIsInSheet || sheetID == ShippedSpot.installID ? 0 : 1, fill: fieldIsInSheet ? 1 : 0)
            ZStack(alignment: .topLeading) {
                Image(systemName: "magnifyingglass")
                    .modifier(SpotSecondaryText())
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.rowHeight)
                    .offset(x: glyphLeft, y: top)
                searchText
                    .frame(width: Self.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                    .offset(x: fieldTextLeft, y: top)
            }
            .modifier(SpotFieldCrossing(isOpen: sheetOpen, crosses: sheetID != ShippedSpot.installID))
            .opacity(showsDrop ? 0 : 1)
            .opacity(model.isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
            if let lastDrop {
                SpotDropView(drop: lastDrop)
                    .padding(.horizontal, SpotTokens.padding)
                    .frame(width: fieldRect.width, height: fieldRect.height)
                    .offset(x: fieldRect.minX, y: fieldRect.minY)
                    .opacity(showsDrop ? 1 : 0)
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.ink)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .scaleEffect(model.isShown ? 1 : SpotMotion.hiddenScale, anchor: UnitPoint(x: 0.5, y: fieldRect.midY / SpotTokens.panelHeight))
        .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
    }

    /// The field's row in an open sheet.
    private var fieldRowRect: CGRect {
        CGRect(
            x: SpotTokens.halo + SpotTokens.padding,
            y: SpotTokens.halo + SpotTokens.sheetFieldDrop,
            width: SpotTokens.gridWidth - 2 * SpotTokens.padding,
            height: SpotTokens.listRowHeight
        )
    }

    /// The width of the field's words, as narrow as its row in a sheet, so that it stays one size.
    private static let fieldTextWidth = SpotTokens.gridWidth - 4 * SpotTokens.padding - SpotTokens.listIconSize - fieldGap

    /// Where the field's words start, at rest and in a sheet.
    private var fieldTextLeft: CGFloat {
        fieldIsInSheet
            ? SpotTokens.halo + 2 * SpotTokens.padding + SpotTokens.listIconSize + Self.fieldGap
            : SpotTokens.halo + SpotTokens.padding + SpotTokens.glyphSize + Self.fieldGap
    }

    private var searchText: some View {
            SpotSearchText(model: model, title: "\(SearchPrompt.verb) \(sheetOpen ? sheetWord : SearchPrompt.grid)")
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

    /// The empty field's words, as a layer of their own that moves with the field by offsets alone, which stay smooth where
    /// layout rounds to whole pixels.
    private var promptLayer: some View {
        let top = SpotTokens.halo + (fieldIsInSheet ? SpotTokens.sheetFieldDrop - (SpotTokens.rowHeight - SpotTokens.listRowHeight) / 2 : 0)
        let left = fieldTextLeft
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
        .modifier(SpotFieldCrossing(isOpen: sheetOpen, crosses: sheetID != ShippedSpot.installID))
        .modifier(SpotEmptyField(model: model, isHidden: showsDrop))
    }

    private var fieldRadius: CGFloat {
        fieldIsInSheet ? SpotTokens.radius - SpotTokens.padding : SpotTokens.corner(for: .strip)
    }

    private var sheetWord: String {
        SearchPrompt.word(for: model.entries.first { $0.id == sheetID }?.state.title ?? "")
    }
}
