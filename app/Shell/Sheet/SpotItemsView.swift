import OpenspotCore
import SwiftUI

struct SpotItemsView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let list: ItemList
    var recording: String?
    var recordingWords = "Press keys"
    var keys: KeyRecording?
    let onRun: (SpotItem) -> Void
    var onPoint: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    var onDragOut: ([SpotItem]) -> Void = { _ in }
    var failure: (String) -> String? = { _ in nil }
    var tips: SpotsModel?
    var shakes: (String) -> Int = { _ in 0 }
    var room = SpotTokens.listRoom

    private static var bottomFade: CGFloat { 2 * SpotTokens.padding }

    private var row: SpotRoundShape {
        SpotRoundShape(surface.inner())
    }

    private var selected: () -> Int {
        selection ?? { [list] in list.selected }
    }

    private var selectedRun: () -> String? {
        { [list, selected] in list.run(at: selected()) }
    }

    private var isGrid: Bool {
        list.perLine > 1
    }

    var body: some View {
        if list.shown.isEmpty {
            Text(emptyText)
                .font(SpotType.body)
                .modifier(SpotSecondaryText())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.identity)
        } else if isGrid || (list.pinnedTop.isEmpty && list.pinnedBottom.isEmpty) {
            scroll
        } else {
            VStack(spacing: SpotTokens.listRowGap) {
                pinned(.top)
                if !list.scrolling.isEmpty {
                    pinnedScroll
                } else {
                    Spacer(minLength: 0)
                }
                if list.setsApart {
                    Rectangle()
                        .fill(SpotTheme.ink.opacity(SpotTheme.fill))
                        .frame(height: 1)
                        .frame(height: SpotTokens.pinRuleRoom)
                }
                pinned(.bottom)
            }
        }
    }

    private func pinned(_ pin: SpotItem.Pin) -> some View {
        ForEach(pin == .top ? list.pinnedTop : list.pinnedBottom, id: \.run) { item in
            Button { onRun(item) } label: { rowLabel(item) }
                .buttonStyle(.plain)
        }
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        if list.isLoading { return list.loadingWords ?? "Loading…" }
        if list.hasFailed { return "Could not load" }
        if list.search == .script && list.query.isEmpty { return "Type to search" }
        return list.query.isEmpty ? "Nothing here yet" : "No results"
    }

    private var scroll: some View {
        Group {
            if isGrid { grid } else { lineScroll }
        }
        .modifier(ItemsFade(bottom: Self.bottomFade))
        .padding(.vertical, -SpotTokens.padding)
    }

    private var bottomInset: CGFloat {
        SpotTokens.rowsFit(rows: list.lineCount, perLine: list.perLine, sections: list.sectionCount, in: room) ? SpotTokens.padding : Self.bottomFade
    }

    private var pinnedScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { lines }
                .modifier(ItemsFollow(selection: selected, items: list.shown, proxy: proxy))
                .onChange(of: list.landedSearches) {
                    guard let run = list.scrolling.first?.run else { return }
                    DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
                }
        }
    }

    private var lineScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { lines }
                .safeAreaPadding(.top, SpotTokens.padding)
                .safeAreaPadding(.bottom, bottomInset)
                .modifier(ItemsFollow(selection: selected, items: list.shown, proxy: proxy))
                .onChange(of: list.landedSearches) {
                    guard let run = list.shown.first?.run else { return }
                    DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
                }
        }
    }

    private var grid: some View {
        SpotItemGrid(list: list, selection: selected, bottomInset: bottomInset, bottomFade: Self.bottomFade, onRun: onRun, onPoint: onPoint, onDragOut: onDragOut)
    }

    private var lines: some View {
        LazyVStack(spacing: SpotTokens.listRowGap) {
            ForEach(list.scrolling, id: \.run) { item in
                if let section = list.sectionStarts[item.run] {
                    Text(section)
                        .font(SpotType.detail.weight(.semibold))
                        .modifier(SpotSecondaryText())
                        .padding(.horizontal, SpotTokens.padding)
                        .frame(maxWidth: .infinity, minHeight: SpotTokens.listSection, maxHeight: SpotTokens.listSection, alignment: .bottomLeading)
                }
                Button {
                    onRun(item)
                } label: {
                    rowLabel(item)
                }
                .buttonStyle(.plain)
                .modifier(SpotFileDragSource(items: [item], hasFiles: item.file != nil, onDrop: onDragOut))
            }
        }
        .modifier(SpotPointerMove(at: { [list, onPoint] in if let item = $0.flatMap({ list.lineItem(at: $0.y) }) { onPoint(item) } }))
    }

    private func rowLabel(_ item: SpotItem) -> some View {
        HStack(spacing: SpotTokens.wordsGap) {
            SpotItemIcon(item: item, size: SpotTokens.listIconSize)
                .overlay(alignment: .bottomTrailing) { SpotToneDot(tone: item.tone, side: SpotTokens.listIconSize) }
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                Text(item.title)
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let number = item.number {
                SpotRowNumber(number: number, tone: item.tone)
            }
            if let shortcut = item.shortcut {
                LiveKeyLabel(text: shortcut, isRecording: recording == item.run, words: recordingWords, keys: keys)
            }
            ItemFailureMark(failure: { [failure, run = item.run] in failure(run) }, tips: tips, id: item.run)
            if item.isToggle {
                ItemSwitch(isOn: item.isOn)
            } else if item.isOn {
                Image(systemName: "checkmark")
                    .font(SpotType.body.weight(.semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRow)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: row)
        .modifier(SpotLiveSelectionRing(isSelected: { [selectedRun, run = item.run] in selectedRun() == run }, shape: row, marksMenu: true))
        .contentShape(row)
        .modifier(SpotShake(count: { [shakes, run = item.run] in shakes(run) }))
    }
}

private struct LiveKeyLabel: View {
    let text: String
    let isRecording: Bool
    let words: String
    let keys: KeyRecording?

    var body: some View {
        SpotKeyLabel(text: text, isRecording: isRecording, recordingWords: words, held: isRecording ? keys?.held ?? [] : [])
    }
}

private struct ItemFailureMark: View {
    let failure: () -> String?
    let tips: SpotsModel?
    let id: String

    var body: some View {
        if let text = failure() {
            let mark = Image(systemName: "exclamationmark.triangle.fill")
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .accessibilityLabel("Last run failed")
            if let tips { mark.modifier(SpotFailureTip(model: tips, id: id, text: text)) } else { mark }
        }
    }
}

private struct ItemSwitch: View {
    let isOn: Bool

    var body: some View {
        Toggle("", isOn: .constant(isOn))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
            .tint(SpotTheme.accent)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct ItemsFade: ViewModifier {
    let bottom: CGFloat
    @State private var edges = SpotScrollEdges()

    func body(content: Content) -> some View {
        content
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [SpotTheme.mask.opacity(1 - edges.top), SpotTheme.mask], startPoint: .top, endPoint: .bottom)
                        .frame(height: SpotTokens.padding)
                    SpotTheme.mask
                    LinearGradient(colors: [SpotTheme.mask, SpotTheme.mask.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom)
                }
            }
    }
}

private struct ItemsFollow: ViewModifier {
    let selection: () -> Int
    let items: [SpotItem]
    let proxy: ScrollViewProxy
    var motion: Animation?

    func body(content: Content) -> some View {
        content.onChange(of: selection()) { _, index in
            guard items.indices.contains(index) else { return }
            withAnimation(motion) { proxy.scrollTo(items[index].run) }
        }
    }
}
