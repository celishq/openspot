import OpenspotCore
import SwiftUI

/// The cards of the panel on their grid, over one blur. An open sheet pushes each other card away from its own card, shrinks
/// it, and fades it before it leaves the sheet's rect. A change of the panel that does not reach these inputs leaves the grid as it is.
struct SpotGridView: View {
    let model: SpotsModel
    let isSheetOpen: Bool
    /// The card that the open sheet grows from, and how the sheet pushes the other cards.
    let openID: String?
    let push: SheetPush?
    @Binding var scrollOffset: CGFloat
    @Binding var dropTarget: String?
    @Binding var dragged: (id: String, offset: CGSize)?

    var body: some View {
        let placements = model.placements
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        let glass = placements.map { placement in
            let entry = model.visible[placement.index]
            return SpotGridGlass.Card(
                id: entry.id,
                size: placement.size,
                offset: offset(of: placement, id: entry.id),
                scale: isSheetOpen && entry.id != openID ? SpotMotion.pushedScale : 1,
                exit: push?.exit(of: placement) ?? 1,
                isCovered: entry.id == openID || SpotCardView.isFilled(entry, takesDrag: model.takesDrag(entry.id), isDropTarget: dropTarget == entry.id)
            )
        }
        return ZStack(alignment: .topLeading) {
            SpotGridGlass(cards: glass, isSheetOpen: isSheetOpen, size: CGSize(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows)))
            ForEach(Array(zip(placements, glass)), id: \.1.id) { placement, card in
                let entry = model.visible[placement.index]
                SpotCardView(
                    entry: entry,
                    size: placement.size,
                    isSelected: placement.index == model.selected,
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    readings: entry.kind == .widget ? model.readings : [:],
                    chainLetter: model.chainLetter(of: entry),
                    showsChain: model.showsChain,
                    isHiddenFromGrid: model.isEditing && !entry.isOnGrid,
                    query: model.query,
                    model: model
                )
                .onDrop(of: [.fileURL], delegate: SpotCardDrop(id: entry.id, model: model, target: $dropTarget))
                .scaleEffect(card.scale)
                .offset(card.offset)
                .zIndex(dragged?.id == entry.id ? 1 : 0)
                .highPriorityGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .contextMenu { spotMenu(of: entry) }
                .animation(SpotMotion.cardFade(isSheetOpen: isSheetOpen, exit: card.exit)) { $0.opacity(isSheetOpen ? SpotMotion.coveredCardOpacity : 1) }
                .opacity(entry.id == openID ? 0 : 1)
            }
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows), alignment: .topLeading)
        .contentShape(Rectangle())
    }

    /// Where a card lies in the grid: its place, the push of an open sheet and the drag of Edit Spots.
    private func offset(of placement: SpotPlacement, id: String) -> CGSize {
        let place = placement.rect
        let pushed = isSheetOpen ? push?.offset(of: placement) ?? .zero : .zero
        let drag = dragged?.id == id ? dragged?.offset ?? .zero : .zero
        return CGSize(width: place.minX + pushed.width + drag.width, height: place.minY + pushed.height + drag.height)
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

    /// Moves a card in Edit Spots: it follows the pointer, and takes the place of the card it lands on.
    private func moveGesture(of entry: SpotsModel.Entry) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotsView.panelSpace))
            .onChanged { dragged = (entry.id, $0.translation) }
            .onEnded { drag in
                withAnimation(SpotMotion.edit) { dragged = nil }
                let point = CGPoint(
                    x: drag.location.x - SpotTokens.halo,
                    y: drag.location.y + scrollOffset - SpotTokens.gridTop
                )
                let column = Int(point.x / (SpotTokens.cell + SpotTokens.columnGap))
                let row = Int(point.y / (SpotTokens.rowHeight + SpotTokens.rowGap))
                let target = model.placements.first { place in
                    (place.column..<(place.column + place.size.columns)).contains(column) && (place.row..<(place.row + place.size.rows)).contains(row)
                }
                if let target { model.moveSpot(entry.id, to: target.index) }
            }
    }
}
