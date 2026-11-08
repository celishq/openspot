import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @FocusState private var searchFocused: Bool
    @State private var edges = SpotScrollEdges()
    @State private var scroll = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var gridHint = ""
    @State private var sheetHint = ""
    @State private var dropTarget: String?
    @State private var dragged: (id: String, offset: CGSize)?
    @State private var hintIsForEdit = false
    @State private var showsDrop = false
    @State private var lastDrop: SpotDrop?

    /// The sheet that is built, from its first frame on its card to the end of its close.
    private var sheetID: String? {
        model.transition.id
    }

    /// Whether the sheet is open or on its way there.
    private var sheetOpen: Bool {
        model.transition.isOpen
    }

    static let panelSpace = "panel"
    private static let gridBottom: CGFloat = SpotTokens.halo + SpotTokens.hintBlock

    var body: some View {
        let card = SpotSheetCard.of(sheetID, in: model)
        let frame = card?.frame(scrollOffset: scrollOffset)
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                SpotGridView(
                    model: model,
                    isSheetOpen: sheetOpen,
                    openID: card?.id,
                    push: card.map(push(from:)),
                    scrollOffset: $scrollOffset,
                    dropTarget: $dropTarget,
                    dragged: $dragged
                )
                    .offset(y: gridPush)
                    .padding(.horizontal, SpotTokens.halo)
                    .padding(.top, SpotTokens.gridTop)
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
                SpotSheetLayer(
                    model: model,
                    entry: entry,
                    card: card,
                    frame: frame,
                    sheetRect: sheetRect,
                    isOpen: sheetOpen,
                    hasLeftCard: model.sheetHasLeftCard,
                    panel: shownPanel,
                    cardMask: edges.gradient(height: cardHeight)
                )
            }
            SpotFieldView(
                model: model,
                isOpen: sheetOpen,
                isInSheet: fieldIsInSheet,
                isInstall: sheetID == ShippedSpot.installID,
                showsField: showsSearchField,
                surfaceIsOut: surfaceIsOut,
                showsDrop: showsDrop,
                lastDrop: lastDrop,
                sheetWord: sheetWord,
                focus: $searchFocused
            )
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
            if model.transition.phase == .ready || model.transition.phase == .closing {
                holdDropInField()
            } else {
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    showsDrop = false
                    lastDrop = nil
                }
            }
        }
        .onChange(of: model.transition) { old, new in
            if new.phase == .open, new.id == ShippedSpot.installID {
                showsDrop = false
                lastDrop = nil
            } else if new.phase == .closed, old.id == ShippedSpot.installID {
                hideDrop()
            }
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
        let top = SpotTokens.gridTop + spot.rect.minY
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.panelHeight - Self.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: SpotTokens.gridTop + SpotTokens.height(rows: rows) + Self.gridBottom
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

    /// How the open sheet pushes the cards of the grid, with the sheet's rect taken into the grid. Its window starts at the
    /// top of the search field, so a card that moves up is gone there.
    private func push(from card: SpotSheetCard) -> SheetPush {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset)
        let window = CGRect(x: -origin.x, y: SpotTokens.halo - origin.y, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight - SpotTokens.halo)
        return SheetPush(open: card.placement, sheet: sheetRect.offsetBy(dx: -origin.x, dy: -origin.y), window: window)
    }

    private var sheetRect: CGRect {
        if let form = model.form { return SpotTokens.formRect(form.draft.form) }
        if let shownPanel { return SpotTokens.panelRect(shownPanel) }
        let shape = model.sheets[sheetID ?? ""]?.shape
        return SpotTokens.sheetRect(rows: shape?.rows ?? 0, perLine: shape?.perLine ?? 1)
    }

    /// The parts of the open sheet.
    private var shownPanel: SheetParts? {
        model.sheets[sheetID ?? ""]?.panel
    }

    /// How far the install screen pushes the grid: as far as its lower edge moves.
    private var gridPush: CGFloat {
        coversGrid ? sheetRect.maxY - SpotFieldView.rect.maxY : 0
    }

    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    private var surfaceIsOut: Bool {
        sheetOpen || (showsDrop && !(model.transition.phase == .closing && sheetID == ShippedSpot.installID))
    }

    /// Whether the field lies in the open sheet. The install screen grows out of the field, which stays where it is.
    private var fieldIsInSheet: Bool {
        sheetOpen && sheetID != ShippedSpot.installID
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

    /// The hint under the grid and the hint under the sheet. Each stays at its own place, and one fades out before the other fades in.
    private var hintLine: some View {
        ZStack(alignment: .top) {
            hint(gridHint, isShown: !surfaceIsOut, height: gridHeight)
            hint(sheetWords, isShown: surfaceIsOut, height: sheetID == nil ? gridHeight : sheetHeight)
        }
    }

    private func hint(_ words: String, isShown: Bool, height: CGFloat) -> some View {
        SpotHint(text: words, onPress: model.pressHint)
            .frame(width: SpotTokens.panelWidth)
            .allowsHitTesting(isShown)
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

    private var sheetWord: String {
        SearchPrompt.word(for: model.entries.first { $0.id == sheetID }?.state.title ?? "")
    }
}
