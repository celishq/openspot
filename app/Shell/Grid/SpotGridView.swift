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
    @Binding var scrollOffset: CGFloat
    @Binding var dropTarget: String?
    @Binding var dragged: (id: String, offset: CGSize)?
    /// The card that the person presses.
    @GestureState private var pressed: String?

    var body: some View {
        let placements = model.placements
        let rows = placements.map { $0.row + $0.size.rows }.max() ?? 0
        let glass = placements.map { placement in
            let entry = model.visible[placement.index]
            return SpotGridGlass.Card(
                id: entry.id,
                size: placement.size,
                motion: motion(of: placement, id: entry.id),
                isCovered: entry.id == openID || SpotCardView.isFilled(entry, takesDrag: model.takesDrag(entry.id), isDropTarget: dropTarget == entry.id),
                isPressed: pressed == entry.id && SpotCardView.showsPress(of: entry)
            )
        }
        return ZStack(alignment: .topLeading) {
            SpotGridGlass(cards: glass, size: CGSize(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows)))
            ForEach(Array(zip(placements, glass)), id: \.1.id) { placement, card in
                let entry = model.visible[placement.index]
                SpotCardView(
                    entry: entry,
                    size: placement.size,
                    isSelected: { [model, index = placement.index] in model.selected == index },
                    isPressed: pressed == entry.id,
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    reading: entry.kind == .widget ? { [model] in model.reading(of: $0) } : { _ in nil },
                    chainLetter: model.chainLetter(of: entry),
                    showsChain: model.showsChain,
                    isHiddenFromGrid: model.isEditing && !entry.isOnGrid,
                    model: model
                )
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, pressed, _ in pressed = entry.id })
                .onDrop(of: [.fileURL], delegate: SpotCardDrop(id: entry.id, model: model, target: $dropTarget))
                .modifier(card.motion)
                .zIndex(dragged?.id == entry.id ? 1 : 0)
                .highPriorityGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .contextMenu { spotMenu(of: entry) }
                .opacity(entry.id == openID ? 0.001 : 1)
                .allowsHitTesting(entry.id != openID)
            }
        }
        .frame(width: SpotTokens.gridWidth, height: SpotTokens.height(rows: rows), alignment: .topLeading)
        .contentShape(Rectangle())
    }

    /// Where a card lies in the grid, from its place, the drag of Edit Spots and the push of an open sheet, and how it
    /// shrinks and fades on that push.
    private func motion(of placement: SpotPlacement, id: String) -> SpotPushedCard {
        let place = placement.rect
        let drag = dragged?.id == id ? dragged?.offset ?? .zero : .zero
        let base = CGSize(width: place.minX + drag.width, height: place.minY + drag.height)
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
