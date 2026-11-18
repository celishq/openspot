import OpenspotCore
import SwiftUI

struct SpotRowsView: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let list: ItemList
    var recording: String?
    var recordingWords = "Press keys"
    var keys: KeyRecording?
    let onRun: (SpotItem) -> Void
    var onPoint: (SpotItem) -> Void = { _ in }
    var selection: (() -> Int)?
    var onDragOut: ([SpotItem]) -> Void = { _ in }

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
            if list.isBento { bentoScroll } else if isGrid { grid } else { lineScroll }
        }
        .modifier(RowsFade(bottom: Self.bottomFade))
        .padding(.vertical, -SpotTokens.padding)
    }

    private var bottomInset: CGFloat {
        SpotTokens.sheetFits(rows: list.lineCount, perLine: list.perLine) ? SpotTokens.padding : Self.bottomFade
    }

    private var pinnedScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { lines }
                .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy))
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
                .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy))
                .onChange(of: list.landedSearches) {
                    guard let run = list.shown.first?.run else { return }
                    DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
                }
        }
    }

    private var grid: some View {
        SpotRowGrid(list: list, selection: selected, bottomInset: bottomInset, bottomFade: Self.bottomFade, onRun: onRun, onPoint: onPoint, onDragOut: onDragOut)
    }

    private var lines: some View {
        LazyVStack(spacing: SpotTokens.listRowGap) {
            ForEach(list.scrolling, id: \.run) { item in
                if let section = list.sectionStarts[item.run] {
                    Text(section)
                        .font(SpotType.detail.weight(.semibold))
                        .modifier(SpotSecondaryText())
                        .padding(.horizontal, SpotTokens.padding)
                        .frame(maxWidth: .infinity, minHeight: SpotTokens.listRow, maxHeight: SpotTokens.listRow, alignment: .bottomLeading)
                }
                Button {
                    onRun(item)
                } label: {
                    rowLabel(item)
                }
                .buttonStyle(.plain)
                .modifier(SpotPointerMove { onPoint(item) })
                .modifier(SpotFileDragSource(items: [item], hasFiles: item.file != nil, onDrop: onDragOut))
            }
        }
    }

    private var bentoScroll: some View {
        let drawing = list.drawing
        let side = SpotTokens.square(perLine: drawing.columns)
        let step = side + SpotTokens.listRowGap
        let lines = drawing.lineCount(rows: list.shown.count)
        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(list.shown.enumerated()), id: \.element.run) { index, item in
                        let area = drawing.area(of: index)
                        bentoCell(item, size: Self.size(of: area, step: step))
                            .id(item.run)
                            .offset(x: CGFloat(area.x0) * step, y: CGFloat(area.y0) * step)
                    }
                }
                .overlay(alignment: .topLeading) { BentoRing(selection: selected, count: list.shown.count, drawing: drawing, step: step) }
                .frame(width: SpotTokens.partsWidth, height: max(CGFloat(lines) * step - SpotTokens.listRowGap, 0), alignment: .topLeading)
                .padding(.top, SpotTokens.padding)
                .padding(.bottom, bottomInset)
            }
            .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy, motion: SpotMotion.move))
            .onChange(of: list.landedSearches) {
                guard let run = list.shown.first?.run else { return }
                DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
            }
        }
    }

    fileprivate static func size(of area: SheetArea, step: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(area.x1 - area.x0 + 1) * step - SpotTokens.listRowGap,
            height: CGFloat(area.y1 - area.y0 + 1) * step - SpotTokens.listRowGap
        )
    }

    private func bentoCell(_ item: SpotItem, size: CGSize) -> some View {
        SpotItemIcon(item: item, size: min(size.width, size.height) * SpotTokens.tileIconShare)
            .overlay(alignment: .bottomTrailing) { SpotToneDot(tone: item.tone, side: min(size.width, size.height) * SpotTokens.tileIconShare) }
            .frame(width: size.width, height: size.height)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: row)
        .contentShape(row)
        .onTapGesture { onRun(item) }
        .modifier(SpotPointerMove { onPoint(item) })
        .modifier(SpotFileDragSource(items: [item], hasFiles: item.file != nil, onDrop: onDragOut))
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(.isButton)
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
                if let focus = item.focusSubtitle {
                    RowDetail(text: item.subtitle, focus: focus, run: item.run, selectedRun: selectedRun)
                } else if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(SpotType.detail)
                        .modifier(SpotSecondaryText())
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !item.bars.isEmpty {
                RowBars(bars: item.bars, tone: item.tone)
            }
            if let shortcut = item.shortcut {
                LiveKeyLabel(text: shortcut, isRecording: recording == item.run, words: recordingWords, keys: keys)
            }
            if item.isToggle {
                RowSwitch(isOn: item.isOn)
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

private struct RowBars: View {
    let bars: [Double?]
    let tone: MetricValue.Tone?

    var body: some View {
        HStack(alignment: .bottom, spacing: SpotTokens.rowBarGap) {
            ForEach(bars.indices, id: \.self) { index in
                Rectangle()
                    .fill(bars[index].map { $0 > 0 ? colour : SpotTheme.ink.opacity(SpotTheme.fill) } ?? SpotTheme.ink.opacity(SpotTheme.fill))
                    .frame(width: SpotTokens.rowBarWidth, height: max(SpotTokens.rowBarFloor, SpotTokens.rowBarHeight * (bars[index] ?? 0)))
            }
        }
        .frame(height: SpotTokens.rowBarHeight, alignment: .bottom)
    }

    private var colour: Color {
        tone.map(SpotMetricView.colour) ?? SpotTheme.ink
    }
}

private struct RowSwitch: View {
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

private struct RowDetail: View {
    let text: String?
    let focus: String
    let run: String
    let selectedRun: () -> String?

    var body: some View {
        Text(selectedRun() == run ? focus : text ?? "")
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            .lineLimit(1)
    }
}

private struct RowsFade: ViewModifier {
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

private struct BentoRing: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let selection: () -> Int
    let count: Int
    let drawing: RepeatDrawing
    let step: CGFloat

    var body: some View {
        let index = selection()
        if index < count {
            let area = drawing.area(of: index)
            let size = SpotRowsView.size(of: area, step: step)
            Color.clear
                .frame(width: size.width, height: size.height)
                .modifier(SpotSelectionRing(isSelected: true, shape: SpotRoundShape(surface.inner()), marksMenu: true))
                .offset(x: CGFloat(area.x0) * step, y: CGFloat(area.y0) * step)
        }
    }
}

private struct RowsFollow: ViewModifier {
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
