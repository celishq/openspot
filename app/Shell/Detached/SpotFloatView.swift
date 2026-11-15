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
        .overlay { drop(on: entry) }
        .onDrop(of: [.fileURL], delegate: SpotFloatDrop(id: id, place: place, model: model, target: $dropTarget))
        .onChange(of: dropTarget) { dropWords = dropTarget.flatMap { model.dropWords(SpotGridDrop.paths, on: $0) } }
        .onChange(of: size, initial: true) { onSize(size) }
        .environment(\.spotIsShown, true)
        .environment(\.spotCards, SpotCardSource(model: model))
    }

    private func size(_ entry: SpotsModel.Entry?, _ run: SpotRun?) -> CGSize {
        guard let entry, let run else { return CGSize(width: SpotTokens.gridWidth, height: SpotTokens.rowHeight) }
        guard entry.kind.opensSheet else {
            return CGSize(width: SpotTokens.width(columns: entry.size.columns), height: SpotTokens.height(rows: entry.size.rows))
        }
        return SpotTokens.floatSize(rows: run.shape.rows, perLine: run.shape.perLine, parts: run.panel)
    }

    private func sheet(_ entry: SpotsModel.Entry, _ run: SpotRun, size: CGSize) -> some View {
        let sole = fills ? run.panel.flatMap { $0.parts.count == 1 ? $0.parts.first : nil }.flatMap { $0.isOpen ? $0 : nil } : nil
        return VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            if !fills { header(entry, run) }
            if let part = sole, let view = entry.spot.view {
                GeometryReader { area in
                    SpotCustomView(source: view, values: part.values, card: .square, room: area.size, answers: run.panel?.answered ?? 0, date: entry.spot.viewDate, views: .shared) { run.set(part, to: $0) }
                        .equatable()
                }
                .ignoresSafeArea()
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
                    onRun: { model.pick($0, of: entry, in: place) },
                    onDragOut: { model.dragOut($0, of: id) },
                    selection: { run.selection },
                    selectedPart: { run.selectedPart?.id },
                    nudge: { run.nudge },
                    viewSource: entry.spot.view,
                    viewDate: entry.spot.viewDate
                )
            } else {
                SpotRowsView(
                    list: run.list,
                    onRun: { model.pick($0, of: entry, in: place) },
                    selection: { run.selection },
                    onDragOut: { model.dragOut($0, of: id) }
                )
            }
        }
        .padding(sole == nil ? SpotTokens.padding : 0)
        .frame(width: fills ? nil : size.width, height: fills ? nil : size.height, alignment: .topLeading)
        .frame(maxWidth: fills ? .infinity : nil, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
        .modifier(FloatSurface(fills: fills))
    }

    private func header(_ entry: SpotsModel.Entry, _ run: SpotRun) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotGlyph(entry: entry)
                .modifier(SpotFileDragSource(items: run.list.shown, hasFiles: run.list.hasFiles, onDrop: { model.dragOut($0, of: id) }))
            SpotSheetTitle(title: entry.shownState.title, subtitle: entry.shownState.subtitle)
            Spacer(minLength: 0)
            SpotRoundButton(symbol: "xmark", label: "Close") { model.land(id) }
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
            chainLetter: nil,
            model: model,
            onTap: { model.pressFloatCard(id) }
        )
    }

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

private struct FloatSurface: ViewModifier {
    let fills: Bool

    func body(content: Content) -> some View {
        if fills {
            content.background {
                Color.clear
                    .spotGlass(in: RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous))
                    .ignoresSafeArea()
            }
        } else {
            content.modifier(SpotGlass())
        }
    }
}
