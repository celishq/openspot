import OpenspotCore
import SwiftUI

/// The sheet in the panel: its content, the look of the widget it grows from, the fill of an on card, and the frame that
/// grows it out of its card and collapses it back.
struct SpotSheetLayer: View {
    let model: SpotsModel
    let entry: SpotsModel.Entry
    /// The card it grows from, and where that card lies in the panel.
    let card: SpotSheetCard?
    let frame: CGRect?
    let sheetRect: CGRect
    /// Whether the sheet is open or on its way there.
    let isOpen: Bool
    /// The fade of the grid's cards, which fades a closed sheet at the ends of the scroll as the grid fades its card.
    let fade: SpotScrollFade
    /// The height of the surface that the cards scroll in.
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
        .modifier(SheetSlideIn(model: model))
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

    /// How far the sheet is open, which the sheet's motion carries from 0 on its card to 1.
    private var progress: Double {
        isOpen ? 1 : 0
    }

    /// How strongly the sheet's content shows: whole, unless the card draws its own look, which it takes the place of in the
    /// second half of the motion.
    private var contentOpacity: (Double) -> Double {
        if card?.look == nil { return { _ in 1 } }
        return { SheetMorph.sheetLook(at: $0) }
    }

    /// The rect that the sheet grows out of and collapses into: its card, or the field for the install screen.
    private var closedRect: CGRect {
        isInstall ? SpotFieldView.rect : frame ?? sheetRect
    }

    /// How far the sheet's content lies from its open place when it lies on a closed rect.
    private func shift(to closed: CGRect) -> CGSize {
        CGSize(width: closed.minX - sheetRect.minX, height: closed.minY - sheetRect.minY)
    }

    /// Whether the card draws an arrow. A 1x1 card shows its glyph alone, and a card with its own look draws none.
    private var showsArrow: Bool {
        entry.kind == .list && card?.look == nil && (frame?.width ?? 0) > SpotTokens.cell
    }

    /// The arrow of the card while its sheet moves. It stays in view until the close button takes its place at the edge.
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

    /// The card's own look without its glass, since the sheet draws the glass under it: the drawing of its script, its view,
    /// or the places of a widget, as the card draws them. A widget reads its places only while `readsLive`.
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

/// The card's own look over its sheet, which stays in the tree so that a close fades it in from where it lies. It tells
/// the look whether the sheet moves or lies on its card; once the sheet has settled open, where the look is clear, the look
/// reads no live values, so that a new reading draws nothing under the sheet. It alone reads the phase of the motion.
private struct MovingLook<Look: View>: View {
    let model: SpotsModel
    let id: String
    @ViewBuilder let look: (Bool) -> Look

    var body: some View {
        look(model.transition.phase != .open || model.transition.id != id)
    }
}

/// The content of the sheet while another page of it slides in: it lies `slideOffset` from its place, and fades in as it
/// comes. It alone reads the offset, so that a slide reruns no sheet.
private struct SheetSlideIn: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        let offset = model.slideOffset
        content
            .offset(x: offset)
            .opacity(1 - abs(offset) / MotionTokens.slideDistance * 0.6)
    }
}

/// The fade of a closed sheet at the ends of the scroll, as the grid fades its card. It alone reads the fade, so that a scroll
/// near an end reruns no sheet.
private struct SheetFadeMask: ViewModifier {
    let fade: SpotScrollFade
    let height: CGFloat
    let isOpen: Bool

    func body(content: Content) -> some View {
        content.mask {
            ZStack {
                fade.edges.gradient(height: height)
                Color.black.opacity(isOpen ? 1 : 0)
            }
        }
    }
}
