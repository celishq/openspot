import OpenspotCore
import SwiftUI
import UniformTypeIdentifiers

struct SpotGridView: View {
    let model: SpotsModel
    let isSheetOpen: Bool
    let openID: String?
    let push: SheetPush?
    @Binding var dropTarget: String?
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
        .onDrop(of: [.fileURL, .storeCard], delegate: SpotGridDrop(model: model, target: $dropTarget))
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
        guard let push else { return .center }
        let away = placement.direction(awayFrom: push.open)
        return away.columns < 0 ? .trailing : away.columns > 0 ? .leading : away.rows < 0 ? .bottom : away.rows > 0 ? .top : .center
    }

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

    private func landing(of drag: SpotDrag?, in placements: [SpotPlacement]) -> some View {
        let placement = placements.first { $0.index == (drag?.place ?? model.selected) }
        return SpotSurfaceShape(rect: placement?.rect ?? .zero, radius: SpotTokens.corner(for: placement?.size ?? .small))
            .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            .opacity(drag == nil ? 0.001 : 1)
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
