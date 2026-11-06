import SwiftUI
import OpenspotCore

struct SpotSheetView: View {
    let entry: SpotsModel.Entry
    let isOpen: Bool
    let headerIsHidden: Bool
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
    @State private var edges = SpotScrollEdges()
    @State private var wordsHeight: CGFloat = 0

    private static let bottomFade = 2 * SpotTokens.padding

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
            header
                .opacity(headerIsHidden ? 0 : 1)
            VStack(alignment: .leading, spacing: SpotTokens.rowGap) {
                if let panel {
                    SpotPanelView(panel: panel, work: work, onSet: onSet, onPress: onPress, recordingPart: recording, onRecord: onRecord)
                } else if let form {
                    SpotFormView(draft: form, onValue: onFormValue)
                } else {
                    Color.clear.frame(height: SpotTokens.listRowHeight)
                    if let createTitle {
                        Button(action: onCreate) {
                            createLabel(createTitle)
                        }
                        .buttonStyle(.plain)
                    } else if list.shown.isEmpty {
                        Text(emptyText)
                            .font(SpotType.body)
                            .modifier(SpotSecondaryText())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.identity)
                    } else {
                        rows
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
                    if form == nil, let subtitle = entry.shownState.subtitle {
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
        !isOpen && entry.size == .small
    }

    /// Whether the sheet still lies on a card with room under its header, which shows only its glyph and its words.
    private var showsTallCard: Bool {
        !isOpen && entry.size.rows > 1
    }

    /// How far the words of the header lie from their place at the foot of a tall card.
    private var tallCardShift: CGSize {
        let row = max(SpotTokens.glyphSize, wordsHeight)
        let top = SpotTokens.padding + (row - wordsHeight) / 2
        return CGSize(
            width: -(SpotTokens.glyphSize + SpotTokens.padding - 5),
            height: SpotTokens.height(rows: entry.size.rows) - SpotTokens.padding - wordsHeight - top
        )
    }

    /// Whether the sheet still lies on a card that is turned on, which is plain white.
    private var showsFill: Bool {
        !isOpen && entry.state.on == true
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        if list.isLoading { return "Loading…" }
        if list.hasFailed { return "Could not load" }
        if list.search == .script && list.query.isEmpty { return "Type to search" }
        return list.query.isEmpty ? "Nothing here yet" : "No results"
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

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: SpotTokens.listRowGap) {
                    ForEach(Array(list.shown.enumerated()), id: \.element.run) { index, item in
                        Button {
                            onRun(item)
                        } label: {
                            rowLabel(item, isSelected: index == list.selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .safeAreaPadding(.top, SpotTokens.padding)
            .safeAreaPadding(.bottom, SpotTokens.sheetFits(rows: list.shown.count) ? SpotTokens.padding : Self.bottomFade)
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask(edgeFade)
            .padding(.vertical, -SpotTokens.padding)
            .onChange(of: list.selectedItem?.run) { _, run in
                if let run { proxy.scrollTo(run) }
            }
            .onChange(of: list.query) {
                guard let run = list.shown.first?.run else { return }
                DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
            }
        }
    }

    private var edgeFade: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(1 - edges.top), .black], startPoint: .top, endPoint: .bottom)
                .frame(height: SpotTokens.padding)
            Color.black
            LinearGradient(colors: [.black, .black.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.bottomFade)
        }
    }

    private func rowLabel(_ item: SpotItem, isSelected: Bool) -> some View {
        HStack(spacing: SpotTokens.padding - 5) {
            SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(item.title)
                    .font(SpotType.body)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let shortcut = item.shortcut {
                SpotKeyLabel(text: shortcut, isRecording: recording == item.run)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(Color.white.opacity(isSelected ? SpotTokens.selectedFill : SpotTokens.fill), in: row)
        .contentShape(row)
    }
}
