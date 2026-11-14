import AppKit
import SwiftUI

/// A tool of the pen. The cursor is the state of no tool: it grabs a mark under the mouse to move or shape it, and
/// lets every other click through to the apps. The others draw ink, an arrow or a line, a shape, place text, or erase
/// whole marks.
enum PenTool {
    case select, pen, arrow, shape, text, eraser
}

/// What a mark is: freehand ink, a line with two ends and a bend and a head at none, one or both ends, a rectangle or
/// an ellipse between two corners, or text from its top-left corner.
enum Kind: Equatable {
    case ink, arrow, doubleArrow, line, rectangle, ellipse, text

    var isLine: Bool { self == .arrow || self == .doubleArrow || self == .line }
    var isShape: Bool { self == .rectangle || self == .ellipse }
}

/// The stroke of a mark.
enum Dash: CaseIterable {
    case solid, dashed, dotted
}

/// How much colour fills a shape.
enum Fill: CaseIterable {
    case none, semi, solid
}

/// One mark on the screen, in global screen points. A line has its start and end, and a bend: how far the middle of
/// its curve sits from the straight line, to its left. A shape has two opposite corners.
struct Mark: Equatable {
    var points: [CGPoint]
    var color: NSColor
    var kind: Kind
    var dash = Dash.solid
    var fill = Fill.none
    var bend: CGFloat = 0
    var text = ""
    var size: CGFloat = 28

    static func font(_ size: CGFloat) -> NSFont {
        let font = NSFont.systemFont(ofSize: size, weight: .semibold)
        return font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? font
    }

    /// The text with its font and colour.
    var styledText: NSAttributedString {
        NSAttributedString(string: text.isEmpty ? " " : text, attributes: [.font: Self.font(size), .foregroundColor: color])
    }

    /// The box of a text, which hangs down from its top-left corner.
    var textRect: CGRect {
        let measure = styledText.size()
        return CGRect(x: points[0].x, y: points[0].y - measure.height, width: measure.width, height: measure.height)
    }

    /// The rectangle between a shape's two corners.
    var rect: CGRect {
        let a = points[0], b = points[points.count - 1]
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// The middle of the straight line from start to end, and the unit normal to its left.
    var chord: (mid: CGPoint, normal: CGVector) {
        let s = points[0], e = points[points.count - 1]
        let length = max(hypot(e.x - s.x, e.y - s.y), 0.001)
        return (CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2), CGVector(dx: -(e.y - s.y) / length, dy: (e.x - s.x) / length))
    }

    /// The point in the middle of the line's curve, where its bend grip sits.
    var curveMid: CGPoint {
        let (mid, normal) = chord
        return CGPoint(x: mid.x + normal.dx * bend, y: mid.y + normal.dy * bend)
    }

    /// The control point of the line's quadratic curve.
    var control: CGPoint {
        let (mid, _) = chord, top = curveMid
        return CGPoint(x: 2 * top.x - mid.x, y: 2 * top.y - mid.y)
    }

    /// The point at `t` from 0 to 1 along the line's curve.
    func curve(at t: CGFloat) -> CGPoint {
        let s = points[0], e = points[points.count - 1], c = control
        let u = 1 - t
        return CGPoint(x: u * u * s.x + 2 * u * t * c.x + t * t * e.x, y: u * u * s.y + 2 * u * t * c.y + t * t * e.y)
    }

    /// The points that trace the mark's outline in short steps.
    var trace: [CGPoint] {
        switch kind {
        case .ink:
            return points
        case .arrow, .doubleArrow, .line:
            return (0...32).map { curve(at: CGFloat($0) / 32) }
        case .rectangle, .text:
            let r = kind == .text ? textRect : rect
            return [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY)]
        case .ellipse:
            let r = rect
            return (0...48).map {
                let angle = CGFloat($0) / 48 * 2 * .pi
                return CGPoint(x: r.midX + r.width / 2 * cos(angle), y: r.midY + r.height / 2 * sin(angle))
            }
        }
    }

    /// The box around the mark, with room for its ink.
    var bounds: CGRect {
        let line = trace, xs = line.map(\.x), ys = line.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(dx: -Board.width, dy: -Board.width)
    }

    /// Whether the point lies within `slack` of the mark's ink, or inside a filled shape.
    func hit(_ point: CGPoint, slack: CGFloat) -> Bool {
        if kind == .text { return textRect.insetBy(dx: -slack / 2, dy: -slack / 2).contains(point) }
        if kind.isShape, fill != .none {
            let r = rect
            if kind == .rectangle, r.contains(point) { return true }
            if kind == .ellipse, r.width > 0, r.height > 0 {
                let x = (point.x - r.midX) / (r.width / 2), y = (point.y - r.midY) / (r.height / 2)
                if x * x + y * y <= 1 { return true }
            }
        }
        let line = trace
        guard let first = line.first else { return false }
        if line.count == 1 { return hypot(point.x - first.x, point.y - first.y) <= slack }
        return zip(line, line.dropFirst()).contains { Self.distance(point, $0, $1) <= slack }
    }

    func moved(by dx: CGFloat, _ dy: CGFloat) -> Mark {
        var mark = self
        mark.points = points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        return mark
    }

    func scaled(from anchor: CGPoint, by scale: CGFloat) -> Mark {
        var mark = self
        mark.points = points.map { CGPoint(x: anchor.x + ($0.x - anchor.x) * scale, y: anchor.y + ($0.y - anchor.y) * scale) }
        mark.bend = bend * scale
        mark.size = max(8, size * scale)
        return mark
    }

    private static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }
}

