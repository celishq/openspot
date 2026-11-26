import SwiftUI
import OpenspotCore
import UniformTypeIdentifiers

struct SpotsView: View {
    let model: SpotsModel
    @State private var fade = SpotScrollFade()
    @State private var scroll = ScrollPosition()
    @State private var dropTarget: String?

    private var sheetID: String? {
        model.transition.id
    }

    private var sheetOpen: Bool {
        model.transition.isOpen
    }

    static let panelSpace = "panel"
    fileprivate static var gridBottom: CGFloat { SpotTokens.halo + SpotTokens.hintBlock }

    var body: some View {
        let card = SpotSheetCard.of(sheetID, in: model).flatMap { $0.isSeen(scrollOffset: model.cardScroll, gridHeight: gridHeight) ? $0 : nil }
        let frame = card?.frame(scrollOffset: model.cardScroll)
        let motion = SheetMotion(morph: morph(of: card, at: frame), progress: sheetOpen ? 1 : 0)
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                SpotGridView(
                    model: model,
                    isSheetOpen: sheetOpen,
                    openID: card?.id,
                    push: push(from: card),
                    dropTarget: $dropTarget
                )
                    .offset(y: gridPush)
                    .padding(.horizontal, SpotTokens.halo)
                    .padding(.top, SpotTokens.gridTop)
                    .padding(.bottom, Self.gridBottom)
            }
            .scrollDisabled(model.isGridFixed)
            .scrollPosition($scroll)
            .modifier(GridSelectionFollow(model: model, scroll: $scroll))
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
                model.gridScrolled(to: offset)
            })
            .modifier(SpotScrollEdgeTracker(edges: Binding(get: { fade.edges }, set: { fade.edges = $0 })))
            .modifier(GridFadeMask(fade: fade, height: cardHeight))
            .fade(coversGrid ? 0 : 1) { SheetMorph.sheetOpacity(at: $0) }
            .modifier(PanelSpan(grid: model.grid))
            SpotHintLine(model: model, surfaceIsOut: surfaceIsOut, motion: motion)
                .modifier(SpotShownFade(isShown: model.isShown))
                .id(model.grid.columns)
            field(card: card, motion: motion, isGlass: true)
            if sheetOpen, sheetID != nil {
                SpotFlowEdges(model: model, rect: sheetRect)
            }
            if let entry = model.sheetEntry(sheetID) {
                SpotSheetLayer(
                    model: model,
                    entry: entry,
                    card: card,
                    frame: frame,
                    sheetRect: sheetRect,
                    isOpen: sheetOpen,
                    fade: fade,
                    fadeHeight: cardHeight,
                    showsField: showsSearchField && fieldIsInSheet
                )
                .id(model.grid.columns)
            }
            field(card: card, motion: motion, isGlass: false)
            if model.isMenuOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .modifier(PanelSpan(grid: model.grid))
                    .onTapGesture { model.closeMenu() }
            }
        }
        .onDrop(of: [.fileURL], delegate: SpotAddDrop(model: model))
        .contentShape(Rectangle().inset(by: model.isArranging ? SpotTokens.halo - SpotTokens.cornerMark : 0))
        .coordinateSpace(name: Self.panelSpace)
        .allowsHitTesting(!model.transition.isMoving)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .overlayPreferenceValue(SpotMenuAnchor.self, alignment: .topLeading) { item in
            SpotMenuLayer(model: model, item: item, fieldIsInSheet: fieldIsInSheet)
        }
        .background(alignment: .topLeading) { SpotBackdrop(model: model, motion: motion) }
        .environment(\.spotIsShown, model.isShown)
        .environment(\.spotViewPlace, SpotViewPlace(model: model))
        .environment(\.spotGrid, model.grid)
        .onChange(of: model.isShown) { _, isShown in
            if !isShown { dropTarget = nil }
        }
    }

    private func field(card: SpotSheetCard?, motion: SheetMotion, isGlass: Bool) -> some View {
        SpotFieldView(
            model: model,
            isOpen: sheetOpen,
            isInSheet: fieldIsInSheet,
            isInstall: isInstall,
            showsField: showsSearchField,
            surfaceIsOut: surfaceIsOut,
            sheet: fieldSheet(on: card, motion: motion),
            isGlass: isGlass
        )
        .modifier(FlowFieldHide(model: model, isInSheet: fieldIsInSheet))
        .id(model.grid.columns)
    }

    private func fieldSheet(on card: SpotSheetCard?, motion: SheetMotion) -> (morph: SheetMorph, cardRadius: CGFloat)? {
        guard !isInstall, let morph = motion.morph else { return nil }
        return (morph, SurfaceEdge(card: card?.placement.size ?? .strip).radius)
    }

    private func morph(of card: SpotSheetCard?, at frame: CGRect?) -> SheetMorph? {
        guard sheetID != nil else { return nil }
        guard card != nil, let frame else { return SheetMorph(card: SpotTokens.fieldRect(room: model.detailsRoom), sheet: sheetRect, source: .field) }
        return SheetMorph(card: frame, sheet: sheetRect)
    }

    private func push(from card: SpotSheetCard?) -> SheetPush? {
        guard sheetID != nil, !isInstall else { return nil }
        let origin = SpotTokens.gridOrigin(scrollOffset: model.cardScroll)
        let panel = SpotTokens.panelFrame
        let window = CGRect(x: panel.minX - origin.x, y: SpotTokens.halo - origin.y, width: panel.width, height: panel.height - SpotTokens.halo)
        return SheetPush(open: card?.placement, sheet: sheetRect.offsetBy(dx: -origin.x, dy: -origin.y), window: window, foot: model.pushFoot.moved(by: -SpotTokens.halo - origin.y))
    }

    private var sheetRect: CGRect {
        model.formRect ?? rect(of: sheetID)
    }

    private func rect(of id: String?) -> CGRect {
        model.sheets[id ?? ""]?.sheetRect ?? SpotTokens.sheetRect(rows: 0)
    }

    private var gridPush: CGFloat {
        coversGrid ? sheetRect.maxY - SpotFieldView.rect.maxY : 0
    }

    private var surfaceIsOut: Bool {
        sheetOpen || (model.showsFieldDrop && !(model.transition.phase == .closing && isInstall))
    }

    private var isInstall: Bool {
        sheetID != nil && sheetID == model.fieldSheet
    }

    private var fieldIsInSheet: Bool {
        sheetOpen && !isInstall
    }

    private var gridHeight: CGFloat {
        model.gridHeight
    }

    private var cardHeight: CGFloat {
        max(gridHeight, menuHeight)
    }

    private var menuHeight: CGFloat {
        model.menuFrame.map { $0.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock } ?? 0
    }

    private var coversGrid: Bool {
        sheetOpen && isInstall
    }

    private var showsSearchField: Bool {
        guard !coversGrid else { return false }
        if model.formRect != nil { return model.formHasChoices }
        guard sheetOpen else { return true }
        return model.sheets[sheetID ?? ""]?.showsField ?? true
    }
}

