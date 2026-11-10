import OpenspotCore
import SwiftUI

/// The cards of the panel on their grid, over one blur. An open sheet pushes each other card away from its own card, and
/// fades and shrinks it as it crosses the window's edge. A change of the panel that does not reach these inputs leaves the grid as it is.
struct SpotGridView: View {
    let model: SpotsModel
    let isSheetOpen: Bool
    /// The card that the open sheet grows from, and how the sheet pushes the other cards.
    let openID: String?
    let push: SheetPush?
    @Binding var dropTarget: String?
    /// The card that the person presses.
    @GestureState private var pressed: String?

    var body: some View {
        let placements = model.placements
        let drag = model.drag
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        let glass = placements.map { placement in
            let entry = model.visible[placement.index]
            let isLifted = drag?.id == entry.id
            let shown = isLifted ? drag.flatMap { $0.placement(at: $0.start) } ?? placement : placement
            return SpotGridGlass.Card(
                id: entry.id,
                size: shown.size,
                motion: motion(of: placement, at: shown.rect, id: entry.id),
                isCovered: entry.id == openID || SpotCardView.isFilled(entry, takesDrag: model.takesDrag(entry.id), isDropTarget: dropTarget == entry.id),
                isPressed: pressed == entry.id && !isLifted && SpotCardView.showsPress(of: entry),
                isLifted: isLifted
            )
        }
        return ZStack(alignment: .topLeading) {
            SpotGridGlass(cards: glass, pressable: openID == nil ? glass : [], size: CGSize(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows)), lift: model.lift)
            if model.isEditing {
                landing(of: drag, in: placements)
                    .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows))
            }
            ForEach(Array(zip(placements, glass)), id: \.1.id) { placement, card in
                let entry = model.visible[placement.index]
                SpotCardView(
                    entry: entry,
                    size: card.size,
                    index: placement.index,
                    isPressed: pressed == entry.id && !card.isLifted,
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    chainLetter: model.chainLetter(of: entry),
                    showsChain: model.showsChain,
                    isHiddenFromGrid: model.isEditing && !entry.isOnGrid,
                    model: model
                )
                .equatable()
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, pressed, _ in pressed = entry.id })
                .simultaneousGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .overlay(alignment: .topLeading) {
                    if model.isEditing, entry.item == nil, !card.isLifted {
                        SpotHideButton(model: model, id: entry.id, isHidden: !entry.isOnGrid, size: card.size)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if model.isEditing, !card.isLifted, model.sizes(of: entry).count > 1 {
                        SpotResizeHandle(size: card.size)
                            .gesture(resizeGesture(of: entry))
                    }
                }
                .modifier(SpotLiftedCard(isLifted: card.isLifted, size: card.size))
                .modifier(card.motion)
                .modifier(SpotLiftOffset(lift: card.isLifted ? model.lift : nil))
                .zIndex(card.isLifted ? 1 : 0)
                .contextMenu { spotMenu(of: entry) }
                .opacity(entry.id == openID ? 0.001 : 1)
                .allowsHitTesting(entry.id != openID)
            }
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows), alignment: .topLeading)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], delegate: SpotGridDrop(model: model, target: $dropTarget))
    }

    /// Where a card lies in the grid, from its place, or the place a lifted card started at, and the push of an open sheet,
    /// and how it shrinks and fades on that push.
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

    /// The side of a card that faces the open sheet, which stays in step with the sheet's edge as the card shrinks.
    private func anchor(of placement: SpotPlacement) -> UnitPoint {
        guard let push else { return .center }
        let away = placement.direction(awayFrom: push.open)
        return away.columns < 0 ? .trailing : away.columns > 0 ? .leading : away.rows < 0 ? .bottom : away.rows > 0 ? .top : .center
    }

    /// What a card offers on a right click: its preferred size, its place on the grid and Edit Spots.
    @ViewBuilder
    private func spotMenu(of entry: SpotsModel.Entry) -> some View {
        let sizes = model.sizes(of: entry)
        if !sizes.isEmpty {
            Picker("Size", selection: Binding(get: { entry.size.name }, set: { name in
                if let size = SpotSize(name: name) { model.prefer(size, for: entry.id) }
            })) {
                ForEach(sizes.map(\.name), id: \.self) { Text($0.capitalized).tag($0) }
            }
        }
        if entry.item == nil {
            Button(entry.isOnGrid ? "Hide from Grid" : "Show on Grid") { model.setOnGrid(!entry.isOnGrid, for: entry.id) }
            Button("Edit Spots") { model.beginEditing() }
        }
    }

    /// The faint shape where a release puts the lifted card. With no card lifted it lies under the selected card, unseen, so
    /// that it shows in place when a drag starts.
    private func landing(of drag: SpotDrag?, in placements: [SpotPlacement]) -> some View {
        let placement = placements.first { $0.index == (drag?.place ?? model.selected) }
        return SpotSurfaceShape(rect: placement?.rect ?? .zero, radius: SpotTokens.corner(for: placement?.size ?? .small))
            .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            .opacity(drag == nil ? 0.001 : 1)
            .allowsHitTesting(false)
    }

    /// Moves a card in Edit Spots: it follows the pointer, the other cards make room, and a release puts it in that room. It
    /// runs beside the card's press and tap.
    private func moveGesture(of entry: SpotsModel.Entry) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged { model.dragSpot(entry.id, by: $0.translation) }
            .onEnded { model.dropSpot(by: $0.translation) }
    }

    /// Resizes a card by its corner handle: the card snaps to the nearest size, and the other cards make room.
    private func resizeGesture(of entry: SpotsModel.Entry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged { model.resizeSpot(entry.id, by: $0.translation) }
            .onEnded { _ in model.dropResize() }
    }
}
