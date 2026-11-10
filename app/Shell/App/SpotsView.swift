import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @State private var edges = SpotScrollEdges()
    @State private var scroll = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var dropTarget: String?

    /// The sheet that is built, from its first frame on its card to the end of its close.
    private var sheetID: String? {
        model.transition.id
    }

    /// Whether the sheet is open or on its way there.
    private var sheetOpen: Bool {
        model.transition.isOpen
    }

    static let panelSpace = "panel"
    fileprivate static let gridBottom: CGFloat = SpotTokens.halo + SpotTokens.hintBlock

    var body: some View {
        let card = SpotSheetCard.of(sheetID, in: model)
        let frame = card?.frame(scrollOffset: scrollOffset)
        let panel = panelSize
        let gridPart = SpotTokens.gridPanelHeight(rows: model.panelSize.rows)
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                SpotGridView(
                    model: model,
                    isSheetOpen: sheetOpen,
                    openID: card?.id,
                    push: card.map(push(from:)),
                    dropTarget: $dropTarget
                )
                    .offset(y: gridPush)
                    .padding(.horizontal, SpotTokens.halo)
                    .padding(.top, SpotTokens.gridTop)
                    .padding(.bottom, Self.gridBottom)
            }
            .scrollPosition($scroll)
            .modifier(GridSelectionFollow(model: model, scroll: $scroll, scrollOffset: $scrollOffset))
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
                scrollOffset = offset
                model.gridScrolled(to: offset)
            })
            .modifier(GridEdgeScroll(model: model, scroll: $scroll))
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .frame(width: panel.width, height: gridPart)
            .mask(edges.gradient(height: cardHeight, whole: gridPart))
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: !coversGrid)) { $0.opacity(coversGrid ? 0 : 1) }
            SpotHintLine(model: model, surfaceIsOut: surfaceIsOut, gridHeight: gridHeight, sheetHeight: sheetID == nil ? gridHeight : sheetHeight, width: panel.width, sheetShift: sheetShift)
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
                    panel: shownPanel,
                    cardMask: edges.gradient(height: cardHeight, whole: panel.height)
                )
            }
            SpotFieldView(
                model: model,
                isOpen: sheetOpen,
                isInSheet: fieldIsInSheet,
                isInstall: sheetID == ShippedSpot.installID,
                showsField: showsSearchField,
                surfaceIsOut: surfaceIsOut,
                sheetShift: sheetShift
            )
            if model.isEditing {
                editHeader
                    .transition(.opacity)
                panelHandle
                    .transition(.opacity)
            }
            if let menu = model.menu {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeMenu() }
                SpotActionMenuView(menu: menu, work: { model.work(of: $0) }, onPress: { model.pressMenu(row: $0) }, onSearch: { model.searchMenu($0) })
                    .offset(x: SpotTokens.halo, y: menuTop(menu))
            }
        }
        .onDrop(of: [.fileURL], delegate: SpotAddDrop(model: model))
        .coordinateSpace(name: Self.panelSpace)
        .frame(width: panel.width, height: panel.height)
        .background(softBlur)
        .environment(\.spotIsShown, model.isShown)
        .environment(\.spotPanelSize, panel)
        .onChange(of: model.isShown) { _, isShown in
            if !isShown { dropTarget = nil }
        }
    }

    /// The blur of the grid and the blur of the sheet, each with a fixed size, which crossfade as the sheet moves.
    private var softBlur: some View {
        ZStack(alignment: .top) {
            blur(height: gridHeight, isShown: !sheetOpen)
            blur(height: max(sheetHeight, replacedHeight), isShown: sheetOpen)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .opacity(model.isShown ? 1 : 0)
        .scaleEffect(model.isShown ? 1 : SpotMotion.backdropHiddenScale)
        .animation(SpotMotion.surface(isShown: model.isShown), value: model.isShown)
    }

    private func blur(height: CGFloat, isShown: Bool) -> some View {
        let height = max(height, menuBackdropHeight)
        return SpotSoftBlur(width: panelSize.width, height: height)
            .frame(height: height)
            .transaction { $0.animation = nil }
            .animation(SpotMotion.blurFade(isSheetOpen: sheetOpen)) { $0.opacity(isShown ? 1 : 0) }
    }

    /// How the open sheet pushes the cards of the grid, with the sheet's rect taken into the grid. Its window starts at the
    /// top of the search field, so a card that moves up is gone there.
    private func push(from card: SpotSheetCard) -> SheetPush {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset)
        let window = CGRect(x: -origin.x, y: SpotTokens.halo - origin.y, width: panelSize.width, height: panelSize.height - SpotTokens.halo)
        return SheetPush(open: card.placement, sheet: sheetRect.offsetBy(dx: -origin.x, dy: -origin.y), window: window)
    }

    /// The size of the panel's window, from the size of the grid that the person set.
    private var panelSize: CGSize {
        CGSize(width: SpotTokens.panelWidth(columns: model.panelSize.columns), height: SpotTokens.windowHeight(rows: model.panelSize.rows))
    }

    /// How far right the open sheet lies: over the four columns that hold its card.
    private var sheetShift: CGFloat {
        SpotSheetCard.of(sheetID, in: model).map { SpotTokens.sheetShift(column: $0.placement.column) } ?? 0
    }

    private var sheetRect: CGRect {
        if let form = model.form { return SpotTokens.formRect(form.draft.form).offsetBy(dx: sheetShift, dy: 0) }
        return rect(of: sheetID).offsetBy(dx: sheetShift, dy: 0)
    }

    /// The rect of a sheet from its parts, or else from the shape of its rows.
    private func rect(of id: String?) -> CGRect {
        if let panel = model.sheets[id ?? ""]?.panel { return SpotTokens.panelRect(panel) }
        let shape = model.sheets[id ?? ""]?.shape
        return SpotTokens.sheetRect(rows: shape?.rows ?? 0, perLine: shape?.perLine ?? 1)
    }

    /// The height of the sheet that the open one took the place of, so that the blur stays under both until the change
    /// settles.
    private var replacedHeight: CGFloat {
        guard let replaced = model.transition.replaced else { return 0 }
        return rect(of: replaced).height + 2 * SpotTokens.halo + SpotTokens.hintBlock
    }

    /// The parts of the open sheet.
    private var shownPanel: SheetParts? {
        model.shownParts(of: sheetID)
    }

    /// How far the install screen pushes the grid: as far as its lower edge moves.
    private var gridPush: CGFloat {
        coversGrid ? sheetRect.maxY - SpotFieldView.rect.maxY : 0
    }

    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    private var surfaceIsOut: Bool {
        sheetOpen || (model.showsFieldDrop && !(model.transition.phase == .closing && sheetID == ShippedSpot.installID))
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

    /// The height of the grid's part of the panel: as tall as its cards, or in Edit Spots as tall as the size the person set.
    private var gridHeight: CGFloat {
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        return SpotTokens.backdropHeight(rows: model.isEditing ? max(rows, model.panelSize.rows) : rows, shown: model.panelSize.rows)
    }

    /// The height of the shape that ends the cards. It follows only the grid, so that a sheet's motion swaps no image.
    private var cardHeight: CGFloat {
        max(gridHeight, menuBackdropHeight)
    }

    private var menuBackdropHeight: CGFloat {
        model.menu.map { SpotTokens.menuHeight(rows: $0.lines) + 2 * SpotTokens.halo } ?? 0
    }

    /// Where the menu starts: its bottom meets the bottom of the content.
    private func menuTop(_ menu: ActionMenu) -> CGFloat {
        max(SpotTokens.halo, contentHeight - SpotTokens.halo - SpotTokens.hintBlock - SpotTokens.menuHeight(rows: menu.lines))
    }

    /// Whether the install screen takes the place of the grid and the field.
    private var coversGrid: Bool {
        sheetOpen && sheetID == ShippedSpot.installID
    }

    /// Whether the search field is drawn. A form, a sheet of parts and the install screen replace it, but a form of one choice
    /// keeps it to search its rows.
    private var showsSearchField: Bool {
        guard !coversGrid else { return false }
        if let form = model.form { return form.draft.choices != nil }
        guard sheetOpen else { return true }
        return model.sheets[sheetID ?? ""]?.kind.showsField != false
    }

    /// The handle just past the bottom right corner of the grid in Edit Spots, which the person drags to set the panel's
    /// columns and rows.
    private var panelHandle: some View {
        let side = SpotTokens.resizeHandle
        let corner = CGPoint(
            x: SpotTokens.halo + SpotTokens.width(columns: model.panelSize.columns) + SpotTokens.panelHandleGap,
            y: SpotTokens.gridTop + SpotTokens.height(rows: model.panelSize.rows) + SpotTokens.panelHandleGap
        )
        return SpotResizeHandle(size: .large)
            .background(Color.clear.contentShape(Rectangle()).gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.panelSpace))
                    .onChanged { model.resizePanel(by: $0.translation) }
                    .onEnded { _ in model.dropPanelResize() }
            ))
            .help("Drag to change the columns and the rows")
            .offset(x: corner.x - side, y: corner.y - side)
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
        .frame(width: SpotTokens.width(columns: model.panelSize.columns), height: SpotTokens.rowHeight)
        .offset(x: SpotTokens.halo, y: SpotTokens.halo)
    }
}

