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
    /// Whether the header lies on the white fill of a card that is turned on. Its colours change with the fill, on the fill's
    /// own curve.
    let showsFill: Bool
    let rect: CGRect
    /// The parts of the sheet, once they have landed.
    let panel: SheetParts?
    /// How far the close button lies from its place at the card's edge. Nil for a card with no arrow, where the frame cuts it.
    let closeShift: CGFloat?
    /// The width of the card or field that the sheet grows out of and collapses into.
    let cardWidth: CGFloat

    private var list: ItemList {
        model.sheets[entry.id]?.list ?? ItemList()
    }

    /// Reads the selected row where it is called, so that only the view that shows it hears of a move.
    private var selection: () -> Int {
        { [model, id = entry.id] in model.sheets[id]?.selection ?? 0 }
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
                .offset(y: showsRowCard ? (SpotTokens.rowHeight - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0)
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
                        onSlot: { model.slot($1, of: $0, to: $2) },
                        selection: selection,
                        nudge: { model.sheets[entry.id]?.nudge ?? SheetParts.Nudge.rest },
                        customView: { room in
                            entry.command.view.map { SpotCustomView(source: $0, values: entry.state.values, card: entry.state.size ?? .square, room: room, views: SpotViews.shared) }
                        }
                    )
                    .task(id: panel.parts.contains { $0.kind == "view" } ? entry.command.view : nil) {
                        if let view = entry.command.view, panel.parts.contains(where: { $0.kind == "view" }) { await SpotViews.shared.load(view) }
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
                    Color.clear.frame(height: SpotTokens.listRowHeight)
                    if let createTitle {
                        Button { model.createFromSearch() } label: {
                            createLabel(createTitle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotRowsView(list: list, recording: model.recording, onRun: { model.runItem($0) }, selection: selection, onSlot: { model.slot($1, of: $0, to: $2) })
                    }
                }
            }
            .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: isOpen)) { $0.opacity(isOpen ? 1 : 0) }
        }
        .padding(SpotTokens.padding)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
    }

    private var header: some View {
            HStack(spacing: SpotTokens.padding - 5) {
                glyph
                ZStack(alignment: .topLeading) {
                    words(subtitle: entry.shownState.subtitle)
                        .frame(width: max(cardWordsWidth, 0), alignment: .leading)
                        .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: isOpen)) { $0.opacity(isOpen ? 0 : 1) }
                    words(subtitle: list.perLine > 1 ? nil : entry.shownState.subtitle, selectedName: list.perLine > 1)
                        .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                        .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: !isOpen)) { $0.opacity(isOpen ? 1 : 0) }
                }
                .frame(width: max(sheetWordsWidth, 0), alignment: .leading)
                .offset(showsTallCard ? tallCardShift : .zero)
                .opacity(showsSmallCard ? 0 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { closeButton }
    }

    /// The title and the second line of the header, in one copy of its words.
    private func words(subtitle: String?, selectedName: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(form?.form.title ?? entry.shownState.title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .foregroundStyle(showsFill ? SpotTheme.onSolid : SpotTheme.ink)
                .lineLimit(1)
            if form == nil, selectedName {
                SelectedName(list: list, selection: selection, fallback: entry.shownState.subtitle, isOnSolid: showsFill)
            } else if form == nil, let subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine)
                    .modifier(SpotSecondaryText(isOnSolid: showsFill))
                    .lineLimit(1)
            }
        }
        .animation(fillFade, value: showsFill)
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
                .animation(SpotMotion.sheetFade(isOpen: isOpen, isLate: isOpen)) { $0.opacity(isOpen ? 1 : 0) }
                .offset(x: isOpen ? 0 : closeShift)
        } else {
            button
        }
    }

    /// The card's glyph, placed as the card places it until the sheet opens.
    private var glyph: some View {
        Group {
            if let call = entry.work {
                SpotWorkMark(call: call, isOnSolid: showsFill)
            } else if entry.showsHeaderPicture {
                SpotItemIcon(icon: entry.command.icon, glyph: entry.command.glyph, symbol: nil, size: SpotTokens.glyphSize)
            } else {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(showsFill ? SpotTheme.glyphOnSolid : SpotTheme.ink)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(SpotTheme.ink.opacity(showsSmallCard || showsFill ? 0 : SpotTheme.disc), in: Circle())
            }
        }
        .animation(fillFade, value: showsFill)
        .offset(x: showsSmallCard ? (SpotTokens.cell - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0)
    }

    /// The fade of the card's fill, which the colours on it follow.
    private var fillFade: Animation {
        SpotMotion.fillFade(isOpen: isOpen)
    }

    /// Whether the sheet still lies on a 1x1 card, which shows its glyph alone.
    private var showsSmallCard: Bool {
        !isOpen && cardSize == .small
    }

    /// Whether the sheet still lies on a card one row high, which centres its glyph in that row.
    private var showsRowCard: Bool {
        !isOpen && cardSize.rows == 1
    }

    /// Whether the sheet still lies on a card with room under its header, which shows only its glyph and its words.
    private var showsTallCard: Bool {
        !isOpen && cardSize.rows > 1
    }

    /// How far the words of the header lie from their place at the foot of a tall card.
    private var tallCardShift: CGSize {
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