private struct FlowFieldHide: ViewModifier {
    let model: SpotsModel
    let isInSheet: Bool

    func body(content: Content) -> some View {
        content.opacity(isInSheet && model.flowEdges.coming != nil ? MotionTokens.hiddenOpacity : 1)
    }
}

private struct GridFadeMask: ViewModifier {
    let fade: SpotScrollFade
    let height: CGFloat

    func body(content: Content) -> some View {
        content.mask(fade.edges.gradient(height: height))
    }
}

private struct GridSelectionFollow: ViewModifier {
    let model: SpotsModel
    @Binding var scroll: ScrollPosition

    func body(content: Content) -> some View {
        content.onChange(of: model.selected) { show() }
    }

    private func show() {
        let placements = model.placements
        guard model.openSheetID == nil, model.drag == nil, let spot = placements.first(where: { $0.index == model.selected }) else { return }
        let top = SpotTokens.gridTop + spot.rect.minY
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.cell + SpotTokens.scrollFadeLength,
            bottom: SpotTokens.panelHeight - SpotsView.gridBottom - SpotTokens.scrollFadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: SpotTokens.gridTop + SpotPlacement.height(of: model.placements) + SpotsView.gridBottom
        )
        let offset = window.offset(showing: top...(top + SpotTokens.height(rows: spot.size.rows)), from: model.gridScroll)
        guard offset != model.gridScroll else { return }
        withAnimation(SpotMotion.move) { scroll.scrollTo(y: offset) }
    }
}
