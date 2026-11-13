import OpenspotCore
import SwiftUI

/// The rows of a sheet as square buttons, placed by hand. It builds only the lines near the visible band, each cell in a slot
/// that it keeps while the grid scrolls, and one tap, hover and drag on the whole grid find the cell under the pointer. A
/// search that lands scrolls it to the top in the same update as its rows.
struct SpotRowGrid: View {
    let list: ItemList
    let selection: () -> Int
    let bottomInset: CGFloat
    let bottomFade: CGFloat
    let onRun: (SpotItem) -> Void
    let onPoint: (SpotItem) -> Void
    let onDragOut: ([SpotItem]) -> Void
    @State private var reading = GridReading()
    /// Counts the changes of the band and of the aim, so that each one updates the grid. No measure changes it while the
    /// grid's own scroll moves.
    @State private var moves = 0

    /// How many cells of a new search draw their pictures ahead: more than a sheet shows.
    private static let drawnAhead = 120

    var body: some View {
        let _ = moves
        let _ = reading.land(list.landedSearches)
        let perLine = list.perLine
        let side = SpotTokens.square(perLine: perLine)
        let step = side + SpotTokens.listRowGap
        let count = list.shown.count
        let lineCount = (count + perLine - 1) / perLine
        let bandLines = SpotTokens.firstScreen(perLine: perLine) / perLine + 2
        let slots = 2 * bandLines * perLine
        let band = reading.band(lines: bandLines)
        let first = band.lowerBound * perLine
        let end = min(band.upperBound * perLine, first + slots, count)
        ScrollView(showsIndicators: false) {
            GridPlacement(perLine: perLine, side: side) {
                ForEach(0..<slots, id: \.self) { slot in
                    let index = first + (slot - first % slots + slots) % slots
                    if index < end {
                        let item = list.shown[index]
                        SpotGridCell(item: item, side: side)
                            .equatable()
                            .accessibilityAction { onRun(item) }
                            .layoutValue(key: CellIndex.self, value: index)
                    }
                }
            }
            .frame(width: SheetPlacement.width, height: max(CGFloat(lineCount) * step - SpotTokens.listRowGap, 0), alignment: .topLeading)
            .overlay(alignment: .topLeading) { GridRing(selection: selection, count: count, perLine: perLine, side: side) }
            .contentShape(Rectangle())
            .onTapGesture { point in
                if let item = item(at: point, step: step, side: side) { onRun(item) }
            }
            .onContinuousHover { phase in
                if case .active(let point) = phase { reading.pointer = point }
            }
            .modifier(SpotPointerMove {
                if let point = reading.pointer, let item = item(at: point, step: step, side: side) { onPoint(item) }
            })
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                guard !reading.isDragging, let item = item(at: value.startLocation, step: step, side: side), let file = item.file else { return }
                reading.isDragging = SpotFileDrag.begin([file], onDrop: { onDragOut([item]) }, onEnd: { reading.isDragging = false })
            }, isEnabled: list.hasFiles)
            .padding(.top, SpotTokens.padding)
            .padding(.bottom, bottomInset)
        }
        .scrollPosition(Binding(get: { reading.position }, set: { reading.position = $0 }))
        .onScrollGeometryChange(for: CGSize.self, of: { CGSize(width: $0.containerSize.height, height: $0.contentSize.height) }, action: { _, size in
            reading.viewHeight = size.width
            reading.contentHeight = size.height
        })
        .onScrollGeometryChange(for: Int.self, of: { Int(max($0.contentOffset.y - SpotTokens.padding, 0) / step) }, action: { _, lines in
            if reading.pass(lines, bandLines: bandLines) { moves &+= 1 }
        })
        .onScrollPhaseChange { _, phase, context in
            if phase != .animating { reading.isMoving = false }
            guard phase == .idle else { return }
            reading.aim = context.geometry.contentOffset.y
            if reading.pass(Int(max(reading.aim - SpotTokens.padding, 0) / step), bandLines: bandLines) { moves &+= 1 }
        }
        .modifier(GridFollow(selection: selection, items: list.shown, perLine: perLine, bandLines: bandLines, bottomFade: bottomFade, reading: reading, moves: $moves))
        .onChange(of: list.landedSearches, initial: true) {
            let ahead = list.shown.prefix(Self.drawnAhead)
            if reading.newAhead(ahead) { SpotItemIcon.prepare(ahead, size: SpotTokens.listIconSize) }
        }
    }

    /// The row whose cell holds this point of the grid, or nil in a gap or past the last row.
    private func item(at point: CGPoint, step: CGFloat, side: CGFloat) -> SpotItem? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let column = Int(point.x / step)
        let line = Int(point.y / step)
        let index = line * list.perLine + column
        guard column < list.perLine, point.x - CGFloat(column) * step <= side, point.y - CGFloat(line) * step <= side,
              list.shown.indices.contains(index) else { return nil }
        return list.shown[index]
    }
}

