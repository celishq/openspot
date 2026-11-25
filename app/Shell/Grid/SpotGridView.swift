import OpenspotCore
import SwiftUI
import UniformTypeIdentifiers

struct SpotGridView: View {
    let model: SpotsModel
    let isSheetOpen: Bool
    let openID: String?
    let push: SheetPush?
    @Binding var dropTarget: String?

    struct Card: Identifiable {
        let id: String
        let size: SpotSize
        let motion: SpotPushedCard
        let isLifted: Bool
        let isHeld: Bool
        let focus: CardFocus
    }

    var body: some View {
        let placements = model.placements
        let drag = model.drag
        let frame = model.grid
        let height = model.query.isEmpty ? frame.height : SpotPlacement.height(of: placements)
        let cards = placements.map { placement in
            let entry = model.visible[placement.index]
            let isLifted = drag?.id == entry.id
            let isHeld = isLifted || model.landing == entry.id
            let shown = isLifted ? drag.map { SpotPlacement(index: placement.index, row: $0.home.row, column: $0.home.column, size: placement.size) } ?? placement : placement
            return Card(
                id: entry.id,
                size: shown.size,
                motion: motion(of: placement, at: shown.rect, id: entry.id),
                isLifted: isLifted,
                isHeld: isHeld,
                focus: model.focus(ofCard: placement.index)
            )
        }
        return ZStack(alignment: .topLeading) {
            if model.isEditing {
                GridSlots(cells: model.freeCells)
                landing(of: drag, in: placements)
                    .frame(width: frame.width, height: height)
                PinLanding(model: model)
            }
            ForEach(Array(zip(placements, cards)), id: \.1.id) { placement, card in
                let entry = model.visible[placement.index]
                SpotGridCard(
                    entry: entry,
                    size: card.size,
                    index: placement.index,
                    isHeld: card.isHeld,
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    model: model
                )
                .equatable()
                .simultaneousGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .modifier(SpotEditControls(
                    model: model,
                    id: entry.id,
                    size: card.size,
                    takesOffGrid: model.isEditing && !card.isLifted && model.takesOffGrid(entry),
                    sizes: model.isEditing && !card.isLifted ? model.sizes(of: entry) : [],
                    isResizing: model.resize?.id == entry.id,
                    isDragging: drag != nil
                ))
                .modifier(SpotLiftedCard(isLifted: card.isLifted, isSolid: card.isHeld, size: card.size))
                .modifier(SpotFocusLook(focus: card.focus))
                .modifier(SpotMenuDim(model: model, index: placement.index))
                .modifier(SpotCardPlace(motion: card.motion, lift: card.isLifted ? model.lift : nil))
                .zIndex(card.isHeld ? 1 : 0)
                .opacity(entry.id == openID ? MotionTokens.hiddenOpacity : 1)
                .animation(nil) { $0.opacity(model.carry?.entry.id == entry.id ? MotionTokens.hiddenOpacity : 1) }
                .allowsHitTesting(entry.id != openID)
            }
        }
        .frame(width: frame.width, height: height, alignment: .topLeading)
        .contentShape(Rectangle())
        .modifier(SpotPointerMove(at: { model.point(at: .grid($0)) }))
        .onDrop(of: [.fileURL], delegate: SpotGridDrop(model: model, target: $dropTarget))
    }

    private func motion(of placement: SpotPlacement, at place: CGRect, id: String) -> SpotPushedCard {
        let base = CGSize(width: place.minX, height: place.minY)
        let pushed = isSheetOpen ? push?.offset(of: placement) ?? .zero : .zero
        return SpotPushedCard(
            offset: CGSize(width: base.width + pushed.width, height: base.height + pushed.height),
            share: isSheetOpen && id != openID ? 1 : 0,
            base: base,
            push: push,
            placement: placement,
            anchor: anchor(of: placement)
        )
    }

    private func anchor(of placement: SpotPlacement) -> UnitPoint {
        guard let open = push?.open else { return .center }
        let away = placement.direction(awayFrom: open)
        return away.columns < 0 ? .trailing : away.columns > 0 ? .leading : away.rows < 0 ? .bottom : away.rows > 0 ? .top : .center
    }

    private func landing(of drag: SpotDrag?, in placements: [SpotPlacement]) -> some View {
        let placement = placements.first { $0.index == (drag?.index ?? model.selected) }
        return SpotSurfaceShape(rect: placement?.rect ?? .zero, radius: SurfaceEdge(card: placement?.size ?? .small).radius)
            .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            .opacity(drag == nil ? MotionTokens.hiddenOpacity : 1)
            .allowsHitTesting(false)
    }

    private func moveGesture(of entry: SpotsModel.Entry) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged { value in
                var still = Transaction()
                still.tracksVelocity = false
                withTransaction(still) { model.dragSpot(entry.id, by: value.translation) }
            }
            .onEnded { model.dropSpot(by: $0.translation) }
    }
}

private struct PinLanding: View {
    let model: SpotsModel

    var body: some View {
        if let rect = model.pin?.landing {
            SpotSurfaceShape(rect: rect, radius: SurfaceEdge(card: model.pin?.target?.size ?? .small).radius)
                .fill(SpotTheme.ink.opacity(SpotTheme.fill))
                .allowsHitTesting(false)
        }
    }
}

private struct GridSlots: View, Equatable {
    let cells: [GridCell]

    var body: some View {
        let shape = SpotRoundShape(SurfaceEdge(card: .small))
        ZStack(alignment: .topLeading) {
            ForEach(cells, id: \.self) { cell in
                let rect = SpotPlacement(index: 0, row: cell.row, column: cell.column, size: .small).rect
                shape
                    .fill(SpotTheme.ink.opacity(SpotTheme.track))
                    .frame(width: rect.width, height: rect.height)
                    .allowsHitTesting(false)
                    .offset(x: rect.minX, y: rect.minY)
            }
        }
    }
}
