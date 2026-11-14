import OpenspotCore
import SwiftUI

/// The content of a float: the spot's sheet with its header, its rows or parts and a close button, or its card when it has
/// no sheet. It tells its window the size that it needs. In a window of its own it fills the window, whose title bar holds
/// the name and the close button.
struct SpotFloatView: View {
    let model: SpotsModel
    let id: String
    var fills = false
    let onSize: (CGSize) -> Void
    @State private var dropTarget: String?
    @State private var dropWords: String?

    var body: some View {
        let entry = model.card(id: id)
        let run = model.sheets[id]
        let size = size(entry, run)
        Group {
            if let entry, let run {
                if entry.kind.opensSheet {
                    sheet(entry, run, size: size)
                } else {
                    card(entry)
                }
            }
        }
        .overlay { drop(on: entry) }
        .onDrop(of: [.fileURL], delegate: SpotFloatDrop(id: id, model: model, target: $dropTarget))
        .onChange(of: dropTarget) { dropWords = dropTarget.flatMap { model.dropWords(SpotGridDrop.paths, on: $0) } }
        .onChange(of: size, initial: true) { onSize(size) }
        .environment(\.spotIsShown, true)
        .environment(\.spotCards, SpotCardSource(model: model))
    }

    /// The size of the sheet or the card.
    private func size(_ entry: SpotsModel.Entry?, _ run: SpotRun?) -> CGSize {
        guard let entry, let run else { return CGSize(width: SpotTokens.gridWidth, height: SpotTokens.rowHeight) }
        guard entry.kind.opensSheet else {
            return CGSize(width: SpotTokens.width(columns: entry.size.columns), height: SpotTokens.height(rows: entry.size.rows))
        }
        return SpotTokens.floatSize(rows: run.shape.rows, perLine: run.shape.perLine, parts: run.panel)
    }

    private func sheet(_ entry: SpotsModel.Entry, _ run: SpotRun, size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            if !fills { header(entry, run) }
            if fills, let parts = run.panel, parts.parts.count == 1, let part = parts.parts.first, part.kind == "view", let view = entry.spot.view {
                GeometryReader { area in
                    SpotCustomView(source: view, values: part.values, card: .square, room: area.size, views: .shared) { run.set(part, to: $0) }
                        .equatable()
                }
                .task(id: view) { await SpotViews.shared.load(view) }
            } else if let parts = run.panel {
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
                    onDragOut: { model.dragOut($0, of: id) },
                    selection: { run.selection },
                    selectedPart: { run.selectedPart?.id },
                    nudge: { run.nudge },
                    viewSource: entry.spot.view
                )
                .task(id: parts.parts.contains { $0.kind == "view" } ? entry.spot.view : nil) {
                    if let view = entry.spot.view, parts.parts.contains(where: { $0.kind == "view" }) { await SpotViews.shared.load(view) }
                }
            } else {
                SpotRowsView(
                    list: run.list,
                    onRun: { model.pick($0, of: entry, in: .float) },
                    selection: { run.selection },
                    onDragOut: { model.dragOut($0, of: id) }
                )
            }
        }
        .padding(SpotTokens.padding)
        .frame(width: fills ? nil : size.width, height: fills ? nil : size.height, alignment: .topLeading)
        .frame(maxWidth: fills ? .infinity : nil, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
        .modifier(FloatSurface(fills: fills))
    }

    private func header(_ entry: SpotsModel.Entry, _ run: SpotRun) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotGlyph(entry: entry)
                .modifier(SpotFileDragSource(items: run.list.shown, hasFiles: run.list.hasFiles, onDrop: { model.dragOut($0, of: id) }))
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
            model: model,
            onTap: { model.pressFloatCard(id) }
        )
        .background { SpotBlur(radius: SpotTheme.blur).overlay(SpotTheme.glass).clipShape(shape) }
    }

    /// What a drop adds, over the float, only while a drag that it takes lies over it (W9).
    @ViewBuilder
    private func drop(on entry: SpotsModel.Entry?) -> some View {
        if let dropWords, entry?.kind.opensSheet == true {
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

/// The glass of a float, which a window of its own leaves out: the window draws its own background.
private struct FloatSurface: ViewModifier {
    let fills: Bool

    func body(content: Content) -> some View {
        if fills { content } else { content.modifier(SpotGlass()) }
    }
}
