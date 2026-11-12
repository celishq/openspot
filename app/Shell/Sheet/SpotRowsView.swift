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
    @State private var position = ScrollPosition(edge: .top)
    @State private var reading = GridScrollReading()

    private static let bottomFade = 2 * SpotTokens.padding
    /// How many cells of a new search draw their pictures ahead: more than a sheet shows.
    private static let drawnAhead = 120

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
        } else {
            scroll
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
            if list.isBento { bentoScroll } else if isGrid { gridScroll } else { lineScroll }
        }
        .modifier(RowsFade(bottom: Self.bottomFade))
        .padding(.vertical, -SpotTokens.padding)
    }

    private var bottomInset: CGFloat {
        SpotTokens.sheetFits(rows: list.shown.count, perLine: list.perLine) ? SpotTokens.padding : Self.bottomFade
    }

    private var lineScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) { lines }
                .safeAreaPadding(.top, SpotTokens.padding)
                .safeAreaPadding(.bottom, bottomInset)
                .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy))
                .onChange(of: list.query) {
                    guard let run = list.shown.first?.run else { return }
                    DispatchQueue.main.async { proxy.scrollTo(run, anchor: .top) }
                }
        }
    }

    /// The grid, which scrolls by offsets worked out from the index of the selected cell, with its margins inside.
    private var gridScroll: some View {
        ScrollView(showsIndicators: false) {
            buttons
                .padding(.top, SpotTokens.padding)
                .padding(.bottom, bottomInset)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGSize.self, of: { CGSize(width: $0.containerSize.height, height: $0.contentSize.height) }, action: { _, size in
            reading.viewHeight = size.width
            reading.contentHeight = size.height
        })
        .onScrollPhaseChange { _, phase, context in
            if phase == .idle { reading.aim = context.geometry.contentOffset.y }
        }
        .modifier(GridFollow(selection: selected, items: list.shown, perLine: list.perLine, bottomFade: Self.bottomFade, position: $position, reading: reading))
        .onChange(of: list.query, initial: true) {
            reading.aim = 0
            position.scrollTo(y: 0)
            SpotItemIcon.prepare(list.shown.prefix(Self.drawnAhead), size: SpotTokens.listIconSize)
        }
    }

    private var lines: some View {
        LazyVStack(spacing: SpotTokens.listRowGap) {
            ForEach(list.shown, id: \.run) { item in
                Button {
                    onRun(item)
                } label: {
                    rowLabel(item)
                }
                .buttonStyle(.plain)
                .modifier(SpotPointerMove { onPoint(item) })
                .modifier(SpotFileDragSource(items: [item], onDrop: onDragOut))
            }
        }
    }

    private var buttons: some View {
        let side = SpotTokens.square(perLine: list.perLine)
        let columns = Array(repeating: GridItem(.fixed(side), spacing: SpotTokens.listRowGap), count: list.perLine)
        return LazyVGrid(columns: columns, spacing: SpotTokens.listRowGap) {
            ForEach(list.shown.indices, id: \.self) { index in
                let item = list.shown[index]
                SpotGridCell(item: item, side: side)
                    .equatable()
                    .onTapGesture { onRun(item) }
                    .modifier(SpotPointerMove { onPoint(item) })
                    .modifier(SpotFileDragSource(items: [item], onDrop: onDragOut))
            }
        }
        .overlay(alignment: .topLeading) { GridRing(selection: selected, count: list.shown.count, perLine: list.perLine, side: side) }
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
            .modifier(RowsFollow(selection: selected, items: list.shown, proxy: proxy, motion: SpotMotion.arrowScroll))
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
        .modifier(SpotFileDragSource(items: [item], onDrop: onDragOut))
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
                if let subtitle = item.subtitle {
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
        .modifier(RowRing(run: item.run, selectedRun: selectedRun, shape: row))
        .contentShape(row)
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

/// The ring of one row. It reads the selection itself, so that a move reruns the rings and no row.
private struct RowRing: ViewModifier {
    let run: String
    let selectedRun: () -> String?
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: selectedRun() == run, shape: shape, marksMenu: true))
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

/// One square of the grid. It depends on its item alone, so that a move of the selection leaves it as it is.
private struct SpotGridCell: View, Equatable {
    let item: SpotItem
    let side: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous)
        SpotItemIcon(item: item, size: SpotTokens.listIconSize)
            .overlay(alignment: .bottomTrailing) { SpotToneDot(tone: item.tone, side: SpotTokens.listIconSize) }
            .frame(width: side, height: side)
            .background(SpotTheme.ink.opacity(SpotTheme.fill), in: shape)
            .contentShape(shape)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(.isButton)
    }
}

/// What the grid last knew of its scroll view, kept out of observation so that a scroll redraws nothing.
@MainActor
private final class GridScrollReading {
    var viewHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    var aim: CGFloat = 0
}

/// The one ring of the grid, over the selected cell. It alone reads the selection, so that a move redraws no cell.
private struct GridRing: View {
    let selection: () -> Int
    let count: Int
    let perLine: Int
    let side: CGFloat

    var body: some View {
        let index = selection()
        if index < count {
            let step = side + SpotTokens.listRowGap
            Color.clear
                .frame(width: side, height: side)
                .modifier(SpotSelectionRing(
                    isSelected: true,
                    shape: RoundedRectangle(cornerRadius: SpotTokens.radius - SpotTokens.padding, style: .continuous),
                    width: SpotSelectionRing<RoundedRectangle>.thinWidth,
                    marksMenu: true
                ))
                .offset(x: CGFloat(index % perLine) * step, y: CGFloat(index / perLine) * step)
        }
    }
}

/// Scrolls the grid until the line of the selected cell lies clear of the fades at its two ends. It alone reads the
/// selection, so that a move reruns only this modifier.
private struct GridFollow: ViewModifier {
    private static let linesAhead = 10

    let selection: () -> Int
    let items: [SpotItem]
    let perLine: Int
    let bottomFade: CGFloat
    @Binding var position: ScrollPosition
    let reading: GridScrollReading

    func body(content: Content) -> some View {
        content.onChange(of: selection()) { _, index in show(index) }
    }

    private func show(_ index: Int) {
        let line = index / perLine * perLine
        SpotItemIcon.prepare(items[min(line, items.count)..<min(line + Self.linesAhead * perLine, items.count)], size: SpotTokens.listIconSize)
        guard reading.viewHeight > 0 else { return }
        let side = SpotTokens.square(perLine: perLine)
        let top = SpotTokens.padding + CGFloat(index / perLine) * (side + SpotTokens.listRowGap)
        let window = ScrollWindow(
            top: SpotTokens.padding,
            bottom: reading.viewHeight - bottomFade,
            viewHeight: reading.viewHeight,
            contentHeight: reading.contentHeight
        )
        let offset = window.offset(showing: top...(top + side), from: reading.aim)
        guard offset != reading.aim else { return }
        reading.aim = offset
        withAnimation(SpotMotion.arrowScroll) { position.scrollTo(y: offset) }
    }
}
