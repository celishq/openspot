import AppKit
import SwiftUI
import OpenspotCore

/// The content of an open sheet: its header, and its rows, parts or form. It reads the sheet's state from the model itself,
/// so that a change inside the sheet reruns only this view.
struct SpotSheetView: View {
    let model: SpotsModel
    let entry: SpotsModel.Entry
    /// The size that the grid gives its card, which can differ from the size it prefers.
    let cardSize: SpotSize
    let isOpen: Bool
    /// Whether the card is on, so that the card's look of the header lies on its fill.
    let showsFill: Bool
    let rect: CGRect
    /// How far the close button lies from its place at the card's edge. Nil for a card with no arrow, where the frame cuts it.
    let closeShift: CGFloat?
    /// The width of the card or field that the sheet grows out of and collapses into.
    let cardWidth: CGFloat
    /// Whether the card draws its own look over the closed sheet, so that the header keeps its open place and only fades.
    var hasCardLook = false
    /// The sheet's shape between its card and its open place.
    let morph: SheetMorph

    /// How far the sheet is open, which the sheet's motion carries from 0 on its card to 1.
    private var progress: Double {
        isOpen ? 1 : 0
    }

    /// The parts of the sheet, once they have landed.
    private var panel: SheetParts? {
        model.shownParts(of: entry.id)
    }

    private var list: ItemList {
        model.sheets[entry.id]?.list ?? ItemList()
    }

    /// Reads the selected row where it is called, so that only the view that shows it hears of a move. While a part below
    /// the rows has the focus, no row is selected.
    private var selection: () -> Int {
        { [model, id = entry.id] in
            guard let sheet = model.sheets[id] else { return 0 }
            return sheet.panel?.selectedPart == nil ? sheet.selection : Int.max
        }
    }

    private var form: FormDraft? {
        model.form?.entry.id == entry.id ? model.form?.draft : nil
    }