/// The style strip under the toolbar: for lines, or for shapes.
enum Strip {
    case line, shape
}

/// A grip of the selected mark: an end or the bend of a line, or a corner of a shape or of the box of freehand ink. A
/// shape's corner moves freely; ink scales from the opposite corner.
enum Grip: Equatable {
    case end(Int)
    case bend
    case corner(CGPoint, anchor: CGPoint)
}

/// The text box that is open: on the mark at `index`, or new at `origin`.
struct Editing {
    var index: Int?
    var origin: CGPoint
    var size: CGFloat
    var color: NSColor
}

/// What the cursor holds while the mouse is down.
enum Grab {
    case move(start: CGPoint, original: Mark)
    case grip(Grip, original: Mark)
}

/// The drawing that every screen shows. It lives only as long as the process, so closing it erases everything.
final class Board: ObservableObject {
    static let colors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1),
        NSColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1),
    ]
    static let width: CGFloat = 4
    static let gripSize: CGFloat = 10

    static let eraserCursor: NSCursor = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            NSColor.white.withAlphaComponent(0.6).setFill()
            ring.fill()
            NSColor.black.withAlphaComponent(0.8).setStroke()
            ring.lineWidth = 1.5
            ring.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()

    @Published var tool = PenTool.pen {
        didSet {
            if tool != .select { selected = nil }
            if editing != nil, tool != .text { commitText() }
            cursor.set()
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
                canvases.first { $0.window?.frame.contains(NSEvent.mouseLocation) == true }?.window?.makeKey()
            }
            follow()
            redraw()
        }
    }
    @Published var color = 0
    @Published var lineKind = Kind.arrow
    @Published var shapeKind = Kind.rectangle
    @Published var dash = Dash.solid
    @Published var fill = Fill.none
    @Published var editing: Editing?
    var marks: [Mark] = []
    var history: [[Mark]] = []
    var future: [[Mark]] = []
    var live: Mark?
    var selected: Int?
    var grab: Grab?
    var erasing: CGPoint?
    var canvases: [Canvas] = []

    /// The pointer of the tool over the canvas.
    var cursor: NSCursor {
        switch tool {
        case .select: .arrow
        case .text: .iBeam
        case .eraser: Self.eraserCursor
        case .pen, .arrow, .shape: .crosshair
        }
    }

    /// The selected mark, if any.
    var selection: Mark? {
        guard let index = selected, marks.indices.contains(index) else { return nil }
        return marks[index]
    }

    /// The style strip that shows: for the selected mark, else for the tool.
    var strip: Strip? {
        if let mark = selection {
            return mark.kind.isLine ? .line : mark.kind.isShape ? .shape : nil
        }
        return tool == .arrow ? .line : tool == .shape ? .shape : nil
    }

    /// The kind, stroke and fill the strip marks as chosen: the selected mark's, else the next mark's.
    var shownKind: Kind { selection?.kind ?? (strip == .shape ? shapeKind : lineKind) }
    var shownDash: Dash { selection?.dash ?? dash }
    var shownFill: Fill { selection?.fill ?? fill }
    var shownColor: Int { selection.flatMap { mark in Self.colors.firstIndex(of: mark.color) } ?? color }

    /// Picks a colour for the next marks and for the selected one.
    func pick(color index: Int) {
        color = index
        if editing != nil {
            editing?.color = Self.colors[index]
            canvases.forEach { $0.recolorEditor(Self.colors[index]) }
        }
        restyle { $0.color = Self.colors[index] }
    }

    /// Picks the kind of the next line or shape, and of the selected one when it is the same sort.
    func pick(kind: Kind) {
        if kind.isLine { lineKind = kind } else { shapeKind = kind }
        restyle { mark in
            if mark.kind.isLine == kind.isLine, mark.kind.isShape == kind.isShape { mark.kind = kind }
        }
    }

    func pick(dash: Dash) {
        self.dash = dash
        restyle { if $0.kind != .ink { $0.dash = dash } }
    }

    func pick(fill: Fill) {
        self.fill = fill
        restyle { if $0.kind.isShape { $0.fill = fill } }
    }

    private func restyle(_ change: (inout Mark) -> Void) {
        guard let index = selected, marks.indices.contains(index) else { return redraw() }
        var mark = marks[index]
        change(&mark)
        guard mark != marks[index] else { return redraw() }
        record()
        marks[index] = mark
        redraw()
    }

    /// Whether the canvas takes a press at the point: always while a drawing tool is on, and with the cursor only on a
    /// mark or a grip, so that every other click goes to the apps.
    func wants(_ point: CGPoint) -> Bool {
        guard tool == .select, grab == nil, editing == nil else { return true }
        return grips().contains { hypot($0.at.x - point.x, $0.at.y - point.y) <= Self.gripSize }
            || marks.contains { $0.hit(point, slack: Self.width / 2 + 8) }
    }

    /// Lets the mouse through each canvas, or takes it, by what lies under the pointer now.
    func follow() {
        let take = wants(NSEvent.mouseLocation)
        for canvas in canvases where canvas.window?.ignoresMouseEvents == take {
            canvas.window?.ignoresMouseEvents = !take
        }
    }

    func beginErase(at point: CGPoint) {
        record()
        erasing = point
        erase(to: point)
    }

    /// Removes each mark that the eraser crosses on its way from its last place to the point.
    func erase(to point: CGPoint) {
        guard let last = erasing else { return }
        let steps = max(1, Int(hypot(point.x - last.x, point.y - last.y) / 4))
        let path = (0...steps).map { CGPoint(x: last.x + (point.x - last.x) * CGFloat($0) / CGFloat(steps), y: last.y + (point.y - last.y) * CGFloat($0) / CGFloat(steps)) }
        let count = marks.count
        marks.removeAll { mark in path.contains { mark.hit($0, slack: Self.width / 2 + 6) } }
        erasing = point
        if marks.count != count { redraw() }
    }

    func endErase() {
        erasing = nil
        if history.last == marks { history.removeLast() }
        redraw()
    }

    /// Starts a mark of the tool; Shift on the pen starts an arrow.
    func begin(at point: CGPoint, arrow: Bool) {
        let kind: Kind = switch tool {
        case .arrow: lineKind
        case .shape: shapeKind
        default: arrow ? .arrow : .ink
        }
        live = Mark(points: [point], color: Self.colors[color], kind: kind, dash: kind == .ink ? .solid : dash, fill: kind.isShape ? fill : .none)
    }

    /// Grows the mark to the point; `square` keeps a shape's sides equal.
    func extend(to point: CGPoint, square: Bool = false) {
        guard var mark = live else { return }
        if mark.kind == .ink {
            mark.points.append(point)
        } else if mark.kind.isShape, square {
            let start = mark.points[0]
            let side = max(abs(point.x - start.x), abs(point.y - start.y))
            mark.points = [start, CGPoint(x: start.x + (point.x < start.x ? -side : side), y: start.y + (point.y < start.y ? -side : side))]
        } else {
            mark.points = [mark.points[0], point]
        }
        live = mark
        redraw()
    }

    func end() {
        guard let mark = live else { return }
        live = nil
        guard mark.kind == .ink || hypot(mark.points[0].x - mark.points[1].x, mark.points[0].y - mark.points[1].y) > 3 else {
            redraw()
            return
        }
        record()
        marks.append(mark)
        redraw()
    }

    /// The box drawn around a selected shape, text or freehand ink. A line shows only its grips.
    func selectionBox() -> CGRect? {
        guard let mark = selection, !mark.kind.isLine else { return nil }
        return mark.kind.isShape ? mark.rect : mark.bounds.insetBy(dx: -6, dy: -6)
    }

    /// Opens a text box: on the text mark at `index`, or a new one at the point.
    func edit(at point: CGPoint, index: Int?) {
        if editing != nil { commitText() }
        let mark = index.map { marks[$0] }
        let open = Editing(index: index, origin: mark?.points[0] ?? point, size: mark?.size ?? 28, color: mark?.color ?? Self.colors[color])
        editing = open
        selected = nil
        let canvas = canvases.first { $0.window?.frame.contains(open.origin) == true } ?? canvases.first
        canvas?.openEditor(text: mark?.text ?? "", open)
        redraw()
    }

    /// Keeps the typed text as a mark, drops an empty one, and goes back to the cursor from the text tool.
    func commitText() {
        guard let open = editing else { return }
        let text = canvases.compactMap { $0.closeEditor() }.first ?? ""
        editing = nil
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let index = open.index, marks.indices.contains(index) {
            if empty {
                record()
                marks.remove(at: index)
            } else if marks[index].text != text || marks[index].color != open.color {
                record()
                marks[index].text = text
                marks[index].color = open.color
            }
        } else if !empty {
            record()
            marks.append(Mark(points: [open.origin], color: open.color, kind: .text, text: text, size: open.size))
        }
        if tool == .text { tool = .select }
        redraw()
    }

    /// The grips of the selected mark, each at its place on the screen.
    func grips() -> [(grip: Grip, at: CGPoint)] {
        guard let index = selected, marks.indices.contains(index) else { return [] }
        let mark = marks[index]
        if mark.kind.isLine {
            return [(.end(0), mark.points[0]), (.bend, mark.curveMid), (.end(1), mark.points[1])]
        }
        guard let box = selectionBox() else { return [] }
        let corners = [
            CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY),
        ]
        return corners.indices.map { (.corner(corners[$0], anchor: corners[($0 + 2) % 4]), corners[$0]) }
    }

    /// Takes a grip of the selected mark, or the mark under the point; a press on nothing drops the selection.
    func press(at point: CGPoint) {
        if let index = selected, let grip = grips().first(where: { hypot($0.at.x - point.x, $0.at.y - point.y) <= Self.gripSize }) {
            record()
            grab = .grip(grip.grip, original: marks[index])
        } else if let index = marks.indices.last(where: { marks[$0].hit(point, slack: Self.width / 2 + 8) }) {
            selected = index
            record()
            grab = .move(start: point, original: marks[index])
        } else {
            selected = nil
        }
        redraw()
    }

    func drag(to point: CGPoint) {
        guard let index = selected, let grab else { return }
        switch grab {
        case let .move(start, original):
            marks[index] = original.moved(by: point.x - start.x, point.y - start.y)
        case let .grip(.end(end), original):
            var mark = original
            mark.points[end] = point
            marks[index] = mark
        case let .grip(.bend, original):
            var mark = original
            let (mid, normal) = original.chord
            mark.bend = (point.x - mid.x) * normal.dx + (point.y - mid.y) * normal.dy
            if abs(mark.bend) < 4 { mark.bend = 0 }
            marks[index] = mark
        case let .grip(.corner(_, anchor), original) where original.kind.isShape:
            var mark = original
            mark.points = [anchor, point]
            marks[index] = mark
        case let .grip(.corner(corner, anchor), original):
            let dx = corner.x - anchor.x, dy = corner.y - anchor.y
            let scale = ((point.x - anchor.x) * dx + (point.y - anchor.y) * dy) / max(dx * dx + dy * dy, 1)
            marks[index] = original.scaled(from: anchor, by: max(0.1, scale))
        }
        redraw()
    }

    func release() {
        guard grab != nil else { return }
        grab = nil
        if history.last == marks { history.removeLast() }
        redraw()
    }

    func nudge(_ dx: CGFloat, _ dy: CGFloat) {
        guard let index = selected else { return }
        record()
        marks[index] = marks[index].moved(by: dx, dy)
        redraw()
    }

    func deleteSelected() {
        guard let index = selected else { return }
        record()
        marks.remove(at: index)
        selected = nil
        redraw()
    }

    func undo() {
        guard let last = history.popLast() else { return }
        future.append(marks)
        marks = last
        selected = nil
        redraw()
    }

    func redo() {
        guard let next = future.popLast() else { return }
        history.append(marks)
        marks = next
        selected = nil
        redraw()
    }

    func clear() {
        guard !marks.isEmpty else { return }
        record()
        marks.removeAll()
        selected = nil
        redraw()
    }

    func redraw() {
        objectWillChange.send()
        canvases.forEach { $0.needsDisplay = true }
    }

    private func record() {
        history.append(marks)
        future.removeAll()
    }
}