/// Scrolls the grid while a lifted card lies in the fade at either end of the grid's clear part, faster the deeper it lies,
/// once a frame until the drag ends.
private struct GridEdgeScroll: ViewModifier {
    let model: SpotsModel
    @Binding var scroll: ScrollPosition

    func body(content: Content) -> some View {
        content.task(id: model.drag?.id) {
            var last = ContinuousClock.now
            while !Task.isCancelled, model.drag != nil {
                try? await Task.sleep(for: .milliseconds(8))
                let now = ContinuousClock.now
                let seconds = (now - last) / .seconds(1)
                last = now
                step(seconds: seconds)
            }
        }
    }

    private func step(seconds: Double) {
        guard let drag = model.drag else { return }
        let rows = model.placements.map { $0.row + $0.size.rows }.max() ?? 0
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.gridPanelHeight(rows: model.panelSize.rows) - SpotsView.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.gridPanelHeight(rows: model.panelSize.rows),
            contentHeight: SpotTokens.gridTop + SpotTokens.height(rows: rows) + SpotsView.gridBottom
        )
        let point = SpotTokens.gridTop + drag.centre(movedBy: model.lift.offset).y
        let next = window.offset(scrolling: point, from: model.gridScroll, by: SpotMotion.edgeScrollSpeed * seconds, over: SpotScrollEdges.fadeLength)
        if next != model.gridScroll { scroll.scrollTo(y: next) }
    }
}

/// Scrolls the grid until the selected spot lies clear of the fades at its two ends. It alone reads the selection, so that an
/// arrow press on the grid reruns this modifier and not the panel. The grid holds still under a drag.
private struct GridSelectionFollow: ViewModifier {
    let model: SpotsModel
    @Binding var scroll: ScrollPosition
    @Binding var scrollOffset: CGFloat

    func body(content: Content) -> some View {
        content.onChange(of: model.selected) { show() }
    }

    private func show() {
        let placements = model.placements
        guard model.openList == nil, model.drag == nil, let spot = placements.first(where: { $0.index == model.selected }) else { return }
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        let top = SpotTokens.gridTop + spot.rect.minY
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.gridPanelHeight(rows: model.panelSize.rows) - SpotsView.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.gridPanelHeight(rows: model.panelSize.rows),
            contentHeight: SpotTokens.gridTop + SpotTokens.height(rows: rows) + SpotsView.gridBottom
        )
        let offset = window.offset(showing: top...(top + SpotTokens.height(rows: spot.size.rows)), from: scrollOffset)
        guard offset != scrollOffset else { return }
        withAnimation(SpotMotion.follow) { scroll.scrollTo(y: offset) }
    }
}
