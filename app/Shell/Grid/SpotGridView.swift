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
        let height = SpotGrid.height(of: placements)
        let glass = placements.map { placement in
            let entry = model.visible[placement.index]
            let isLifted = drag?.id == entry.id
            let isHeld = isLifted || model.landing == entry.id
            let shown = isLifted ? drag.flatMap { $0.placement(at: $0.home) } ?? placement : placement
            return SpotGridGlass.Card(
                id: entry.id,
                size: shown.size,
                motion: motion(of: placement, at: shown.rect, id: entry.id),
                isCovered: entry.id == openID || SpotCardView.isFilled(entry, takesDrag: model.takesDrag(entry.id), isDropTarget: dropTarget == entry.id),
                isPressed: pressed == entry.id && !isHeld && SpotCardView.showsPress(of: entry),
                isLifted: isLifted,
                isHeld: isHeld,
                focus: model.focus(ofCard: placement.index)
            )
        }
        return ZStack(alignment: .topLeading) {
            if model.isEditing {
                SidePanelWells(panels: model.panels, height: height)
            }
            SpotGridGlass(cards: glass, pressable: openID == nil ? glass : [], size: CGSize(width: SpotTokens.width(columns: model.panels.columns), height: height), lift: model.lift)
            if model.isEditing {
                landing(of: drag, in: placements)
                    .frame(width: SpotTokens.width(columns: model.panels.columns), height: height)
                groupTitles(model.groupBands)
            }
            ForEach(Array(zip(placements, glass)), id: \.1.id) { placement, card in
                let entry = model.visible[placement.index]
                SpotCardView(
                    entry: entry,
                    size: card.size,
                    index: placement.index,
                    isPressed: pressed == entry.id && !card.isHeld,
                    takesDrag: model.takesDrag(entry.id),
                    isDropTarget: dropTarget == entry.id,
                    chainLetter: model.chainLetter(of: entry),
                    model: model
                )
                .equatable()
                .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, pressed, _ in pressed = entry.id })
                .simultaneousGesture(moveGesture(of: entry), including: model.isEditing ? .all : .subviews)
                .modifier(SpotEditControls(
                    model: model,
                    id: entry.id,
                    size: card.size,
                    turnsOff: model.isEditing && !card.isLifted && model.turnsOff(entry),
                    sizes: model.isEditing && !card.isLifted ? model.sizes(of: entry) : [],
                    isResizing: model.resize?.id == entry.id,
                    isDragging: drag != nil
                ))
                .modifier(SpotLiftedCard(isLifted: card.isLifted, isSolid: card.isHeld, size: card.size))
                .modifier(SpotFocusLook(focus: card.focus))
                .modifier(SpotCardPlace(motion: card.motion, lift: card.isLifted ? model.lift : nil))
                .zIndex(card.isHeld ? 1 : 0)
                .opacity(entry.id == openID ? 0.001 : 1)
                .animation(nil) { $0.opacity(model.carry?.entry.id == entry.id ? 0.001 : 1) }
                .allowsHitTesting(entry.id != openID)
            }
        }
        .frame(width: SpotTokens.width(columns: model.panels.columns), height: height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .plainText], delegate: SpotGridDrop(model: model, target: $dropTarget))
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

    /// The title over each group of Edit Spots, with the number of its cards, at the top of the group's band over the
    /// center panel. It shows while the grid has two groups, and moves with the cards.
    @ViewBuilder
    private func groupTitles(_ bands: SpotGroupBands?) -> some View {
        if let bands {
            let center = model.panels.firstColumn(of: .center)
            ZStack(alignment: .topLeading) {
                GroupTitle(name: "On grid", count: bands.grid)
                GroupTitle(name: "Search only", count: bands.shelf)
                    .offset(y: bands.shelfTop)
            }
            .offset(x: center == 0 ? 0 : SpotTokens.width(columns: center) + SpotTokens.columnGap)
            .frame(width: SpotTokens.width(columns: model.panels.columns), alignment: .topLeading)
            .allowsHitTesting(false)
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
    /// runs beside the card's press and tap. Its moves carry no speed, so a release lands the card from rest.
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

/// The room of each side panel in Edit Spots, as a faint well under its cards and their glass, so that a card can be dragged
/// into an empty side. It is as high as the grid, and one row at least.
private struct SidePanelWells: View, Equatable {
    let panels: GridPanels
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
        ZStack(alignment: .topLeading) {
            ForEach([GridPanel.left, .right].filter { panels[$0] }, id: \.self) { panel in
                shape
                    .fill(SpotTheme.ink.opacity(SpotTheme.track))
                    .frame(width: SpotTokens.gridWidth, height: max(height, SpotTokens.rowHeight))
                    .offset(x: CGFloat(panels.firstColumn(of: panel)) * (SpotTokens.cell + SpotTokens.columnGap))
            }
        }
        .allowsHitTesting(false)
    }
}

/// The name of a group of Edit Spots and the number of its cards.
private struct GroupTitle: View {
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(SpotType.title)
                .foregroundStyle(SpotTheme.ink)
            Text("\(count)")
                .font(SpotType.body)
                .modifier(SpotSecondaryText())
        }
        .frame(height: SpotTokens.groupTitleHeight)
        .padding(.horizontal, SpotTokens.padding)
    }
}
