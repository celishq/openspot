import OpenspotCore
import SwiftUI

/// The rows of a script, one on each line or as square buttons, which scroll when they do not fit.
struct SpotRowsView: View {
    let list: ItemList
    var recording: String?
    /// The words of the key that records.
    var recordingWords = "Press keys"
    let onRun: (SpotItem) -> Void
    /// Takes the row that the pointer moves onto.
    var onPoint: (SpotItem) -> Void = { _ in }
    /// Reads the selected row where it is called. Nil reads it from the list.
    var selection: (() -> Int)?
    /// Takes the rows whose files a drag took out to another app (protocol: Files out).
    var onDragOut: ([SpotItem]) -> Void = { _ in }

    private static let bottomFade = 2 * SpotTokens.padding

    private var row: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
    }

    private var selected: () -> Int {
        selection ?? { [list] in list.selected }
    }

    /// Reads the run of the selected row where it is called, so that a row's ring needs no index.
    private var selectedRun: () -> String? {
        { [list, selected] in
            let index = selected()
            return list.shown.indices.contains(index) ? list.shown[index].run : nil
        }
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

    /// The rows that stay above or under the rows that scroll, such as the key of a spot's command.
    private func pinned(_ pin: SpotItem.Pin) -> some View {
        ForEach(pin == .top ? list.pinnedTop : list.pinnedBottom, id: \.run) { item in
            Button { onRun(item) } label: { rowLabel(item) }
                .buttonStyle(.plain)
        }
    }

    private var emptyText: String {
        if list.isWaiting { return "Searching" }
        if list.isLoading { return "Loading…" }
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
        SpotTokens.sheetFits(rows: list.shown.count, perLine: list.perLine) ? SpotTokens.padding : Self.bottomFade
    }

    /// The rows between the pinned rows, which fill exactly the room between them, with no margin or fade to reach past it.
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

    /// The rows of a bento: the drawing of the repeat, tile under tile, with each row drawn at the size of its place.
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
                .frame(width: SheetPlacement.width, height: max(CGFloat(lines) * step - SpotTokens.listRowGap, 0), alignment: .topLeading)
                .padding(.top, SpotTokens.padding)
                .padding(.bottom, bottomInset)
            }
            .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy, motion: SpotMotion.move))
        }
    }

    /// The size of a tile that covers an area of the drawing, whose cells lie a step apart.
    fileprivate static func size(of area: SheetArea, step: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(area.x1 - area.x0 + 1) * step - SpotTokens.listRowGap,
            height: CGFloat(area.y1 - area.y0 + 1) * step - SpotTokens.listRowGap
        )
    }

    private func bentoCell(_ item: SpotItem, size: CGSize) -> some View {
        SpotItemIcon(item: item, size: min(size.width, size.height) * 0.5)
            .overlay(alignment: .bottomTrailing) { SpotToneDot(tone: item.tone, side: min(size.width, size.height) * 0.5) }
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
        HStack(spacing: SpotTokens.padding - 5) {
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
            if let shortcut = item.shortcut {
                SpotKeyLabel(text: shortcut, isRecording: recording == item.run, recordingWords: recordingWords)
            }
            if item.isOn {
                Image(systemName: "checkmark")
                    .font(SpotType.body.weight(.semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpotTokens.padding)
        .frame(height: SpotTokens.listRowHeight)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: row)
        .modifier(SpotLiveSelectionRing(isSelected: { [selectedRun, run = item.run] in selectedRun() == run }, shape: row, marksMenu: true))
        .contentShape(row)
    }
}

/// The second line of a row that says another thing while it is selected. It alone reads the selection, so that a move
/// redraws only it.
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

/// The fade at each end of the rows as they scroll. It alone holds how far each end fades, so that a scroll near an end
/// reruns no row.
private struct RowsFade: ViewModifier {
    let bottom: CGFloat
    @State private var edges = SpotScrollEdges()

    func body(content: Content) -> some View {
        content
            .modifier(SpotScrollEdgeTracker(edges: $edges))
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(1 - edges.top), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: SpotTokens.padding)
                    Color.black
                    LinearGradient(colors: [.black, .black.opacity(1 - edges.bottom)], startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom)
                }
            }
    }
}

/// The one ring of a bento, over the tile of the selected row. It alone reads the selection, so that a move redraws no tile.
private struct BentoRing: View {
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
                .modifier(SpotSelectionRing(isSelected: true, shape: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous), marksMenu: true))
                .offset(x: CGFloat(area.x0) * step, y: CGFloat(area.y0) * step)
        }
    }
}

/// Scrolls the rows until the selected row shows. It alone reads the selection, so that a move reruns only this modifier.
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
