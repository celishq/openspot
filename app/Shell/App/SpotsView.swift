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

    private var sheetID: String? {
        model.transition.id
    }

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
            .morph(coversGrid ? 0 : 1, opacity: { SheetMorph.sheetLook(at: $0) })
            .modifier(PanelSpan(panels: model.panels))
            SpotHintLine(model: model, surfaceIsOut: surfaceIsOut, gridHeight: max(gridHeight, model.menuBackdropHeight), sheetHeight: max(sheetID == nil ? gridHeight : sheetHeight, model.menuBackdropHeight))
                .modifier(SpotShownFade(isShown: model.isShown))
            if sheetOpen, sheetID != nil {
                SpotFlowEdges(model: model, rect: sheetRect)
            }
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
                surfaceIsOut: surfaceIsOut,
                sheet: fieldSheet(on: card, at: frame)
            )
            if model.isMenuOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .modifier(PanelSpan(panels: model.panels))
                    .onTapGesture { model.closeMenu() }
            }
        }
        .onDrop(of: [.fileURL], delegate: SpotAddDrop(model: model))
        .coordinateSpace(name: Self.panelSpace)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .overlayPreferenceValue(SpotMenuAnchor.self, alignment: .topLeading) { item in
            SpotMenuLayer(model: model, item: item, fieldIsInSheet: fieldIsInSheet)
        }
        .background(alignment: .topLeading) {
            softBlur
        }
        .environment(\.spotIsShown, model.isShown)
        .environment(\.spotPanels, model.panels)
        .onChange(of: model.isShown) { _, isShown in
            if !isShown { dropTarget = nil }
        }
    }

    private var softBlur: some View {
        SpotBackdrop(model: model, gridHeight: gridHeight, sheetHeight: max(sheetHeight, replacedHeight), menuHeight: menuHeight, drawsBlur: drawsBlur)
            .environment(\.spotPanels, model.shownPanels)
            .modifier(PanelSpan(panels: model.shownPanels))
    }

    private func fieldSheet(on card: SpotSheetCard?, at frame: CGRect?) -> (morph: SheetMorph, cardRadius: CGFloat)? {
        guard let card, let frame, !isInstall else { return nil }
        return (SheetMorph(card: frame, sheet: sheetRect), SpotTokens.corner(for: card.placement.size))
    }

    private func push(from card: SpotSheetCard) -> SheetPush {
        let origin = SpotTokens.gridOrigin(scrollOffset: scrollOffset, left: model.panels.leftExtent)
        let panel = model.panels.frame
        let window = CGRect(x: panel.minX - origin.x, y: SpotTokens.halo - origin.y, width: panel.width, height: panel.height - SpotTokens.halo)
        return SheetPush(open: card.placement, sheet: sheetRect.offsetBy(dx: -origin.x, dy: -origin.y), window: window)
    }

    private var sheetRect: CGRect {
        model.formRect ?? rect(of: sheetID)
    }

    private func rect(of id: String?) -> CGRect {
        Self.rect(of: id, in: model)
    }

    private static func rect(of id: String?, in model: SpotsModel) -> CGRect {
        model.sheets[id ?? ""]?.sheetRect ?? SpotTokens.sheetRect(rows: 0)
    }

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

    private var replacedHeight: CGFloat {
        guard let replaced = model.transition.replaced else { return 0 }
        return Self.blurHeight(of: rect(of: replaced))
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

    private var contentHeight: CGFloat {
        sheetOpen ? sheetHeight : gridHeight
    }

    private var sheetHeight: CGFloat {
        Self.blurHeight(of: sheetRect)
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
        let window = ScrollWindow(
            top: SpotTokens.halo + SpotTokens.rowHeight + SpotScrollEdges.fadeLength,
            bottom: SpotTokens.panelHeight - SpotsView.gridBottom - SpotScrollEdges.fadeLength,
            viewHeight: SpotTokens.panelHeight,
            contentHeight: SpotTokens.gridTop + SpotGrid.height(of: model.placements) + SpotsView.gridBottom
        )
        let point = SpotTokens.gridTop + drag.centre(movedBy: model.lift.offset).y
        guard point - model.gridScroll < SpotTokens.panelHeight else { return }
        let next = window.offset(scrolling: point, from: model.gridScroll, by: MotionTokens.edgeScrollSpeed * seconds, over: SpotScrollEdges.fadeLength)
        if next != model.gridScroll { scroll.scrollTo(y: next) }
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
        withAnimation(SpotMotion.move) { scroll.scrollTo(y: offset) }
    }
}