/// The clear sheet over one screen, which takes the mouse and draws every mark.
final class Canvas: NSView, NSTextViewDelegate {
    let board: Board
    private var handling = false
    private var editor: NSTextView?
    private var editorTop = CGPoint.zero

    init(board: Board) {
        self.board = board
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .cursorUpdate, .inVisibleRect], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        board.cursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        board.cursor.set()
    }

    /// Places a text box with its top-left corner at the open text's origin, and gives it the keys.
    func openEditor(text: String, _ open: Editing) {
        guard let window else { return }
        let view = NSTextView(frame: .zero)
        view.isRichText = false
        view.allowsUndo = true
        view.drawsBackground = false
        view.font = Mark.font(open.size)
        view.textColor = open.color
        view.insertionPointColor = open.color
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: 100_000, height: 100_000)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.string = text
        view.delegate = self
        editorTop = CGPoint(x: open.origin.x - window.frame.origin.x, y: open.origin.y - window.frame.origin.y)
        editor = view
        addSubview(view)
        fitEditor()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeFirstResponder(view)
    }

    /// Removes the text box and gives back its text, or nil when this canvas has none.
    func closeEditor() -> String? {
        guard let view = editor else { return nil }
        editor = nil
        view.removeFromSuperview()
        return view.string
    }

    func recolorEditor(_ color: NSColor) {
        editor?.textColor = color
        editor?.insertionPointColor = color
    }

    func textDidChange(_ notification: Notification) {
        fitEditor()
    }

    private func fitEditor() {
        guard let view = editor, let open = board.editing else { return }
        let measure = Mark(points: [.zero], color: open.color, kind: .text, text: view.string, size: open.size).textRect.size
        view.frame = CGRect(x: editorTop.x, y: editorTop.y - measure.height, width: measure.width + open.size, height: measure.height)
    }

    private func screenPoint(_ event: NSEvent) -> CGPoint {
        window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
    }

    override func mouseDown(with event: NSEvent) {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKey()
        }
        handling = false
        let point = screenPoint(event)
        let text = board.marks.indices.last { board.marks[$0].kind == .text && board.marks[$0].hit(point, slack: 8) }
        if board.editing != nil {
            board.commitText()
            return
        }
        if board.tool == .text || (board.tool == .select && event.clickCount == 2 && text != nil) {
            board.edit(at: point, index: text)
            return
        }
        handling = board.tool == .select || event.modifierFlags.contains(.command)
        if handling {
            board.press(at: screenPoint(event))
        } else if board.tool == .eraser {
            board.beginErase(at: screenPoint(event))
        } else {
            board.begin(at: screenPoint(event), arrow: event.modifierFlags.contains(.shift))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if handling {
            board.drag(to: screenPoint(event))
        } else if board.tool == .eraser {
            board.erase(to: screenPoint(event))
        } else if board.live != nil {
            board.extend(to: screenPoint(event), square: event.modifierFlags.contains(.shift))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if handling {
            board.release()
            if board.tool != .select {
                board.selected = nil
                board.redraw()
            }
            board.follow()
        } else if board.tool == .eraser {
            board.erase(to: screenPoint(event))
            board.endErase()
        } else if board.live != nil {
            board.extend(to: screenPoint(event), square: event.modifierFlags.contains(.shift))
            board.end()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let origin = window?.frame.origin else { return }
        let local = { (point: CGPoint) in CGPoint(x: point.x - origin.x, y: point.y - origin.y) }
        let editing = board.editing?.index
        let marks = board.marks.indices.filter { $0 != editing }.map { board.marks[$0] } + (board.live.map { [$0] } ?? [])
        for mark in marks {
            mark.color.set()
            switch mark.kind {
            case .text:
                let rect = mark.textRect
                mark.styledText.draw(at: CGPoint(x: rect.minX - origin.x, y: rect.minY - origin.y))
            case .ink: drawInk(mark.points.map(local))
            case .arrow, .doubleArrow, .line: drawLine(mark.moved(by: -origin.x, -origin.y))
            case .rectangle, .ellipse: drawShape(mark.moved(by: -origin.x, -origin.y))
            }
        }
        if let box = board.selectionBox() {
            let frame = NSBezierPath(rect: box.offsetBy(dx: -origin.x, dy: -origin.y))
            frame.lineWidth = 1.5
            frame.setLineDash([5, 4], count: 2, phase: 0)
            NSColor.controlAccentColor.set()
            frame.stroke()
        }
        for grip in board.grips() {
            let center = local(grip.at)
            let size = Board.gripSize
            let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            let shape = grip.grip == .bend || grip.grip == .end(0) || grip.grip == .end(1)
                ? NSBezierPath(ovalIn: rect)
                : NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            shape.fill()
            NSColor.controlAccentColor.setStroke()
            shape.lineWidth = 1.5
            shape.stroke()
        }
    }

    private func drawInk(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.lineWidth = Board.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: first)
        if points.count == 1 {
            path.line(to: first)
        }
        for index in 1..<max(points.count, 1) {
            let mid = CGPoint(x: (points[index - 1].x + points[index].x) / 2, y: (points[index - 1].y + points[index].y) / 2)
            path.curve(to: mid, controlPoint1: points[index - 1], controlPoint2: points[index - 1])
        }
        if let last = points.last, points.count > 1 {
            path.line(to: last)
        }
        path.stroke()
    }

    private func stroke(_ path: NSBezierPath, _ dash: Dash) {
        path.lineWidth = Board.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        switch dash {
        case .solid: break
        case .dashed: path.setLineDash([8, 12], count: 2, phase: 0)
        case .dotted: path.setLineDash([0, 10], count: 2, phase: 0)
        }
        path.stroke()
    }

    private func drawShape(_ mark: Mark) {
        let path = mark.kind == .ellipse ? NSBezierPath(ovalIn: mark.rect) : NSBezierPath(rect: mark.rect)
        if mark.fill != .none {
            mark.color.withAlphaComponent(mark.fill == .solid ? 1 : 0.3).setFill()
            path.fill()
        }
        mark.color.setStroke()
        stroke(path, mark.dash)
    }

    private func drawLine(_ mark: Mark) {
        guard mark.points.count == 2 else { return }
        let start = mark.points[0], end = mark.points[1], control = mark.control
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 2 else { return }
        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.curve(
            to: end,
            controlPoint1: CGPoint(x: start.x + 2 / 3 * (control.x - start.x), y: start.y + 2 / 3 * (control.y - start.y)),
            controlPoint2: CGPoint(x: end.x + 2 / 3 * (control.x - end.x), y: end.y + 2 / 3 * (control.y - end.y)))
        stroke(shaft, mark.dash)
        let head = min(20, max(10, length / 4))
        if mark.kind != .line { drawHead(at: end, from: control, head) }
        if mark.kind == .doubleArrow { drawHead(at: start, from: control, head) }
    }

    private func drawHead(at tip: CGPoint, from control: CGPoint, _ head: CGFloat) {
        let angle = atan2(tip.y - control.y, tip.x - control.x)
        let spread = CGFloat.pi / 6.5
        let wings = NSBezierPath()
        wings.move(to: CGPoint(x: tip.x - cos(angle - spread) * head, y: tip.y - sin(angle - spread) * head))
        wings.line(to: tip)
        wings.line(to: CGPoint(x: tip.x - cos(angle + spread) * head, y: tip.y - sin(angle + spread) * head))
        stroke(wings, .solid)
    }
}

