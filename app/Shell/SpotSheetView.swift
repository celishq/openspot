import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    let isOpen: Bool
    let list: ItemList
    let rect: CGRect
    let form: FormDraft?
    let panel: SpotPanel?
    let work: (SpotPart) -> ScriptCall?
    let onSet: (SpotPart, String) -> Void
    let onPress: (SpotPart) -> Void
    let recordingPart: String?
    let onRecord: (SpotPart) -> Void
    let createTitle: String?
    let onCreate: () -> Void
    let onFormValue: (String, String) -> Void
    let onRun: (SpotItem) -> Void
    let onClose: () -> Void

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header
            if let panel {
                if panel.showsRows { Color.clear.frame(height: SpotTokens.listRowHeight) }
                SpotPanelView(panel: panel, work: work, onSet: onSet, onPress: onPress, recordingPart: recordingPart, onRecord: onRecord, list: list, onRun: onRun)
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
                    SpotRowsView(list: list, onRun: onRun)
                }
            }
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
                .opacity(showsSmallCard ? 0 : 1)
                Spacer()
                SpotRoundButton(symbol: "xmark", label: "Close", action: onClose)
            }
    }

    /// The second line of the header: the name of the selected button in a grid, which draws only its picture.
    private var shownSubtitle: String? {
        isOpen && list.perLine > 1 ? list.selectedItem?.title ?? entry.shownState.subtitle : entry.shownState.subtitle
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
        !isOpen && entry.size == .small
    }

    /// Whether the sheet still lies on a card that is turned on, which is plain white.
    private var showsFill: Bool {
        !isOpen && entry.state.on == true
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
