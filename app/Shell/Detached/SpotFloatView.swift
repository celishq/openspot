import OpenspotCore
import SwiftUI

struct SpotFloatView: View {
    let model: SpotsModel
    let id: String
    var fills = false
    let onSize: (CGSize) -> Void

    private var place: SheetPlace {
        fills ? .window : .float
    }
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
        .onDrop(of: [.fileURL], delegate: SpotFloatDrop(id: id, place: place, model: model, target: $dropTarget))
        .onChange(of: dropTarget) { dropWords = dropTarget.flatMap { model.dropWords(SpotGridDrop.paths, on: $0) } }
        .onChange(of: size, initial: true) { onSize(size) }
        .environment(\.spotIsShown, true)
        .environment(\.spotViewPlace, SpotViewPlace(model: model, place: .detached(id)))
        .environment(\.spotViewDates, entry?.spot.viewDates ?? [:])
        .id(SpotLoadedTheme.shared.layout)
    }

    private func size(_ entry: SpotsModel.Entry?, _ run: SpotRun?) -> CGSize {
        guard let entry, let run else { return CGSize(width: SpotTokens.gridWidth, height: SpotTokens.cell) }
        guard entry.kind.opensSheet else {
            return CGSize(width: SpotTokens.width(columns: entry.size.columns), height: SpotTokens.height(rows: entry.size.rows))
        }
        return SpotTokens.floatSize(rows: run.shape.rows, perLine: run.shape.perLine, parts: run.panel, setsApart: run.shape.setsApart)
    }

    private func sheet(_ entry: SpotsModel.Entry, _ run: SpotRun, size: CGSize) -> some View {
        let sole = soleView(run)
        return VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            if !fills { header(entry, run) }
            if let sole, let view = sole.node.source {
                NodeSpotView(id: sole.node.id, values: sole.node.values, source: view)
                    .environment(\.spotNode.host, FloatHost(model: model, run: run, place: place))
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
            } else {
                SpotSheetBody(
                    panel: run.panel,
                    list: run.list,
                    host: FloatHost(model: model, run: run, place: place),
                    onPick: { model.pick($0, of: entry, in: place) },
                    onDragOut: { model.dragOut($0, of: id) },
                    selection: { run.selection }
                )
            }
        }
        .padding(sole == nil ? SpotTokens.padding : 0)
        .environment(\.spotNode.variants, [fills ? .window : .float])
        .frame(width: fills ? nil : size.width, height: fills ? nil : size.height, alignment: .topLeading)
        .frame(maxWidth: fills ? .infinity : nil, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
        .modifier(FloatSurface(fills: fills, dropWords: dropWords))
    }

    private func soleView(_ run: SpotRun) -> (part: SpotPart, node: ViewNode)? {
        guard fills, let panel = run.panel, panel.parts.count == 1, let part = panel.parts.first, let node = panel.tree.node(part.id), node.source != nil else { return nil }
        return (part, node)
    }

    private func header(_ entry: SpotsModel.Entry, _ run: SpotRun) -> some View {
        HStack(spacing: SpotTokens.wordsGap) {
            SpotGlyph(entry: entry)
                .modifier(SpotFileDragSource(items: run.list.shown, hasFiles: run.list.hasFiles, onDrop: { model.dragOut($0, of: id) }))
            SpotSheetTitle(title: entry.shownState.title, subtitle: entry.shownState.subtitle)
            Spacer(minLength: 0)
            SpotRoundButton(icon: .symbol("xmark"), label: "Close") { model.land(id) }
        }
    }

    private func card(_ entry: SpotsModel.Entry) -> some View {
        SpotCardView(
            entry: entry,
            size: entry.size,
            index: -1,
            isPressed: false,
            takesDrag: dropTarget != nil,
            isDropTarget: dropTarget != nil,
            model: model,
            onTap: { model.pressFloatCard(id) }
        )
    }
}

private struct FloatSurface: ViewModifier {
    let fills: Bool
    let dropWords: String?

    func body(content: Content) -> some View {
        if fills {
            content
                .modifier(SpotWindowSurface())
                .overlay { FloatDropWords(words: dropWords, shape: ConcentricRectangle()).ignoresSafeArea() }
        } else {
            let shape = SpotRoundShape(.sheet)
            content
                .modifier(SpotGlass(shape: shape))
                .overlay { FloatDropWords(words: dropWords, shape: shape) }
        }
    }
}

private struct FloatDropWords<Edge: Shape>: View {
    let words: String?
    let shape: Edge

    var body: some View {
        if let words {
            Text(words)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.onSolid)
                .lineLimit(1)
                .padding(.horizontal, SpotTokens.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SpotTheme.accent, in: shape)
                .allowsHitTesting(false)
        }
    }
}