/// A window over a whole screen that may take keys, which a borderless window can't by default.
final class CanvasWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// The small bar of tools, colours, undo, redo, clear and close, and under it the style strip of the arrow and shape
/// tools. Each button shows its name and key a second after the pointer rests on it, and at once while another tip
/// shows. Over the bar the pointer is always the plain arrow.
struct Toolbar: View {
    static let colorNames = ["Red", "Yellow", "Green", "Blue", "White", "Black"]

    @ObservedObject var board: Board
    let close: () -> Void
    @State private var tip: String?
    @State private var hovering: String?

    var body: some View {
        VStack(spacing: 6) {
            bar
            if let strip = board.strip {
                styles(strip)
            }
        }
        .padding(.horizontal, 48)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bar: some View {
        HStack(spacing: 4) {
            tool(.select, "cursorarrow", "Select", "V")
            tool(.pen, "pencil.tip", "Pen", "P")
            tool(.arrow, Self.symbol(board.lineKind), Self.name(board.lineKind), Self.key(board.lineKind), turn: board.lineKind == .doubleArrow ? -45 : 0)
            tool(.shape, board.shapeKind == .ellipse ? "circle" : "rectangle", board.shapeKind == .ellipse ? "Ellipse" : "Rectangle", board.shapeKind == .ellipse ? "O" : "R")
            tool(.text, "textformat", "Text", "T")
            tool(.eraser, "eraser", "Eraser", "E")
            Divider().frame(height: 20).padding(.horizontal, 4)
            ForEach(Board.colors.indices, id: \.self) { index in
                Button { board.pick(color: index) } label: {
                    Circle()
                        .fill(Color(nsColor: Board.colors[index]))
                        .overlay(Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .padding(4)
                        .background(Circle().strokeBorder(.primary.opacity(board.shownColor == index ? 0.8 : 0), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .modifier(tipped(Self.colorNames[index], "\(index + 1)"))
            }
            Divider().frame(height: 20).padding(.horizontal, 4)
            action("arrow.uturn.backward", "Undo", "⌘Z", off: board.history.isEmpty) { board.undo() }
            action("arrow.uturn.forward", "Redo", "⇧⌘Z", off: board.future.isEmpty) { board.redo() }
            action("trash", "Clear all", "⌫", off: board.marks.isEmpty) { board.selected == nil ? board.clear() : board.deleteSelected() }
            action("xmark", "Close and erase", "Esc", close)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .modifier(Plate())
    }

    private func styles(_ strip: Strip) -> some View {
        HStack(spacing: 4) {
            if strip == .shape {
                choice("rectangle", "Rectangle", "R", board.shownKind == .rectangle) { board.pick(kind: .rectangle) }
                choice("circle", "Ellipse", "O", board.shownKind == .ellipse) { board.pick(kind: .ellipse) }
            } else {
                ForEach([Kind.line, .arrow, .doubleArrow], id: \.self) { kind in
                    choice(Self.symbol(kind), Self.name(kind), Self.key(kind), board.shownKind == kind, turn: kind == .doubleArrow ? -45 : 0) { board.pick(kind: kind) }
                }
            }
            Divider().frame(height: 18).padding(.horizontal, 3)
            ForEach(Dash.allCases, id: \.self) { dash in
                choice(nil, dash == .solid ? "Solid" : dash == .dashed ? "Dashed" : "Dotted", "", board.shownDash == dash) { board.pick(dash: dash) }
                    .overlay(DashSample(dash: dash).allowsHitTesting(false))
            }
            if strip == .shape {
                Divider().frame(height: 18).padding(.horizontal, 3)
                ForEach(Fill.allCases, id: \.self) { fill in
                    choice(nil, fill == .none ? "No fill" : fill == .semi ? "Light fill" : "Solid fill", "", board.shownFill == fill) { board.pick(fill: fill) }
                        .overlay(FillSample(fill: fill).allowsHitTesting(false))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .modifier(Plate())
    }

    static func symbol(_ kind: Kind) -> String {
        kind == .line ? "line.diagonal" : kind == .doubleArrow ? "arrow.left.and.right" : "arrow.up.right"
    }

    static func name(_ kind: Kind) -> String {
        kind == .line ? "Line" : kind == .doubleArrow ? "Double arrow" : "Arrow"
    }

    static func key(_ kind: Kind) -> String {
        kind == .line ? "L" : kind == .doubleArrow ? "D" : "A"
    }

    /// The tip of one button. Its id holds its place, so a bar button and a strip button of one name never share a tip.
    private func tipped(_ name: String, _ key: String, strip: Bool = false) -> TipModifier {
        TipModifier(id: (strip ? "strip." : "bar.") + name, name: name, key: key, drop: strip ? 38 : board.strip == nil ? 40 : 82, tip: $tip, hovering: $hovering)
    }

    private func tool(_ tool: PenTool, _ symbol: String, _ name: String, _ key: String, turn: Double = 0) -> some View {
        Button {
            board.tool = tool
            NSCursor.arrow.set()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(turn))
                .frame(width: 30, height: 28)
                .background(board.tool == tool ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(tipped(name, key))
    }

    private func choice(_ symbol: String?, _ name: String, _ key: String, _ on: Bool, turn: Double = 0, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Group {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).rotationEffect(.degrees(turn)) } else { Color.clear }
            }
            .frame(width: 28, height: 26)
            .background(on ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(tipped(name, key, strip: true))
    }

    private func action(_ symbol: String, _ name: String, _ key: String, off: Bool = false, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(off)
        .opacity(off ? 0.35 : 1)
        .modifier(tipped(name, key))
    }
}

/// The ground of the toolbar and the strip: a light material capsule with a faint rim, over which the pointer is the
/// plain arrow.
struct Plate: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.arrow.set() }
            }
    }
}

/// A short line drawn in one stroke style.
struct DashSample: View {
    let dash: Dash

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 6, y: 13))
            path.addLine(to: CGPoint(x: 22, y: 13))
        }
        .stroke(.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: dash == .solid ? [] : dash == .dashed ? [4, 4.5] : [0, 4.5]))
        .frame(width: 28, height: 26)
    }
}

