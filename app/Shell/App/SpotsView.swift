import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @State private var fade = SpotScrollFade()
    @State private var scroll = ScrollPosition()
    @State private var scrollOffset: CGFloat = 0
    @State private var dropTarget: String?
    @Environment(\.spotDrawsBlur) private var drawsBlur

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
            .modifier(SpotScrollEdgeTracker(edges: Binding(get: { fade.edges }, set: { fade.edges = $0 })))
            .modifier(GridFadeMask(fade: fade, height: cardHeight))
            .animation(SpotMotion.sheetFade(isOpen: surfaceIsOut, isLate: !coversGrid)) { $0.opacity(coversGrid ? 0 : 1) }
            SpotHintLine(model: model, surfaceIsOut: surfaceIsOut, gridHeight: cardHeight, sheetHeight: max(sheetID == nil ? gridHeight : sheetHeight, menuBackdropHeight))
                .animation(SpotMotion.sheet(isOpen: model.menu != nil), value: menuBackdropHeight)
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
                    fade: fade,
                    fadeHeight: cardHeight
                )
            }
            SpotFieldView(
                model: model,
                isOpen: sheetOpen,
                isInSheet: fieldIsInSheet,
                isInstall: isInstall,
                showsField: showsSearchField,
                surfaceIsOut: surfaceIsOut
            )
            if model.menu != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { model.closeMenu() }
            }
        }
        .onDrop(of: [.fileURL], delegate: SpotAddDrop(model: model))
        .coordinateSpace(name: Self.panelSpace)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        .overlayPreferenceValue(SpotMenuAnchor.self, alignment: .topLeading) { item in
            menuLayer(at: item)
                .animation(SpotMotion.sheet(isOpen: model.menu != nil), value: model.menu == nil)
        }
        .background(softBlur)
        .environment(\.spotIsShown, model.isShown)
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

    @ViewBuilder
    private func blur(height: CGFloat, isShown: Bool) -> some View {
        let height = max(height, menuBackdropHeight)
        Group {
            if drawsBlur { SpotSoftBlur(height: height) } else { Color.clear }
        }
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
        return rect(of: sheetID)
    }

    private func rect(of id: String?) -> CGRect {
        Self.rect(of: id, in: model)
    }

    /// The rect of a sheet from its parts, or else from the shape of its rows.
    private static func rect(of id: String?, in model: SpotsModel) -> CGRect {
        if let rect = model.sheets[id ?? ""]?.partsRect { return rect }
        let shape = model.sheets[id ?? ""]?.shape
        return SpotTokens.sheetRect(rows: shape?.rows ?? 0, perLine: shape?.perLine ?? 1, hasField: shape?.hasField ?? true, setsApart: shape?.setsApart ?? false)
    }

    /// The heights of blur that the grid, each sheet as it is now and the tallest sheet ask for.
    static func blurHeights(of model: SpotsModel) -> [CGFloat] {
        let sheets = model.sheets.keys.map { blurHeight(of: rect(of: $0, in: model)) }
        return [gridHeight(of: model), blurHeight(of: SpotTokens.sheetRect(rows: 0)), SpotTokens.panelHeight] + sheets
    }

    private static func blurHeight(of sheet: CGRect) -> CGFloat {
        sheet.height + 2 * SpotTokens.halo + SpotTokens.hintBlock
    }

    private static func gridHeight(of model: SpotsModel) -> CGFloat {
        SpotTokens.backdropHeight(gridHeight: SpotGrid.height(of: model.placements))
    }

    /// The height of the sheet that the open one took the place of, so that the blur stays under both until the change
    /// settles.
    private var replacedHeight: CGFloat {
        guard let replaced = model.transition.replaced else { return 0 }
        return Self.blurHeight(of: rect(of: replaced))
    }

    /// How far the install screen pushes the grid: as far as its lower edge moves.
    private var gridPush: CGFloat {
        coversGrid ? sheetRect.maxY - SpotFieldView.rect.maxY : 0
    }

    /// Whether a sheet is out or a drop is taken, which sets the time of each fade and which hint shows.
    private var surfaceIsOut: Bool {
        sheetOpen || (model.showsFieldDrop && !(model.transition.phase == .closing && isInstall))
    }

    /// Whether the sheet is the install screen, which grows out of the field.
    private var isInstall: Bool {
        sheetID != nil && sheetID == model.fieldSheet
    }

    /// Whether the field lies in the open sheet. The install screen grows out of the field, which stays where it is.
    private var fieldIsInSheet: Bool {
        sheetOpen && !isInstall
    }

    private var contentHeight: CGFloat {
        sheetOpen ? sheetHeight : gridHeight
    }

    private var sheetHeight: CGFloat {
        Self.blurHeight(of: sheetRect)
    }

    private var gridHeight: CGFloat {
        Self.gridHeight(of: model)
    }

    /// The height of the shape that ends the cards. It follows only the grid, so that a sheet's motion swaps no image.
    private var cardHeight: CGFloat {
        max(gridHeight, menuBackdropHeight)
    }

    private var menuBackdropHeight: CGFloat {
        model.menuSession?.frame.map { $0.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock } ?? 0
    }

    /// Where the menu may lie: under the field, down to the panel's foot.
    private var menuBounds: CGRect {
        ActionMenuFrame.bounds(under: fieldIsInSheet ? SpotTokens.halo + SpotTokens.sheetFieldDrop + SpotTokens.listRowHeight + SpotTokens.rowGap : SpotTokens.gridTop)
    }

    /// The rect of the menu's glass at a scale from its corner nearest its item, as its rows scale, so that the blur behind
    /// it stays still.
    private static func rect(_ rect: CGRect, scaledBy scale: CGFloat, from corner: UnitPoint) -> CGRect {
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        return CGRect(x: rect.minX + (rect.width - size.width) * corner.x, y: rect.minY + (rect.height - size.height) * corner.y, width: size.width, height: size.height)
    }

    /// The open menu at the selected card or row, or the closing one at its last place. With no selected item it opens under
    /// the field.
    private func menuLayer(at item: SpotMenuAnchor.Item?) -> some View {
        GeometryReader { proxy in
            if let session = model.menuSession {
                let menu = session.menu
                let bounds = menuBounds
                let rect = item.map { proxy[$0.bounds] } ?? SpotFieldView.rect
                let isClosing = session.phase == .closing
                let fresh = ActionMenuFrame(item: rect, menu: menu, bounds: bounds)
                let frame = isClosing ? session.frame ?? fresh : fresh
                let shown = frame.rect(of: menu)
                let isGrown = session.isGrown
                let scale = isGrown ? 1 : SpotMotion.menuStartScale
                let corner = UnitPoint(x: frame.side == .left ? 0 : 1, y: frame.stillEdge == .top ? 0 : 1)
                ZStack(alignment: .topLeading) {
                    SpotSurface(rect: Self.rect(shown, scaledBy: scale, from: corner), radius: SpotActionMenuView.radius * scale, glass: isGrown ? 1 : 0)
                    SpotActionMenuView(menu: menu, frame: frame, isSettled: session.phase == .settled, work: { model.work(of: $0) }, onPress: { model.pressMenu(row: $0) }, onPoint: { model.point(at: .menuRow($0)) }, onSearch: { model.searchMenu($0) })
                        .scaleEffect(scale, anchor: corner)
                        .opacity(isGrown ? 1 : 0)
                        .offset(x: shown.minX, y: shown.minY)
                }
                .allowsHitTesting(!isClosing)
                .transition(.opacity)
                .onChange(of: frame, initial: true) { model.placeMenu(frame) }
            }
        }
    }

    /// Whether the install screen takes the place of the grid and the field.
    private var coversGrid: Bool {
        sheetOpen && isInstall
    }

    /// Whether the search field is drawn. A form, a sheet of parts and the install screen replace it, but a form of one choice
    /// keeps it to search its rows.
    private var showsSearchField: Bool {
        guard !coversGrid else { return false }
        if let form = model.form { return form.draft.choices != nil }
        guard sheetOpen else { return true }
        guard let sheet = model.sheets[sheetID ?? ""] else { return true }
        return sheet.kind.showsField && sheet.list.search != .off
    }
}