    /// The words of the button that makes a new item from the search, or nil when there is none.
    private var createTitle: String? {
        model.createAction.map { "\($0.title): \(model.searchText)" }
    }

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
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
                        work: { model.work(of: $0) },
                        onSet: { model.setPart($0, to: $1) },
                        onPress: { model.pressPart($0) },
                        recordingPart: model.recording,
                        onRecord: { model.toggleRecording($0) },
                        list: list,
                        onRun: { model.runItem($0) },
                        onDragOut: { model.dragOut($0, of: entry.id) },
                        selection: selection,
                        selectedPart: { [model, id = entry.id] in model.sheets[id]?.selectedPart?.id },
                        nudge: { model.sheets[entry.id]?.nudge ?? SheetParts.Nudge.rest },
                        menuOpening: { model.sheets[entry.id]?.menuOpening },
                        onFocus: { model.focusPart($0) },
                        customView: { room in
                            entry.spot.view.map { SpotCustomView(source: $0, values: entry.state.values, card: .square, room: room, views: SpotViews.shared) }
                        }
                    )
                    .task(id: panel.parts.contains { $0.kind == "view" } ? entry.spot.view : nil) {
                        if let view = entry.spot.view, panel.parts.contains(where: { $0.kind == "view" }) { await SpotViews.shared.load(view) }
                    }
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
                    if let createTitle {
                        Button { model.createFromSearch() } label: {
                            createLabel(createTitle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotRowsView(list: list, recording: model.recording, recordingWords: model.recordingWords, onRun: { model.runItem($0) }, onPoint: { model.point(at: .item($0)) }, selection: selection, onDragOut: { model.dragOut($0, of: entry.id) })
                    }
                }
            }
            .morph(progress, opacity: { [morph, firstRow] in morph.shown(firstRow, at: $0) })
        }
        .padding(SpotTokens.padding)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }

    private var header: some View {
            HStack(spacing: SpotTokens.padding - 5) {
                glyph
                ZStack(alignment: .topLeading) {
                    if showsCardWords {
                        words(subtitle: entry.shownState.subtitle, isOnSolid: showsFill)
                            .frame(width: max(cardWordsWidth, 0), alignment: .leading)
                            .morph(progress, opacity: SheetMorph.cardLook(at:))
                    }
                    words(subtitle: list.perLine > 1 ? nil : entry.shownState.subtitle, selectedName: list.perLine > 1)
                        .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                        .morph(progress, opacity: sheetWordsOpacity)
                }
                .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                .morph(progress, offset: { [tallCardShift] in SheetMorph.place(onCard: tallCardShift, at: $0) })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { closeButton }
    }

    /// The title and the second line of the header, in one copy of its words.
    private func words(subtitle: String?, selectedName: Bool = false, isOnSolid: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(form?.form.title ?? entry.shownState.title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .foregroundStyle(isOnSolid ? SpotTheme.onSolid : SpotTheme.ink)
                .lineLimit(1)
            if form == nil, selectedName {
                SelectedName(list: list, selection: selection, fallback: entry.shownState.subtitle, isOnSolid: isOnSolid)
            } else if form == nil, let subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine)
                    .modifier(SpotSecondaryText(isOnSolid: isOnSolid))
                    .lineLimit(1)
            }
        }
    }

    /// Whether the card shows the stock words, which give way to the sheet's words in the first half of the motion. A 1x1
    /// card shows none, and a card with its own look draws its own.
    private var showsCardWords: Bool {
        !hasCardLook && cardSize != .small
    }

    /// How strongly the sheet's words show: in the second half of the motion where the card shows words, and once the
    /// shape holds most of them where it shows none. Over a card's own look they stay, as the whole sheet fades.
    private var sheetWordsOpacity: (Double) -> Double {
        if hasCardLook { return { _ in 1 } }
        if !isSmallCard { return SheetMorph.sheetLook(at:) }
        let left = SpotTokens.padding + SpotTokens.glyphSize + Self.wordsGap
        let words = CGRect(x: left, y: SpotTokens.padding, width: min(wordsWidth, max(sheetWordsWidth, 0)), height: SpotType.titleLine)
        return { [morph] in morph.shown(words, at: $0) }
    }

    /// The width of the header's words as they are drawn, the longer of the title and the second line.
    private var wordsWidth: CGFloat {
        let title = (form?.form.title ?? entry.shownState.title) as NSString
        let detail = (entry.shownState.subtitle ?? "") as NSString
        return max(
            title.size(withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).width,
            detail.size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
        )
    }

    private static let wordsGap = SpotTokens.padding - 5

    /// The width of the words up to the close button in the open sheet.
    private var sheetWordsWidth: CGFloat {
        rect.width - SpotTokens.padding - SpotTokens.glyphSize - 2 * Self.wordsGap - SpotTokens.glyphSize - SpotTokens.padding
    }

    /// The width that the card gives the words before the sheet opens.
    private var cardWordsWidth: CGFloat {
        if cardSize.rows > 1 { return cardWidth - 2 * SpotTokens.padding }
        let arrow = closeShift == nil ? 0 : SpotCardArrow.width + Self.wordsGap
        return max(cardWidth - SpotCardArrow.rowInset - arrow - SpotTokens.padding - SpotTokens.glyphSize - Self.wordsGap, 0)
    }

    /// The close button, which stays at the moving edge of the sheet and takes the place of the card's arrow.
    @ViewBuilder
    private var closeButton: some View {
        let button = SpotRoundButton(symbol: "xmark", label: "Close") {
            model.closeList(moving: true)
        }
        if let closeShift {
            button
                .morph(progress, offset: { SheetMorph.place(onCard: CGSize(width: closeShift, height: 0), at: $0) }, opacity: SheetMorph.sheetLook(at:))
        } else if hasCardLook {
            button
        } else {
            let place = CGRect(x: rect.width - SpotTokens.padding - SpotTokens.glyphSize, y: SpotTokens.padding, width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
            button
                .morph(progress, opacity: { [morph] in morph.growth(of: place, at: $0) }, scale: { [morph] in morph.growth(of: place, at: $0) })
        }
    }

    /// The card's glyph, which moves from the card's place for it to the header's. Where the card draws it on its fill or
    /// with no disc, the card's look of it gives way to the sheet's as the fill does.
    private var glyph: some View {
        ZStack {
            SpotGlyph(entry: entry)
            if glyphDiffersOnCard {
                SpotGlyph(entry: entry, isOnSolid: showsFill, showsDisc: !(isSmallCard || showsFill))
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
            }
        }
        .morph(progress, offset: { [smallCardShift] in SheetMorph.place(onCard: CGSize(width: smallCardShift, height: 0), at: $0) })
        .modifier(SpotFileDragSource(items: isOpen ? list.shown : [], onDrop: { model.dragOut($0, of: entry.id) }))
    }

    /// Whether the card draws its glyph unlike the header: on its fill, or alone with no disc on a 1x1 card.
    private var glyphDiffersOnCard: Bool {
        !hasCardLook && (showsFill || isSmallCard)
    }

    /// How far the glyph of a 1x1 card lies from its place in the header: in the middle of the card.
    private var smallCardShift: CGFloat {
        isSmallCard ? (SpotTokens.cell - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0
    }

    /// How far the header of a card one row high lies from its place in the sheet: in the middle of that row.
    private var rowCardDrop: CGFloat {
        !hasCardLook && cardSize.rows == 1 ? (SpotTokens.rowHeight - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0
    }

    /// The first row under the header, in the content: the body shows once most of it lies inside the shape.
    private var firstRow: CGRect {
        CGRect(x: SpotTokens.padding, y: SpotTokens.padding + SpotTokens.glyphSize + SpotTokens.rowGap, width: rect.width - 2 * SpotTokens.padding, height: SpotTokens.listRowHeight)
    }

    private var isSmallCard: Bool {
        !hasCardLook && cardSize == .small
    }

    /// How far the words of the header lie from their place at the foot of a tall card, and none on any other card.
    private var tallCardShift: CGSize {
        guard !hasCardLook, cardSize.rows > 1 else { return .zero }
        let hasSubtitle = form == nil && (entry.shownState.subtitle != nil || (list.perLine > 1 && !list.shown.isEmpty))
        let wordsHeight = SpotType.titleLine + (hasSubtitle ? SpotType.lineGap + SpotType.detailLine : 0)
        let row = max(SpotTokens.glyphSize, wordsHeight)
        let top = SpotTokens.padding + (row - wordsHeight) / 2
        return CGSize(
            width: -(SpotTokens.glyphSize + SpotTokens.padding - 5),
            height: SpotTokens.height(rows: cardSize.rows) - SpotTokens.padding - wordsHeight - top
        )
    }

    private func createLabel(_ title: String) -> some View {
        Text(title)
            .font(SpotType.body)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: row)
            .modifier(SpotSelectionRing(isSelected: true, shape: row))
            .contentShape(row)
    }
}

/// The second line of a grid's header: the name of the selected button, which draws only its picture. It alone reads the
/// selection, so that a move redraws only this line.
private struct SelectedName: View {
    let list: ItemList
    let selection: () -> Int
    let fallback: String?
    let isOnSolid: Bool

    var body: some View {
        let index = selection()
        if let name = list.shown.indices.contains(index) ? list.shown[index].title : fallback {
            Text(name)
                .font(SpotType.detail)
                .frame(height: SpotType.detailLine)
                .modifier(SpotSecondaryText(isOnSolid: isOnSolid))
                .lineLimit(1)
        }
    }
}
