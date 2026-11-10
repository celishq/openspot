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
    /// The parts of the sheet, once they have landed.
    let panel: SheetParts?
    /// The mask of the grid's cards, which fades a closed sheet at the ends of the scroll as the grid fades its card.
    let cardMask: LinearGradient

    var body: some View {
        SpotSheetView(
            model: model,
            entry: entry,
            cardSize: card?.placement.size ?? entry.size,
            isOpen: isOpen,
            showsFill: entry.state.on == true && !isOpen,
            rect: sheetRect,
            panel: panel,
            closeShift: isInstall ? 0 : showsArrow ? (frame?.width ?? sheetRect.width) - sheetRect.width : nil,
            cardWidth: isInstall ? SpotFieldView.rect.width : frame?.width ?? sheetRect.width
        )
        .id(entry.id)
        .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: isOpen)) { $0.opacity(card?.look == nil || isOpen ? 1 : 0) }
        .overlay(alignment: .topLeading) {
            if let look = card?.look, let frame {
                cardLook(look, size: card?.placement.size ?? look.size)
                    .frame(width: frame.width, height: frame.height)
                    .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: !isOpen)) { $0.opacity(isOpen ? 0 : 1) }
                    .allowsHitTesting(false)
            }
        }
        .background {
            SpotTheme.solid
                .animation(SpotMotion.fillFade(isOpen: isOpen)) { $0.opacity(entry.state.on == true && !isOpen ? 1 : 0) }
        }
        .modifier(SpotSheetFrame(
            rect: isOpen ? sheetRect : closedRect,
            radius: isOpen ? SpotTokens.radius : isInstall ? SpotTokens.corner(for: .strip) : SpotTokens.corner(for: card?.placement.size ?? entry.size),
            sheetRect: sheetRect,
            shift: isOpen ? .zero : shift(to: closedRect),
            showsRing: !isOpen && cardIsSelected,
            arrow: showsArrow ? AnyView(arrow) : nil,
            arrowBox: frame?.size ?? .zero
        ))
        .mask {
            ZStack {
                cardMask
                Color.black.opacity(isOpen ? 1 : 0)
            }
        }
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
        SpotCardArrow(isOnSolid: entry.state.on == true && !isOpen)
            .placed(isTall: (frame?.height ?? 0) > SpotTokens.rowHeight)
            .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: !isOpen)) { $0.opacity(isOpen ? 0 : 1) }
            .allowsHitTesting(false)
    }

    private var isInstall: Bool {
        entry.id == ShippedSpot.installID
    }

    private var cardIsSelected: Bool {
        let id = card?.look?.id ?? entry.id
        return model.placements.first { model.visible[$0.index].id == id }?.index == model.selected
    }

    /// The card's own look without its glass, since the sheet draws the glass under it: the drawing of its script, its view,
    /// or the places of a widget, as the card draws them.
    @ViewBuilder
    private func cardLook(_ card: SpotsModel.Entry, size: SpotSize) -> some View {
        let reading: (String) -> MetricReading? = card.kind == .widget ? { [model] in model.reading(of: $0) } : { _ in nil }
        if card.item == nil, let layout = card.state.face.layout(for: size) {
            SpotCardDrawing(layout: layout, face: card.state.face, card: size, reading: reading, view: { room in
                card.command.view.map { SpotCustomView(source: $0, values: card.state.values, card: size, room: room, views: SpotViews.shared) }
            }, onSlot: { _, _ in })
            .padding(SpotTokens.cardPadding(for: size, isWidget: true))
        } else if card.item == nil, card.state.face.hasView, let view = card.command.view {
            SpotCustomView(source: view, values: card.state.values, card: size, views: SpotViews.shared)
        } else if let layout = card.command.layout {
            SpotWidgetView(layout: layout, places: card.command.places, reading: reading, card: size)
                .padding(SpotTokens.cardPadding(for: size, isWidget: true))
        }
    }
}
