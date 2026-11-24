import OpenspotCore
import SwiftUI

struct SpotSheetLayer: View {
    let model: SpotsModel
    let entry: SpotsModel.Entry
    let card: SpotSheetCard?
    let frame: CGRect?
    let sheetRect: CGRect
    let isOpen: Bool
    let fade: SpotScrollFade
    let fadeHeight: CGFloat
    var showsField = false

    var body: some View {
        let step = step
        SpotSheetView(
            model: model,
            entry: entry,
            cardSize: card?.placement.size ?? .strip,
            isOpen: isOpen,
            showsFill: entry.isActive,
            rect: sheetRect,
            closeShift: isInstall ? 0 : showsArrow ? (frame?.width ?? sheetRect.width) - sheetRect.width : nil,
            cardWidth: isInstall ? SpotFieldView.rect.width : frame?.width ?? SpotFieldView.rect.width,
            hasCardLook: card?.look != nil,
            morph: morph,
            cardState: card?.state,
            held: closingPage
        )
        .environment(\.spotIsHeld, closingPage != nil)
        .id(entry.id)
        .morph(progress, opacity: contentOpacity)
        .overlay(alignment: .topLeading) {
            if let look = card?.look, let frame {
                cardLook(look, size: card?.placement.size ?? look.size)
                    .frame(width: frame.width, height: frame.height)
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
                    .allowsHitTesting(false)
            }
        }
        .background {
            if entry.isActive {
                SpotTheme.solid
                    .morph(progress, opacity: { [morph] in morph.sourceLook(at: $0) })
            }
        }
        .modifier(SpotSheetFrame(
            rect: isOpen ? step.fit ?? sheetRect : closedRect,
            radius: isOpen ? SpotTokens.cardRadius : isInstall || card == nil ? SurfaceEdge(card: .strip).radius : SurfaceEdge(card: card?.placement.size ?? entry.size).radius,
            sheetRect: sheetRect,
            shift: isOpen ? .zero : shift(to: closedRect),
            isSelected: { [model, id = card?.look?.id ?? entry.id] in
                model.placements.first { model.visible[$0.index].id == id }?.index == model.selected
            },
            progress: progress,
            arrow: showsArrow ? AnyView(arrow) : nil,
            arrowBox: frame?.size ?? .zero,
            step: step
        ))
        .modifier(SheetFadeMask(fade: fade, height: fadeHeight, isOpen: isOpen))
    }

    private var step: SheetStep {
        guard isOpen else { return SheetStep() }
        let edges = model.flowEdges
        guard let from = edges.from else { return SheetStep(marks: edges.edges) }
        let room = edges.room(around: sheetRect)
        return SheetStep(
            marks: edges.edges,
            room: room,
            fit: edges.sheetStart?.rect(around: from) ?? sheetRect,
            leaving: leaving(edges, around: room),
            field: showsField ? AnyView(SpotFieldLook(query: model.searchText, title: entry.state.title, top: model.sheets[entry.id]?.top ?? .plain)) : nil,
            glass: edges.sheetStart == nil || edges.sheetStartsOnMark ? 1 : MotionTokens.hiddenOpacity
        )
    }

    private func leaving(_ edges: FlowEdges, around room: CGRect) -> SheetStep.Leaving? {
        guard let page = edges.leavingPage, let edge = edges.leavingEdge, let held = model.sheetEntry(page.spot) else { return nil }
        let look = ZStack(alignment: .topLeading) {
            SpotSheetView(
                model: model,
                entry: held,
                cardSize: held.size,
                isOpen: true,
                showsFill: held.isActive,
                rect: page.rect,
                closeShift: nil,
                cardWidth: page.rect.width,
                morph: SheetMorph(card: page.rect, sheet: page.rect),
                held: page
            )
            .frame(width: page.rect.width, height: page.rect.height, alignment: .topLeading)
            .offset(x: page.rect.minX, y: page.rect.minY)
            if page.showsField {
                SpotFieldLook(query: page.query, title: page.fieldTitle, top: page.top)
            }
        }
        .environment(\.spotIsHeld, true)
        return SheetStep.Leaving(look: AnyView(look), from: page.rect, rect: edge.rect(around: room))
    }

    private var closingPage: SheetPage? {
        isOpen ? nil : model.closingPage.flatMap { $0.spot == entry.id ? $0 : nil }
    }

    private var progress: Double {
        isOpen ? 1 : 0
    }

    private var contentOpacity: (Double) -> Double {
        if card?.look == nil { return { _ in 1 } }
        return { SheetMorph.contentLook(at: $0) }
    }

    private var morph: SheetMorph {
        SheetMorph(card: closedRect, sheet: sheetRect, source: card == nil ? .field : .card)
    }

    private var closedRect: CGRect {
        isInstall ? SpotFieldView.rect : frame ?? SpotFieldView.rect
    }

    private func shift(to closed: CGRect) -> CGSize {
        CGSize(width: closed.minX - sheetRect.minX, height: closed.minY - sheetRect.minY)
    }

    private var showsArrow: Bool {
        (card?.kind ?? entry.kind) == .list && card?.look == nil && (frame?.width ?? 0) > SpotTokens.cell
    }

    private var arrow: some View {
        SpotCardArrow()
            .placed(isTall: (frame?.height ?? 0) > SpotTokens.cell)
            .environment(\.spotIsOnSolid, entry.isActive)
            .morph(progress, opacity: SheetMorph.cardLook(at:))
            .allowsHitTesting(false)
    }

    private var isInstall: Bool {
        entry.spot.growsFromField
    }

    @ViewBuilder
    private func cardLook(_ card: SpotsModel.Entry, size: SpotSize) -> some View {
        if card.item == nil, card.state.face.draws(on: size) {
            CardTreeView(face: card.state.face, size: size)
                .padding(SpotTokens.cardPadding(for: size, isDrawn: true))
        }
    }
}

private struct SheetFadeMask: ViewModifier {
    let fade: SpotScrollFade
    let height: CGFloat
    let isOpen: Bool
    @Environment(\.spotPanels) private var panels

    func body(content: Content) -> some View {
        content.mask {
            ZStack {
                fade.edges.gradient(height: height)
                isOpen ? SpotTheme.mask : Color.clear
            }
            .padding(.leading, panels.leftExtent)
            .offset(x: panels.frame.minX)
        }
    }
}
