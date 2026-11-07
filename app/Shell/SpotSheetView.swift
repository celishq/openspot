import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    /// The size that the grid gives its card, which can differ from the size it prefers.
    let cardSize: SpotSize
    let isOpen: Bool
    /// Whether the header lies on the white fill of a card that is turned on.
    let showsFill: Bool
    let list: ItemList
    let rect: CGRect
    let form: FormDraft?
    let panel: SpotPanel?
    let work: (SpotPart) -> ScriptCall?
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    let recording: String?
    let onRecord: (SpotPart) -> Void
    let createTitle: String?
    let onCreate: () -> Void
    let onFormValue: (String, String) -> Void
    let onRun: (SpotItem) -> Void
    /// How far the close button lies from its place at the card's edge. Nil for a card with no arrow, where the frame cuts it.
    let closeShift: CGFloat?
    let onClose: () -> Void
    @State private var wordsHeight: CGFloat = 0

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if let panel {
                    if panel.showsRows { Color.clear.frame(height: SpotTokens.listRowHeight) }
                    SpotPanelView(panel: panel, work: work, onSet: onSet, onPress: onPress, recordingPart: recording, onRecord: onRecord, list: list, onRun: onRun)
                } else if let form {
                    SpotFormView(draft: form, onValue: onFormValue)
                } else {
                    Color.clear.frame(height: SpotTokens.listRowHeight)
                    if let createTitle {
                        Button(action: onCreate) {
                            createLabel(createTitle)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SpotRowsView(list: list, recording: recording, onRun: onRun)
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
                VStack(alignment: .leading, spacing: SpotType.lineGap) {
                    Text(form?.form.title ?? entry.shownState.title)
                        .font(SpotType.title)
                        .foregroundStyle(showsFill ? Color.black.opacity(SpotTokens.titleOpacity) : Color.white.opacity(SpotTokens.titleOpacity))
                        .lineLimit(1)
                    if form == nil, let subtitle = shownSubtitle {
                        Text(subtitle)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText(isOnWhite: showsFill))
                            .lineLimit(1)
                    }
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { wordsHeight = $0 }
                .offset(showsTallCard ? tallCardShift : .zero)
                .opacity(showsSmallCard ? 0 : 1)
                Spacer()
                closeButton
            }
    }

    /// The second line of the header: the name of the selected button in a grid, which draws only its picture.
    private var shownSubtitle: String? {
        isOpen && list.perLine > 1 ? list.selectedItem?.title ?? entry.shownState.subtitle : entry.shownState.subtitle
    }

    /// The close button, which stays at the moving edge of the sheet and takes the place of the card's arrow.
    @ViewBuilder
    private var closeButton: some View {
        let button = SpotRoundButton(symbol: "xmark", label: "Close", action: onClose)
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
                SpotWorkMark(call: call, isOnWhite: showsFill)
            } else {
                Image(systemName: entry.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(showsFill ? Color.accentColor : Color.white)
                    .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                    .background(Color.white.opacity(showsSmallCard || showsFill ? 0 : 0.2), in: Circle())
            }
        }
        .offset(x: showsSmallCard ? (SpotTokens.cell - SpotTokens.glyphSize) / 2 - SpotTokens.padding : 0)
    }

    /// Whether the sheet still lies on a 1x1 card, which shows its glyph alone.
    private var showsSmallCard: Bool {
        !isOpen && cardSize == .small
    }

    /// Whether the sheet still lies on a card with room under its header, which shows only its glyph and its words.
    private var showsTallCard: Bool {
        !isOpen && cardSize.rows > 1
    }

    /// How far the words of the header lie from their place at the foot of a tall card.
    private var tallCardShift: CGSize {
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
            .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpotTokens.padding)
            .frame(height: SpotTokens.listRowHeight)
            .background(Color.white.opacity(SpotTokens.selectedFill), in: row)
            .contentShape(row)
    }
}
