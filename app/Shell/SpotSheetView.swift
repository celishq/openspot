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
    /// Whether the header lies on the white fill of a card that is turned on.
    let showsFill: Bool
    let rect: CGRect
    /// The parts of the sheet, once they have landed.
    let panel: SpotPanel?
    /// How far the close button lies from its place at the card's edge. Nil for a card with no arrow, where the frame cuts it.
    let closeShift: CGFloat?
    /// The width of the card or field that the sheet grows out of and collapses into.
    let cardWidth: CGFloat

    private var list: ItemList {
        model.sheets[entry.id]?.list ?? ItemList()
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
                    SpotPanelView(
                        panel: panel,
                        work: { model.work(of: $0) },
                        onSet: { model.setPart($0, to: $1) },
                        onPress: { model.pressPart($0) },
                        recordingPart: model.recording,
                        onRecord: { model.toggleRecording($0) },
                        list: list,
                        onRun: { model.runItem($0) },
                        nudge: { model.sheets[entry.id]?.nudge ?? SpotPanel.Nudge.rest }
                    )
                } else if let form {
                    SpotFormView(draft: form, onValue: { model.setFormValue($0, for: $1) })
                } else {
                    Color.clear.frame(height: SpotTokens.listRowHeight)
                    if let createTitle {
                        Button { model.createFromSearch() } label: {
                            createLabel(createTitle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotRowsView(list: list, recording: model.recording, onRun: { model.runItem($0) })
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
                    words(subtitle: openSubtitle)
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
    private func words(subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            Text(form?.form.title ?? entry.shownState.title)
                .font(SpotType.title)
                .frame(height: SpotType.titleLine)
                .foregroundStyle(showsFill ? SpotTheme.onSolid : SpotTheme.ink)
                .lineLimit(1)
            if form == nil, let subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .frame(height: SpotType.detailLine)
                    .modifier(SpotSecondaryText(isOnSolid: showsFill))
                    .lineLimit(1)
            }
        }
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

    /// The second line of the open sheet's header: the name of the selected button in a grid, which draws only its picture.
    private var openSubtitle: String? {
        list.perLine > 1 ? list.selectedItem?.title ?? entry.shownState.subtitle : entry.shownState.subtitle
    }

    /// The close button, which stays at the moving edge of the sheet and takes the place of the card's arrow.
    @ViewBuilder
    private var closeButton: some View {
        let button = SpotRoundButton(symbol: "xmark", label: "Close") {
            model.allowSheetMotion()
            model.closeList()
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
            } else {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(showsFill ? SpotTheme.glyphOnSolid : SpotTheme.ink)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(SpotTheme.ink.opacity(showsSmallCard || showsFill ? 0 : SpotTheme.disc), in: Circle())
            }
        }
        .offset(x: showsSmallCard ? (SpotTokens.cell - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0)
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
        let hasSubtitle = form == nil && (entry.shownState.subtitle ?? openSubtitle) != nil
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
