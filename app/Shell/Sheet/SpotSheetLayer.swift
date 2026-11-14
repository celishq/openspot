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

    var body: some View {
        SpotSheetView(
            model: model,
            entry: entry,
            cardSize: card?.placement.size ?? entry.size,
            isOpen: isOpen,
            showsFill: entry.isActive,
            rect: sheetRect,
            closeShift: isInstall ? 0 : showsArrow ? (frame?.width ?? sheetRect.width) - sheetRect.width : nil,
            cardWidth: isInstall ? SpotFieldView.rect.width : frame?.width ?? sheetRect.width,
            hasCardLook: card?.look != nil,
            morph: SheetMorph(card: closedRect, sheet: sheetRect)
        )
        .id(entry.id)
        .modifier(FlowPushIn(model: model))
        .morph(progress, opacity: contentOpacity)
        .overlay(alignment: .topLeading) {
            if let look = card?.look, let frame {
                MovingLook(model: model, id: entry.id) { isMoving in cardLook(look, size: card?.placement.size ?? look.size, readsLive: isMoving) }
                    .frame(width: frame.width, height: frame.height)
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
                    .allowsHitTesting(false)
            }
        }
        .background {
            if entry.isActive {
                SpotTheme.solid
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
            }
        }
        .modifier(SpotSheetFrame(
            rect: isOpen ? sheetRect : closedRect,
            radius: isOpen ? SpotTokens.radius : isInstall ? SpotTokens.corner(for: .strip) : SpotTokens.corner(for: card?.placement.size ?? entry.size),
            sheetRect: sheetRect,
            shift: isOpen ? .zero : shift(to: closedRect),
            isSelected: { [model, id = card?.look?.id ?? entry.id] in
                model.placements.first { model.visible[$0.index].id == id }?.index == model.selected
            },
            progress: progress,
            arrow: showsArrow ? AnyView(arrow) : nil,
            arrowBox: frame?.size ?? .zero
        ))
        .modifier(SheetFadeMask(fade: fade, height: fadeHeight, isOpen: isOpen))
    }

    private var progress: Double {
        isOpen ? 1 : 0
    }

    private var contentOpacity: (Double) -> Double {
        if card?.look == nil { return { _ in 1 } }
        return { SheetMorph.sheetLook(at: $0) }
    }

    private var closedRect: CGRect {
        isInstall ? SpotFieldView.rect : frame ?? sheetRect
    }

    private func shift(to closed: CGRect) -> CGSize {
        CGSize(width: closed.minX - sheetRect.minX, height: closed.minY - sheetRect.minY)
    }

    private var showsArrow: Bool {
        entry.kind == .list && card?.look == nil && (frame?.width ?? 0) > SpotTokens.cell
    }

    private var arrow: some View {
        SpotCardArrow()
            .placed(isTall: (frame?.height ?? 0) > SpotTokens.rowHeight)
            .environment(\.spotIsOnSolid, entry.isActive)
            .morph(progress, opacity: SheetMorph.cardLook(at:))
            .allowsHitTesting(false)
    }

    private var isInstall: Bool {
        entry.spot.growsFromField
    }

    @ViewBuilder
    private func cardLook(_ card: SpotsModel.Entry, size: SpotSize, readsLive: Bool) -> some View {
        let reading: (String) -> MetricReading? = card.kind == .widget && readsLive ? { [model] in model.reading(of: $0) } : { _ in nil }
        if card.item == nil, let layout = card.state.face.layout(for: size) {
            SpotCardDrawing(layout: layout, face: card.state.face, card: size, view: { room in
                card.spot.view.map { SpotCustomView(source: $0, values: card.state.values, card: size, room: room, views: SpotViews.shared) }
            }, onSlot: { _, _ in })
            .padding(SpotTokens.cardPadding(for: size, isWidget: true))
        } else if card.item == nil, card.state.face.hasView, let view = card.spot.view {
            SpotCustomView(source: view, values: card.state.values, card: size, views: SpotViews.shared)
        } else if let layout = card.spot.layout {
            SpotWidgetView(layout: layout, places: card.spot.places, reading: reading, card: size)
                .padding(SpotTokens.cardPadding(for: size, isWidget: true))
        }
    }
}

private struct MovingLook<Look: View>: View {
    let model: SpotsModel
    let id: String
    @ViewBuilder let look: (Bool) -> Look

    var body: some View {
        look(model.transition.phase != .open || model.transition.id != id)
    }
}

private struct FlowPushIn: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        let offset = model.pushOffset
        content
            .offset(x: offset)
            .opacity(1 - abs(offset) / MotionTokens.pushDistance)
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
                Color.black.opacity(isOpen ? 1 : 0)
            }
            .padding(.leading, panels.leftExtent)
            .offset(x: panels.frame.minX)
        }
    }
}
