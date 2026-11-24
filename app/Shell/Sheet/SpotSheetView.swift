import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
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
    var cardState: SpotState?
    var held: SheetPage?

    var body: some View {
        SheetContentView(
            model: model, entry: entry, cardSize: cardSize, isOpen: isOpen, showsFill: showsFill, rect: rect, closeShift: closeShift,
            cardWidth: cardWidth, hasCardLook: hasCardLook, morph: morph, cardState: cardState,
            content: held.map(SheetContent.init(page:)) ?? model.sheetContent(of: entry)
        )
    }
}

private struct SheetContentView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    @Environment(\.spotIsHeld) private var isHeld
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
    var cardState: SpotState?
    let content: SheetContent

    private var progress: Double {
        isOpen ? 1 : 0
    }

    private var list: ItemList {
        content.list
    }

    private var state: SpotState {
        content.state
    }

    private var selection: () -> Int {
        content.selection
    }

    private var form: FormDraft? {
        content.form
    }

    private var row: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header
                .morph(progress, offset: { [rowCardDrop] in SheetMorph.place(onCard: CGSize(width: 0, height: rowCardDrop), at: $0) })
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if let form {
                    if form.choices != nil { Color.clear.frame(height: SpotTokens.listRow) }
                    SpotFormView(
                        draft: form,
                        onValue: { model.setFormValue($0, for: $1) },
                        onChoose: { model.chooseFormOption($0) },
                        selection: { [model] in model.form?.draft.choices?.selected ?? 0 }
                    )
                } else {
                    if top.hasField { Color.clear.frame(height: SpotTokens.listRow) }
                    if content.panel?.holdsParts != true, let create = content.create() {
                        Button { model.createFromSearch() } label: {
                            CreateLabel(model: model, title: create.title, shape: row)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotSheetBody(
                            panel: content.panel,
                            list: list,
                            host: SheetHost(model: model, id: entry.id, content: content, isHeld: isHeld),
                            recording: content.recording,
                            recordingWords: model.recordingWords,
                            keys: content.keys,
                            onPick: { model.runItem($0) },
                            onPoint: { model.point(at: .item($0)) },
                            onDragOut: { model.dragOut($0, of: entry.id) },
                            selection: selection,
                            failure: { [model, id = entry.id] in model.failure(of: $0, in: id) },
                            tips: model,
                            shakes: { [model, id = entry.id] in model.refusals(of: $0, in: id) },
                            room: top.listRoom
                        )
                    }
                }
            }
            .morph(progress, opacity: { [morph, firstRow] in min(morph.shown(firstRow, at: $0), SheetMorph.contentLook(at: $0)) })
        }
        .padding(SpotTokens.padding)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .overlay(alignment: .topLeading) { fileDrag }
        .environment(\.spotViewPlace, SpotViewPlace(model: model, place: .sheet(entry.id)))
        .environment(\.spotSearchTitle, state.title)
        .environment(\.spotViewDates, entry.spot.viewDates)
    }

    private var header: some View {
            HStack(spacing: SpotTokens.wordsGap) {
                glyph
                ZStack(alignment: .leading) {
                    if showsCardWords {
                        words(title: cardState?.title, subtitle: cardState.map(\.subtitle) ?? state.subtitle)
                            .environment(\.spotIsOnSolid, showsFill)
                            .frame(width: max(cardWordsWidth, 0), alignment: .leading)
                            .morph(progress, opacity: { [morph] in morph.sourceLook(at: $0) })
                    }
                    words(subtitle: state.subtitle)
                        .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                        .morph(progress, opacity: sheetWordsOpacity)
                }
                .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                .morph(progress, offset: { [tallCardShift] in SheetMorph.place(onCard: tallCardShift, at: $0) })
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { closeButton }
    }

    private func words(title: String? = nil, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(title ?? form?.form.title ?? state.title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .modifier(SpotInk())
                .lineLimit(1)
            if form == nil, let subtitle {
                let lines = title == nil && hasSecondLine ? 2 : 1
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine * CGFloat(lines), alignment: .topLeading)
                    .modifier(SpotSecondaryText())
                    .lineLimit(lines)
            }
        }
    }

    private var top: SheetTop {
        content.top
    }

    private var hasSecondLine: Bool {
        top.header > 0
    }

    private var showsCardWords: Bool {
        morph.source == .card && !hasCardLook && cardSize != .small
    }

    private var sheetWordsOpacity: (Double) -> Double {
        if hasCardLook { return { _ in 1 } }
        return SheetMorph.contentLook(at:)
    }

    private var sheetWordsWidth: CGFloat {
        rect.width - SpotTokens.padding - SpotTokens.glyph - 2 * SpotTokens.wordsGap - SpotTokens.glyph - SpotTokens.padding
    }

    private var cardWordsWidth: CGFloat {
        if cardSize.rows > 1 { return cardWidth - 2 * SpotTokens.padding }
        let arrow = closeShift == nil ? 0 : SpotTokens.arrowWidth + SpotTokens.wordsGap
        return max(cardWidth - SpotTokens.arrowRowInset - arrow - SpotTokens.padding - SpotTokens.glyph - SpotTokens.wordsGap, 0)
    }

    @ViewBuilder
    private var closeButton: some View {
        let button = SpotRoundButton(icon: .symbol("xmark"), label: "Close") {
            model.closeSheet(moving: true)
        }
        if let closeShift {
            button
                .morph(progress, offset: { SheetMorph.place(onCard: CGSize(width: closeShift, height: 0), at: $0) }, opacity: SheetMorph.contentLook(at:))
        } else if hasCardLook {
            button
        } else {
            let place = CGRect(x: rect.width - SpotTokens.padding - SpotTokens.glyph, y: SpotTokens.padding, width: SpotTokens.glyph, height: SpotTokens.glyph)
            button
                .morph(progress, opacity: { [morph] in min(morph.growth(of: place, at: $0), morph.headerLook(at: $0)) })
        }
    }

    private var glyph: some View {
        ZStack {
            SpotGlyph(entry: entry)
            if glyphDiffersOnCard {
                SpotGlyph(entry: entry, showsDisc: !(isSmallCard || showsFill))
                    .environment(\.spotIsOnSolid, showsFill)
                    .morph(progress, opacity: { [morph] in morph.sourceLook(at: $0) })
            }
        }
        .morph(progress, offset: { [smallCardShift] in SheetMorph.place(onCard: CGSize(width: smallCardShift, height: 0), at: $0) }, opacity: { [morph] in morph.headerLook(at: $0) })
    }

    @ViewBuilder
    private var fileDrag: some View {
        if isOpen, content.takesFiles {
            Color.clear
                .frame(width: SpotTokens.glyph, height: SpotTokens.glyph)
                .contentShape(Rectangle())
                .modifier(SpotFileDragSource(items: list.shown, hasFiles: true, onDrop: { model.dragOut($0, of: entry.id) }))
                .padding(SpotTokens.padding)
        }
    }

    private var glyphDiffersOnCard: Bool {
        !hasCardLook && (showsFill || isSmallCard)
    }

    private var smallCardShift: CGFloat {
        isSmallCard ? (SpotTokens.cell - SpotTokens.glyph) / 2 - SpotTokens.padding : 0
    }

    private var rowCardDrop: CGFloat {
        !hasCardLook && cardSize.rows == 1 ? (SpotTokens.cell - SpotTokens.glyph) / 2 - SpotTokens.padding : 0
    }

    private var firstRow: CGRect {
        CGRect(x: SpotTokens.padding, y: top.fieldY, width: rect.width - 2 * SpotTokens.padding, height: SpotTokens.listRow)
    }

    private var isSmallCard: Bool {
        !hasCardLook && cardSize == .small
    }

    private var tallCardShift: CGSize {
        guard !hasCardLook, cardSize.rows > 1 else { return .zero }
        let hasSubtitle = form == nil && state.subtitle != nil
        let wordsHeight = SpotType.titleLine + (hasSubtitle ? SpotType.lineGap + SpotType.detailLine : 0)
        let row = max(SpotTokens.glyph, wordsHeight)
        let top = SpotTokens.padding + (row - wordsHeight) / 2
        return CGSize(
            width: -(SpotTokens.glyph + SpotTokens.wordsGap),
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
            .frame(height: SpotTokens.listRow)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .modifier(SpotSelectionRing(isSelected: true, shape: shape))
            .contentShape(shape)
    }
}