/// Scrolls the grid while a lifted card lies in the fade at either end of the grid's clear part, faster the deeper it lies,
/// once a frame until the drag ends. A card past the panel's bottom or over the dock scrolls nothing.
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
        guard let drag = model.drag, model.carry?.isOverDock != true else { return }
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.panelHeight - SpotsView.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: SpotTokens.gridTop + SpotGrid.height(of: model.placements) + SpotsView.gridBottom
        )
        let point = SpotTokens.gridTop + drag.centre(movedBy: model.lift.offset).y
        guard point - model.gridScroll < SpotTokens.panelHeight else { return }
        let next = window.offset(scrolling: point, from: model.gridScroll, by: SpotMotion.edgeScrollSpeed * seconds, over: SpotScrollEdges.fadeLength)
        if next != model.gridScroll { scroll.scrollTo(y: next) }
    }
}

/// The fade of the grid's cards at the ends of the scroll. It alone reads the fade, so that a scroll near an end reruns no
/// other view.
private struct GridFadeMask: ViewModifier {
    let fade: SpotScrollFade
    let height: CGFloat

    func body(content: Content) -> some View {
        content.mask(fade.edges.gradient(height: height))
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
        let top = SpotTokens.gridTop + spot.rect.minY
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.panelHeight - SpotsView.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: SpotTokens.gridTop + SpotGrid.height(of: model.placements) + SpotsView.gridBottom
        )
        let offset = window.offset(showing: top...(top + SpotTokens.height(rows: spot.size.rows)), from: scrollOffset)
        guard offset != scrollOffset else { return }
        withAnimation(SpotMotion.follow) { scroll.scrollTo(y: offset) }
    }
}