/// A small square drawn with one fill.
struct FillSample: View {
    let fill: Fill

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.primary.opacity(fill == .none ? 0 : fill == .semi ? 0.3 : 1))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.primary, lineWidth: 1.8))
            .frame(width: 14, height: 14)
            .frame(width: 28, height: 26)
    }
}

/// The tip under one button: its name, and its key in a faint box when it has one.
struct TipModifier: ViewModifier {
    let id: String
    let name: String
    let key: String
    let drop: CGFloat
    @Binding var tip: String?
    @Binding var hovering: String?

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    hovering = id
                    if tip != nil {
                        tip = id
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if hovering == id { tip = id }
                        }
                    }
                } else if hovering == id {
                    hovering = nil
                    tip = nil
                }
            }
            .overlay(alignment: .bottom) {
                if tip == id {
                    HStack(spacing: 6) {
                        Text(name)
                        if !key.isEmpty {
                            Text(key)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 7))
                    .fixedSize()
                    .offset(y: drop)
                    .allowsHitTesting(false)
                }
            }
    }
}

/// The panel that holds the toolbar. Screenshots leave it out, so they show only the drawing.
final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
}

/// The overlay: one canvas for each screen, the toolbar, and the keys.
final class Overlay: NSObject, NSApplicationDelegate {
    let board = Board()
    var windows: [NSWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        let mouse = NSEvent.mouseLocation
        var home = NSScreen.main ?? NSScreen.screens[0]
        for screen in NSScreen.screens {
            if screen.frame.contains(mouse) { home = screen }
            let window = CanvasWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.level = level
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isReleasedWhenClosed = false
            let canvas = Canvas(board: board)
            window.contentView = canvas
            board.canvases.append(canvas)
            windows.append(window)
            window.orderFrontRegardless()
        }

        let host = NSHostingView(rootView: Toolbar(board: board) { NSApp.terminate(nil) })
        let size = NSSize(width: host.fittingSize.width, height: 170)
        let panel = ToolbarPanel(
            contentRect: NSRect(
                x: home.visibleFrame.midX - size.width / 2,
                y: home.visibleFrame.maxY - size.height,
                width: size.width,
                height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: level.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.sharingType = .none
        panel.orderFrontRegardless()
        windows.append(panel)

        let board = board
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in board.follow() }
        RunLoop.main.add(timer, forMode: .common)
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
            board.commitText()
            board.selected = nil
            board.redraw()
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.key(event) == true ? nil : event
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first { $0.frame == home.frame }?.makeKey()
    }

    private func key(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)
        let letter = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if board.editing != nil {
            guard event.keyCode == 53 else { return false }
            board.commitText()
            return true
        }
        switch (event.keyCode, letter) {
        case (53, _) where board.tool != .select:
            board.tool = .select
        case (53, _) where board.selected != nil:
            board.selected = nil
            board.redraw()
        case (53, _): NSApp.terminate(nil)
        case (_, "z") where command && shift: board.redo()
        case (_, "z") where command: board.undo()
        case (51, _) where board.selected != nil, (117, _) where board.selected != nil: board.deleteSelected()
        case (51, _), (117, _): board.clear()
        case (123, _) where board.selected != nil: board.nudge(shift ? -10 : -1, 0)
        case (124, _) where board.selected != nil: board.nudge(shift ? 10 : 1, 0)
        case (125, _) where board.selected != nil: board.nudge(0, shift ? -10 : -1)
        case (126, _) where board.selected != nil: board.nudge(0, shift ? 10 : 1)
        case (_, "p") where !command: board.tool = .pen
        case (_, "a") where !command:
            board.tool = .arrow
            board.pick(kind: .arrow)
        case (_, "d") where !command:
            board.tool = .arrow
            board.pick(kind: .doubleArrow)
        case (_, "t") where !command: board.tool = .text
        case (_, "l") where !command:
            board.tool = .arrow
            board.pick(kind: .line)
        case (_, "r") where !command:
            board.tool = .shape
            board.pick(kind: .rectangle)
        case (_, "o") where !command:
            board.tool = .shape
            board.pick(kind: .ellipse)
        case (_, "v") where !command: board.tool = .select
        case (_, "e") where !command: board.tool = .eraser
        case (_, "1"), (_, "2"), (_, "3"), (_, "4"), (_, "5"), (_, "6"):
            board.pick(color: Int(letter)! - 1)
        default: return false
        }
        return true
    }
}

setsid()
signal(SIGHUP, SIG_IGN)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let overlay = Overlay()
app.delegate = overlay
app.run()
