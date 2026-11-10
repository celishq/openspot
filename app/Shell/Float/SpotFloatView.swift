import OpenspotCore
import SwiftUI

/// The content of a float: the spot's sheet with its header, its rows or parts and a close button, or its card when it has
/// no sheet. It tells its window the size that it needs.
struct SpotFloatView: View {
    let model: SpotsModel
    let id: String
    let onSize: (CGSize) -> Void
    @State private var dropTarget: String?

    private var entry: SpotsModel.Entry? {
        model.cards.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let entry, let run = model.sheets[id] {
                if entry.kind.opensSheet {
                    sheet(entry, run)
                } else {
                    card(entry)
                }
            }
        }
        .overlay { drop }
        .onDrop(of: [.fileURL], delegate: SpotCardDrop(id: id, model: model, target: $dropTarget, place: .float))
        .onChange(of: size, initial: true) { onSize(size) }
        .environment(\.spotIsShown, true)
    }

    /// The size of the sheet or the card.
    private var size: CGSize {
        guard let entry, let run = model.sheets[id] else { return CGSize(width: SpotTokens.gridWidth, height: SpotTokens.rowHeight) }
        guard entry.kind.opensSheet else {
            return CGSize(width: SpotTokens.width(columns: entry.size.columns), height: SpotTokens.height(rows: entry.size.rows))
        }
        return SpotTokens.floatSize(rows: run.shape.rows, perLine: run.shape.perLine, parts: run.panel)
    }

    private func sheet(_ entry: SpotsModel.Entry, _ run: SpotRun) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header(entry)
            if let parts = run.panel {
                SheetPartsView(
                    panel: parts,
                    work: { run.work(of: $0) },
                    onSet: { run.set($0, to: $1) },
                    onPress: { part in
                        run.press(part)
                        if part.closes { model.land(id) }
                    },
                    list: run.list,
                    onRun: { model.pick($0, of: entry, in: .float) },
                    onSlot: { model.slot($1, of: $0, in: id, to: $2) },
                    onDragOut: { model.dragOut($0, of: id) },
                    selection: { run.selection },
                    nudge: { run.nudge },
                    customView: { room in
                        entry.command.view.map { SpotCustomView(source: $0, values: entry.state.values, card: entry.state.size ?? .square, room: room, views: SpotViews.shared) }
                    }
                )
                .task(id: parts.parts.contains { $0.kind == "view" } ? entry.command.view : nil) {
                    if let view = entry.command.view, parts.parts.contains(where: { $0.kind == "view" }) { await SpotViews.shared.load(view) }
                }
            } else {
                SpotRowsView(
                    list: run.list,
                    onRun: { model.pick($0, of: entry, in: .float) },
                    selection: { run.selection },
                    onSlot: { model.slot($1, of: $0, in: id, to: $2) },
                    onDragOut: { model.dragOut($0, of: id) }
                )
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(SpotGlass())
    }

    private func header(_ entry: SpotsModel.Entry) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotGlyph(entry: entry)
                .modifier(SpotFileDragSource(items: model.sheets[id]?.list.shown ?? [], onDrop: { model.dragOut($0, of: id) }))
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(entry.shownState.title)
                    .font(SpotType.title)
                    .frame(height: SpotType.titleLine)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                if let subtitle = entry.shownState.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .frame(height: SpotType.detailLine)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            SpotRoundButton(symbol: "xmark", label: "Close") { model.land(id) }
        }
    }

    private func card(_ entry: SpotsModel.Entry) -> some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.corner(for: entry.size), style: .continuous)
        return SpotCardView(
            entry: entry,
            size: entry.size,
            index: -1,
            isPressed: false,
            takesDrag: dropTarget != nil,
            isDropTarget: dropTarget != nil,
            chainLetter: nil,
            showsChain: false,
            isHiddenFromGrid: false,
            model: model,
            onTap: { model.pressFloatCard(id) }
        )
        .background { SpotBlur(radius: SpotTheme.blur).overlay(SpotTheme.glass).clipShape(shape) }
    }

    /// What a drop adds, over the float, only while a drag that it takes lies over it (W9).
    @ViewBuilder
    private var drop: some View {
        if dropTarget != nil, entry?.kind.opensSheet == true, let dropWords = model.dropWords(SpotCardDrop.paths, on: id) {
            Text(dropWords)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.onSolid)
                .lineLimit(1)
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.accent, in: RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous))
                .allowsHitTesting(false)
        }
    }
}