/// The layout of the cells of the grid: each at the place of its index, at the size of a square. It takes the size it is
/// offered, and measures no cell and asks no cell for its alignment.
private struct GridPlacement: Layout {
    let perLine: Int
    let side: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGFloat? {
        nil
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let step = side + SpotTokens.listRowGap
        for subview in subviews {
            let index = subview[CellIndex.self]
            let place = CGPoint(x: bounds.minX + CGFloat(index % perLine) * step, y: bounds.minY + CGFloat(index / perLine) * step)
            subview.place(at: place, anchor: .topLeading, proposal: ProposedViewSize(width: side, height: side))
        }
    }
}

/// The index of the row that a cell of the grid shows.
private struct CellIndex: LayoutValueKey {
    static let defaultValue = 0
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
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(.isButton)
    }
}

/// What the grid last knew of its scroll view, kept out of observation so that a scroll redraws nothing: its sizes, its aim,
/// the position it asks of the scroll view, the band of lines it builds, the pointer, and the rows whose pictures it drew ahead.
@MainActor
private final class GridReading {
    var viewHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
    var aim: CGFloat = 0
    var position = ScrollPosition(edge: .top)
    var isDragging = false
    /// Whether the grid's own scroll moves, while which no measure changes the band.
    var isMoving = false
    /// Where the pointer last lay over the grid.
    var pointer: CGPoint?
    private var built: Range<Int>?
    private var landed: Int?
    private var ahead: [String] = []

    /// The lines that the grid builds: those it was given, or else the first band.
    func band(lines: Int) -> Range<Int> {
        built ?? 0..<lines
    }

    /// Scrolls to the top when a search landed since the last call.
    func land(_ searches: Int) {
        guard searches != landed else { return }
        landed = searches
        aim = 0
        built = nil
        position = ScrollPosition(y: 0)
    }

    /// Builds the band around the lines the scroll has passed, unless the grid's own scroll moves. Returns whether it changed.
    func pass(_ lines: Int, bandLines: Int) -> Bool {
        guard !isMoving else { return false }
        let next = Self.band(around: lines, bandLines: bandLines)
        guard next != band(lines: bandLines) else { return false }
        built = next
        return true
    }

    /// Builds the lines from the band around the last aim to the band around the next, when they span at most two bands, and
    /// returns true. A longer jump builds only the next band and returns false, so that the scroll lands at once.
    func aim(from last: Int, to lines: Int, bandLines: Int) -> Bool {
        let target = Self.band(around: lines, bandLines: bandLines)
        let now = Self.band(around: last, bandLines: bandLines)
        let both = min(now.lowerBound, target.lowerBound)..<max(now.upperBound, target.upperBound)
        built = both.count <= 2 * bandLines ? both : target
        return both.count <= 2 * bandLines
    }

    private static func band(around lines: Int, bandLines: Int) -> Range<Int> {
        let first = max(lines - 1, 0)
        return first..<(first + bandLines)
    }

    /// Whether these rows differ from those whose pictures were last drawn ahead, and keeps them when they do.
    func newAhead(_ rows: ArraySlice<SpotItem>) -> Bool {
        guard !rows.elementsEqual(ahead, by: { $0.run == $1 }) else { return false }
        ahead = rows.map(\.run)
        return true
    }
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
                .allowsHitTesting(false)
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
    let bandLines: Int
    let bottomFade: CGFloat
    let reading: GridReading
    @Binding var moves: Int

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
        let lineAt = { (offset: CGFloat) in Int(max(offset - SpotTokens.padding, 0) / (side + SpotTokens.listRowGap)) }
        let glides = reading.aim(from: lineAt(reading.aim), to: lineAt(offset), bandLines: bandLines)
        reading.aim = offset
        reading.position.scrollTo(y: offset)
        reading.isMoving = glides
        var change = Transaction(animation: glides ? SpotMotion.move : nil)
        change.disablesAnimations = !glides
        withTransaction(change) { moves &+= 1 }
    }
}
