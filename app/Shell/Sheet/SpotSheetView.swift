import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let model: SpotsModel
    let entry: SpotsModel.Entry
    let cardSize: SpotSize
    let isOpen: Bool
    let showsFill: Bool
    let rect: CGRect
    let closeShift: CGFloat?
    let cardWidth: CGFloat
    var hasCardLook = false
    let morph: SheetMorph
    var held: SheetPage?

    private var progress: Double {
        isOpen ? 1 : 0
    }

    private var panel: SheetParts? {
        if let held { return held.panel }
        return model.shownParts(of: entry.id)
    }

    private var list: ItemList {
        held?.list ?? model.sheets[entry.id]?.list ?? ItemList()
    }

    private var state: SpotState {
        held?.state ?? entry.shownState
    }

    private var selection: () -> Int {
        if let held { return { held.selection } }
        return { [model, id = entry.id] in
            guard let sheet = model.sheets[id] else { return 0 }
            return sheet.panel?.selectedPart == nil ? sheet.selection : Int.max
        }
    }

    private var form: FormDraft? {
        held == nil && model.form?.entry.id == entry.id ? model.form?.draft : nil
    }

    private var row: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header
                .morph(progress, offset: { [rowCardDrop] in SheetMorph.place(onCard: CGSize(width: 0, height: rowCardDrop), at: $0) })
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if let panel {
                    if panel.showsRows { Color.clear.frame(height: SpotTokens.listRowHeight) }
                    SheetPartsView(
                        panel: panel,
                        work: { [held] in held == nil ? model.work(of: $0) : nil },
                        onSet: { model.setPart($0, to: $1) },
                        onPress: { model.pressPart($0) },
                        recordingPart: held == nil ? model.recording : held?.recording,
                        onRecord: { model.toggleRecording($0) },
                        heldKeys: { [held] in held == nil ? model.heldKeys : [] },
                        keyStatus: { [held] in held == nil ? model.keyStatus : held?.keyStatus },
                        pressedKey: { [held] in held == nil ? model.pressedKey : nil },
                        isKeyDown: { [held] in held == nil && model.isKeyDown },
                        list: list,
                        onRun: { model.runItem($0) },
                        onDragOut: { model.dragOut($0, of: entry.id) },
                        selection: selection,
                        selectedPart: { [model, id = entry.id, held] in held.map(\.selectedPart) ?? model.sheets[id]?.selectedPart?.id },
                        nudge: { [held] in held == nil ? model.sheets[entry.id]?.nudge ?? SheetParts.Nudge.rest : SheetParts.Nudge.rest },
                        menuOpening: { [held] in held == nil ? model.sheets[entry.id]?.menuOpening : nil },
                        onFocus: { model.focusPart($0) },
                        viewSource: entry.spot.view,
                        viewDate: entry.spot.viewDate
                    )
                } else if let form {
                    if form.choices != nil { Color.clear.frame(height: SpotTokens.listRowHeight) }
                    SpotFormView(
                        draft: form,
                        onValue: { model.setFormValue($0, for: $1) },
                        onChoose: { model.chooseFormOption($0) },
                        selection: { [model] in model.form?.draft.choices?.selected ?? 0 }
                    )
                } else {
                    if list.search != .off { Color.clear.frame(height: SpotTokens.listRowHeight) }
                    if held == nil, let create = model.createAction {
                        Button { model.createFromSearch() } label: {
                            CreateLabel(model: model, title: create.title, shape: row)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotRowsView(list: list, recording: held == nil ? model.recording : nil, recordingWords: model.recordingWords, heldKeys: { model.heldKeys }, onRun: { model.runItem($0) }, onPoint: { model.point(at: .item($0)) }, selection: selection, onDragOut: { model.dragOut($0, of: entry.id) })
                    }
                }
            }
            .morph(progress, opacity: { [morph, firstRow] in morph.shown(firstRow, at: $0) })
        }
        .padding(SpotTokens.padding)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) { fileDrag }
        .environment(\.spotViewPlace, SpotViewPlace(model: model, place: .sheet(entry.id)))
    }

    private var header: some View {
            HStack(spacing: SpotTokens.padding - 5) {
                glyph
                ZStack(alignment: .topLeading) {
                    if showsCardWords {
                        words(subtitle: state.subtitle)
                            .environment(\.spotIsOnSolid, showsFill)
                            .frame(width: max(cardWordsWidth, 0), alignment: .leading)
                            .morph(progress, opacity: SheetMorph.cardLook(at:))
                    }
                    words(subtitle: list.perLine > 1 ? nil : state.subtitle, selectedName: list.perLine > 1)
                        .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                        .morph(progress, opacity: sheetWordsOpacity)
                }
                .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                .morph(progress, offset: { [tallCardShift] in SheetMorph.place(onCard: tallCardShift, at: $0) })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { closeButton }
    }

    private func words(subtitle: String?, selectedName: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(form?.form.title ?? state.title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .modifier(SpotInk())
                .lineLimit(1)
            if form == nil, selectedName {
                SelectedName(list: list, selection: selection, fallback: state.subtitle)
            } else if form == nil, let subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine)
                    .modifier(SpotSecondaryText())
                    .lineLimit(1)
            }
        }
    }

    private var showsCardWords: Bool {
        !hasCardLook && cardSize != .small
    }

    private var sheetWordsOpacity: (Double) -> Double {
        if hasCardLook { return { _ in 1 } }
        if !isSmallCard { return SheetMorph.sheetLook(at:) }
        let left = SpotTokens.padding + SpotTokens.glyphSize + Self.wordsGap
        let words = CGRect(x: left, y: SpotTokens.padding, width: min(wordsWidth, max(sheetWordsWidth, 0)), height: SpotType.titleLine)
        return { [morph] in morph.shown(words, at: $0) }
    }

    private var wordsWidth: CGFloat {
        SpotWordsWidth.of(title: form?.form.title ?? state.title, detail: state.subtitle)
    }

    private static let wordsGap = SpotTokens.padding - 5

    private var sheetWordsWidth: CGFloat {
        rect.width - SpotTokens.padding - SpotTokens.glyphSize - 2 * Self.wordsGap - SpotTokens.glyphSize - SpotTokens.padding
    }

    private var cardWordsWidth: CGFloat {
        if cardSize.rows > 1 { return cardWidth - 2 * SpotTokens.padding }
        let arrow = closeShift == nil ? 0 : SpotCardArrow.width + Self.wordsGap
        return max(cardWidth - SpotCardArrow.rowInset - arrow - SpotTokens.padding - SpotTokens.glyphSize - Self.wordsGap, 0)
    }

    @ViewBuilder
    private var closeButton: some View {
        let button = SpotRoundButton(symbol: "xmark", label: "Close") {
            model.closeSheet(moving: true)
        }
        if let closeShift {
            button
                .morph(progress, offset: { SheetMorph.place(onCard: CGSize(width: closeShift, height: 0), at: $0) }, opacity: SheetMorph.sheetLook(at:))
        } else if hasCardLook {
            button
        } else {
            let place = CGRect(x: rect.width - SpotTokens.padding - SpotTokens.glyphSize, y: SpotTokens.padding, width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
            button
                .morph(progress, opacity: { [morph] in morph.growth(of: place, at: $0) })
        }
    }

    private var glyph: some View {
        ZStack {
            SpotGlyph(entry: entry)
            if glyphDiffersOnCard {
                SpotGlyph(entry: entry, showsDisc: !(isSmallCard || showsFill))
                    .environment(\.spotIsOnSolid, showsFill)
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
            }
        }
        .morph(progress, offset: { [smallCardShift] in SheetMorph.place(onCard: CGSize(width: smallCardShift, height: 0), at: $0) })
    }

    @ViewBuilder
    private var fileDrag: some View {
        if isOpen, held == nil, list.hasFiles {
            Color.clear
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .contentShape(Rectangle())
                .modifier(SpotFileDragSource(items: list.shown, hasFiles: true, onDrop: { model.dragOut($0, of: entry.id) }))
                .padding(SpotTokens.padding)
        }
    }

    private var glyphDiffersOnCard: Bool {
        !hasCardLook && (showsFill || isSmallCard)
    }

    private var smallCardShift: CGFloat {
        isSmallCard ? (SpotTokens.cell - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0
    }

    private var rowCardDrop: CGFloat {
        !hasCardLook && cardSize.rows == 1 ? (SpotTokens.rowHeight - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0
    }

    private var firstRow: CGRect {
        CGRect(x: SpotTokens.padding, y: SpotTokens.padding + SpotTokens.glyphSize + SpotTokens.rowGap, width: rect.width - 2 * SpotTokens.padding, height: SpotTokens.listRowHeight)
    }

    private var isSmallCard: Bool {
        !hasCardLook && cardSize == .small
    }

    private var tallCardShift: CGSize {
        guard !hasCardLook, cardSize.rows > 1 else { return .zero }
        let hasSubtitle = form == nil && (state.subtitle != nil || (list.perLine > 1 && !list.shown.isEmpty))
        let wordsHeight = SpotType.titleLine + (hasSubtitle ? SpotType.lineGap + SpotType.detailLine : 0)
        let row = max(SpotTokens.glyphSize, wordsHeight)
        let top = SpotTokens.padding + (row - wordsHeight) / 2
        return CGSize(
            width: -(SpotTokens.glyphSize + SpotTokens.padding - 5),
            height: SpotTokens.height(rows: cardSize.rows) - SpotTokens.padding - wordsHeight - top
        )
    }
}

private struct CreateLabel: View {
    let model: SpotsModel
    let title: String
    let shape: SpotRoundShape

    var body: some View {
        Text("\(title): \(model.searchText)")
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .modifier(SpotSelectionRing(isSelected: true, shape: shape))
            .contentShape(shape)
    }
}

private struct SelectedName: View {
    let list: ItemList
    let selection: () -> Int
    let fallback: String?

    var body: some View {
        let index = selection()
        if let name = list.shown.indices.contains(index) ? list.shown[index].title : fallback {
            Text(name)
                .font(SpotType.detail)
                .frame(height: SpotType.detailLine)
                .modifier(SpotSecondaryText())
                .lineLimit(1)
        }
    }
}
