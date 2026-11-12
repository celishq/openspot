import AppKit
import Combine

/// The white surface of a board. It draws the figures through the camera, and turns presses, drags, keys, the
/// trackpad and the wheel into changes of the studio's board.
@MainActor
final class Canvas: NSView, NSTextViewDelegate {
    /// A place on a selected figure that a drag changes: a side or corner of a box, an end of a link, or the bend of an arrow.
    enum Grip: Equatable {
        case side(left: Bool, right: Bool, top: Bool, bottom: Bool)
        case start, end, bend
    }

    /// What the drag under way does.
    enum Drag {
        case none
        case pan(last: CGPoint)
        case move(from: CGPoint, before: Board)
        case marquee(from: CGPoint, to: CGPoint, before: Set<UUID>)
        case bundle(points: [CGPoint])
        case create(id: UUID, from: CGPoint, before: Board)
        case pen(id: UUID, before: Board)
        case erase(hits: Set<UUID>)
        case grip(Grip, id: UUID, from: CGPoint, original: Figure, before: Board)

        var isIdle: Bool {
            if case .none = self { true } else { false }
        }
    }

    let studio: Studio
    private var offset = CGPoint(x: 0, y: 0)
    private var drag = Drag.none
    private var spaceHeld = false
    private var hover: CGPoint?
    private var editing: (id: UUID, field: NSTextView, before: Board)?
    private var watch: AnyCancellable?
    private var trail: [CGPoint] = []
    private var trailFade: Timer?

    init(studio: Studio) {
        self.studio = studio
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        watch = studio.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.needsDisplay = true
                self.window?.invalidateCursorRects(for: self)
                if self.drag.isIdle, self.editing == nil, let window = self.window,
                   self.hitTest(self.superview?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? .zero) === self {
                    self.pointer.set()
                }
            }
        }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect, .cursorUpdate], owner: self))
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Camera

    private var zoom: CGFloat {
        get { studio.zoom }
        set { studio.zoom = newValue }
    }

    func board(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - offset.x) / zoom, y: (point.y - offset.y) / zoom)
    }

    func view(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * zoom + offset.x, y: point.y * zoom + offset.y)
    }

    private func view(_ rect: CGRect) -> CGRect {
        CGRect(origin: view(rect.origin), size: CGSize(width: rect.width * zoom, height: rect.height * zoom))
    }

    /// Zooms to a level, keeping the board point under `anchor` in place.
    func zoom(to level: CGFloat, around anchor: CGPoint? = nil) {
        let anchor = anchor ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let fixed = board(anchor)
        zoom = min(8, max(0.1, level))
        offset = CGPoint(x: anchor.x - fixed.x * zoom, y: anchor.y - fixed.y * zoom)
        placeField()
        needsDisplay = true
    }

    /// Shows all the figures, or the middle of the board when it is empty.
    func fit() {
        let area = studio.board.figures.map { studio.board.bounds(of: $0) }.reduce(CGRect.null) { $0.union($1) }
        guard !area.isNull, bounds.width > 0 else {
            zoom = 1
            offset = CGPoint(x: bounds.midX, y: bounds.midY)
            needsDisplay = true
            return
        }
        let room = bounds.insetBy(dx: 80, dy: 100)
        zoom = min(1, room.width / max(area.width, 1), room.height / max(area.height, 1))
        offset = CGPoint(x: bounds.midX - area.midX * zoom, y: bounds.midY - area.midY * zoom)
        placeField()
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) || !event.hasPreciseScrollingDeltas {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 100 : event.scrollingDeltaY / 10
            zoom(to: zoom * (1 + delta), around: point)
            return
        }
        offset = offset + CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY)
        placeField()
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        zoom(to: zoom * (1 + event.magnification), around: convert(event.locationInWindow, from: nil))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.white.setFill()
        dirtyRect.fill()
        context.saveGState()
        context.translateBy(x: offset.x, y: offset.y)
        context.scaleBy(x: zoom, y: zoom)
        var painting = Painting(board: studio.board, assets: studio.assets)
        if case .erase(let hits) = drag { painting.faint = hits }
        if let editing { painting.wordless = [editing.id] }
        painting.draw(in: context)
        context.restoreGState()
        chrome(in: context)
    }

    /// The selection, its grips, the marquee, the bundle stroke and the box that an arrow end would hold.
    private func chrome(in context: CGContext) {
        let accent = NSColor.controlAccentColor
        context.setLineDash(phase: 0, lengths: [])
        context.setStrokeColor(accent.cgColor)
        context.setLineWidth(1.5)
        let selected = studio.selection.compactMap { studio.board[$0] }
        if editing == nil {
            for figure in selected {
                if figure.kind == .arrow || figure.kind == .pen {
                    context.setStrokeColor(accent.withAlphaComponent(0.35).cgColor)
                    context.setLineWidth(figure.weight.width * zoom + 4)
                    context.addLines(between: studio.board.path(of: figure).map { view($0) })
                    context.strokePath()
                    context.setLineWidth(1.5)
                    context.setStrokeColor(accent.cgColor)
                } else {
                    context.stroke(view(studio.board.bounds(of: figure)).insetBy(dx: -4, dy: -4))
                }
            }
            if selected.count > 1 {
                let all = selected.map { studio.board.bounds(of: $0) }.reduce(CGRect.null) { $0.union($1) }
                context.setLineDash(phase: 0, lengths: [4, 4])
                context.stroke(view(all).insetBy(dx: -8, dy: -8))
                context.setLineDash(phase: 0, lengths: [])
            }
            for (_, point) in grips() {
                let knob = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.setFillColor(NSColor.white.cgColor)
                context.fillEllipse(in: knob)
                context.strokeEllipse(in: knob)
            }
        }
        if let held = heldTarget(), let figure = studio.board[held] {
            context.setStrokeColor(accent.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(3)
            context.stroke(view(figure.frame).insetBy(dx: -3, dy: -3))
        }
        if case .marquee(let from, let to, _) = drag {
            let area = CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(to.x - from.x), height: abs(to.y - from.y))
            context.setFillColor(accent.withAlphaComponent(0.08).cgColor)
            context.fill(view(area))
            context.setLineWidth(1)
            context.stroke(view(area))
        }
        if !trail.isEmpty {
            context.setStrokeColor(accent.withAlphaComponent(0.55).cgColor)
            context.setLineWidth(5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(Painting.smooth(trail.map { view($0) }))
            context.strokePath()
        }
    }

    /// The box or junction that the end of the arrow being drawn holds.
    private func heldTarget() -> UUID? {
        switch drag {
        case .create(let id, _, _):
            return studio.board[id]?.end
        case .grip(let grip, let id, _, _, _) where grip == .start || grip == .end:
            return grip == .start ? studio.board[id]?.start : studio.board[id]?.end
        default:
            return nil
        }
    }

    /// The grips of the one selected figure, in view points.
    private func grips() -> [(Grip, CGPoint)] {
        guard studio.selection.count == 1, let id = studio.selection.first, let figure = studio.board[id] else { return [] }
        switch figure.kind {
        case .shape, .text, .image:
            let box = view(figure.frame).insetBy(dx: -4, dy: -4)
            var grips: [(Grip, CGPoint)] = [
                (.side(left: true, right: false, top: true, bottom: false), CGPoint(x: box.minX, y: box.minY)),
                (.side(left: false, right: true, top: true, bottom: false), CGPoint(x: box.maxX, y: box.minY)),
                (.side(left: false, right: true, top: false, bottom: true), CGPoint(x: box.maxX, y: box.maxY)),
                (.side(left: true, right: false, top: false, bottom: true), CGPoint(x: box.minX, y: box.maxY))
            ]
            if figure.kind == .shape {
                grips += [
                    (.side(left: false, right: false, top: true, bottom: false), CGPoint(x: box.midX, y: box.minY)),
                    (.side(left: false, right: true, top: false, bottom: false), CGPoint(x: box.maxX, y: box.midY)),
                    (.side(left: false, right: false, top: false, bottom: true), CGPoint(x: box.midX, y: box.maxY)),
                    (.side(left: true, right: false, top: false, bottom: false), CGPoint(x: box.minX, y: box.midY))
                ]
            }
            return grips
        case .arrow:
            let line = studio.board.path(of: figure)
            var grips: [(Grip, CGPoint)] = [(.start, view(line[0])), (.end, view(line[line.count - 1]))]
            if figure.ties.isEmpty { grips.append((.bend, view(line[line.count / 2]))) }
            return grips
        default:
            return []
        }
    }

    // MARK: Pressing

    override func mouseDown(with event: NSEvent) {
        endEditing()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let at = board(point)
        if event.clickCount == 2, studio.tool == .select {
            doubleClick(at)
            return
        }
        if spaceHeld || studio.tool == .hand {
            drag = .pan(last: point)
            NSCursor.closedHand.set()
            return
        }
        if event.modifierFlags.contains(.option) || studio.tool == .bundle {
            drag = .bundle(points: [at])
            trail = [at]
            return
        }
        switch studio.tool {
        case .select:
            if let grip = grips().first(where: { $0.1.distance(to: point) <= 9 }), let id = studio.selection.first, let figure = studio.board[id] {
                drag = .grip(grip.0, id: id, from: at, original: figure, before: studio.board)
                return
            }
            if let figure = studio.board.figure(at: at, tolerance: 6 / zoom) {
                if event.modifierFlags.contains(.shift) {
                    if studio.selection.contains(figure.id) { studio.selection.remove(figure.id) } else { studio.selection.insert(figure.id) }
                } else if !studio.selection.contains(figure.id) {
                    studio.selection = [figure.id]
                }
                studio.pickUpStyle()
                drag = .move(from: at, before: studio.board)
            } else {
                let kept = event.modifierFlags.contains(.shift) ? studio.selection : []
                studio.selection = kept
                drag = .marquee(from: at, to: at, before: kept)
            }
        case .eraser:
            drag = .erase(hits: [])
            erase(at)
        case .pen:
            var figure = Figure(kind: .pen, points: [at])
            studio.style.dress(&figure)
            figure.filled = false
            let before = studio.board
            studio.board.add(figure)
            drag = .pen(id: figure.id, before: before)
        case .text:
            var figure = Figure(kind: .text, points: [at, at + CGPoint(x: 20, y: 30)])
            studio.style.dress(&figure)
            let before = studio.board
            studio.board.add(figure)
            studio.selection = [figure.id]
            studio.tool = .select
            beginEditing(figure.id, before: before)
        case .shape, .arrow:
            var figure = Figure(kind: studio.tool == .shape ? .shape : .arrow, points: [at, at])
            figure.form = studio.form
            studio.style.dress(&figure)
            if figure.kind == .arrow {
                figure.start = studio.board.target(at: at)
            }
            let before = studio.board
            studio.board.add(figure)
            drag = .create(id: figure.id, from: at, before: before)
        case .hand, .bundle:
            break
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let at = board(point)
        switch drag {
        case .none:
            break
        case .pan(let last):
            offset = offset + (point - last)
            drag = .pan(last: point)
            placeField()
        case .move(let from, let before):
            var board = before
            board.move(studio.selection, by: at - from)
            studio.board = board
        case .marquee(let from, _, let kept):
            drag = .marquee(from: from, to: at, before: kept)
            let area = CGRect(x: min(from.x, at.x), y: min(from.y, at.y), width: abs(at.x - from.x), height: abs(at.y - from.y))
            studio.selection = kept.union(studio.board.figures(in: area))
        case .bundle(var points):
            points.append(at)
            trail = points
            drag = .bundle(points: points)
        case .create(let id, let from, _):
            stretch(id, from: from, to: at, square: event.modifierFlags.contains(.shift))
        case .pen(let id, _):
            studio.board.update(id) { $0.points.append(at) }
        case .erase:
            erase(at)
        case .grip(let grip, let id, let from, let original, let before):
            pull(grip, of: original, by: at - from, to: at, base: before, id: id)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case .pan:
            NSCursor.openHand.set()
        case .move(_, let before), .pen(_, let before):
            studio.record(before)
        case .grip(_, _, _, _, let before):
            studio.record(before)
        case .marquee:
            studio.pickUpStyle()
        case .bundle(let points):
            let before = studio.board
            if let junction = studio.board.bundle(along: points) {
                studio.record(before)
                studio.selection = [junction]
            } else {
                NSSound(named: "Funk")?.play()
            }
            fadeTrail()
        case .create(let id, let from, let before):
            finishCreating(id, from: from, before: before)
        case .erase(let hits):
            drag = .none
            studio.remove(hits)
        case .none:
            break
        }
        drag = .none
        needsDisplay = true
    }

    private func fadeTrail() {
        trailFade?.invalidate()
        trailFade = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.trail.removeFirst(min(self.trail.count, max(2, self.trail.count / 6)))
                self.needsDisplay = true
                if self.trail.isEmpty { timer.invalidate() }
            }
        }
    }

    /// Sets the far corner or end of a figure being drawn.
    private func stretch(_ id: UUID, from: CGPoint, to: CGPoint, square: Bool) {
        var end = to
        studio.board.update(id) { figure in
            if square, figure.isBox {
                let side = max(abs(to.x - from.x), abs(to.y - from.y))
                end = CGPoint(x: from.x + (to.x < from.x ? -side : side), y: from.y + (to.y < from.y ? -side : side))
            }
            figure.points[1] = end
        }
        if studio.board[id]?.kind == .arrow {
            let start = studio.board[id]?.start
            let held = studio.board.target(at: to, except: [id]).flatMap { $0 == start ? nil : $0 }
            studio.board.update(id) { $0.end = held }
        }
    }

    private func finishCreating(_ id: UUID, from: CGPoint, before: Board) {
        guard let figure = studio.board[id] else { return }
        let small = figure.points[0].distance(to: figure.points[1]) < 4 / zoom
        if small {
            if figure.isBox {
                studio.board.update(id) { $0.points = [from - CGPoint(x: 70, y: 45), from + CGPoint(x: 70, y: 45)] }
            } else {
                studio.board = before
                return
            }
        }
        if figure.isBox {
            studio.board.update(id) { $0.points = [$0.frame.origin, CGPoint(x: $0.frame.maxX, y: $0.frame.maxY)] }
        }
        studio.record(before)
        studio.selection = [id]
        studio.tool = .select
    }

    /// Drags a grip of a figure by `delta` from its first place.
    private func pull(_ grip: Grip, of original: Figure, by delta: CGPoint, to at: CGPoint, base: Board, id: UUID) {
        var board = base
        switch grip {
        case .side(let left, let right, let top, let bottom):
            var box = original.frame
            if left { box.origin.x += delta.x; box.size.width -= delta.x }
            if right { box.size.width += delta.x }
            if top { box.origin.y += delta.y; box.size.height -= delta.y }
            if bottom { box.size.height += delta.y }
            board.resize(id, to: box)
        case .start, .end:
            let held = board.target(at: at, except: [id])
            board.update(id) { figure in
                if grip == .start {
                    figure.points[0] = at
                    figure.start = held
                } else {
                    figure.points[figure.points.count - 1] = at
                    figure.end = held
                }
            }
        case .bend:
            let line = base.path(of: original)
            let a = line[0]
            let b = line[line.count - 1]
            let middle = (a + b) * 0.5
            let side = (b - a).unit.normal
            let reach = (at - middle).x * side.x + (at - middle).y * side.y
            board.update(id) { $0.bend = abs(reach) < 4 ? 0 : reach }
        }
        studio.board = board
    }

    private func erase(_ at: CGPoint) {
        guard case .erase(var hits) = drag else { return }
        if let figure = studio.board.figure(at: at, tolerance: 8 / zoom) { hits.insert(figure.id) }
        drag = .erase(hits: hits)
    }

    private func doubleClick(_ at: CGPoint) {
        if let figure = studio.board.figure(at: at, tolerance: 6 / zoom), figure.kind == .shape || figure.kind == .text {
            studio.selection = [figure.id]
            beginEditing(figure.id, before: studio.board)
            return
        }
        if studio.board.figure(at: at, tolerance: 6 / zoom) == nil {
            var figure = Figure(kind: .text, points: [at, at + CGPoint(x: 20, y: 30)])
            studio.style.dress(&figure)
            let before = studio.board
            studio.board.add(figure)
            studio.selection = [figure.id]
            beginEditing(figure.id, before: before)
        }
    }

    // MARK: Words

    /// Opens a field over a text figure or over the middle of a box.
    func beginEditing(_ id: UUID, before: Board) {
        guard let figure = studio.board[id] else { return }
        let field = NSTextView()
        field.isRichText = false
        field.drawsBackground = false
        field.allowsUndo = true
        field.isVerticallyResizable = true
        field.textContainerInset = .zero
        field.textContainer?.lineFragmentPadding = 0
        field.delegate = self
        field.string = figure.text
        field.insertionPointColor = figure.ink.color
        addSubview(field)
        editing = (id, field, before)
        styleField()
        placeField()
        window?.makeFirstResponder(field)
        field.selectAll(nil)
        needsDisplay = true
    }

    private func styleField() {
        guard let editing, let figure = studio.board[editing.id] else { return }
        let font = NSFont(descriptor: figure.font.fontDescriptor, size: figure.font.pointSize * zoom) ?? figure.font
        editing.field.font = font
        editing.field.textColor = figure.ink.color
        editing.field.alignment = figure.align == .left ? .left : figure.align == .right ? .right : .center
    }

    /// Lays the field over its figure, and grows a text figure to fit its words.
    private func placeField() {
        guard let editing, let figure = studio.board[editing.id] else { return }
        styleField()
        if figure.kind == .text {
            let words = NSAttributedString(string: editing.field.string.isEmpty ? " " : editing.field.string, attributes: [.font: figure.font])
            let size = words.boundingRect(with: CGSize(width: 10_000, height: 10_000), options: [.usesLineFragmentOrigin]).size
            let origin = figure.frame.origin
            studio.board.update(editing.id) { $0.points = [origin, origin + CGPoint(x: ceil(size.width) + 4, y: ceil(size.height))] }
            editing.field.frame = view(CGRect(origin: origin, size: CGSize(width: ceil(size.width) + 40, height: ceil(size.height))))
        } else {
            let box = view(figure.frame.insetBy(dx: 10, dy: 8))
            let words = NSAttributedString(string: editing.field.string.isEmpty ? " " : editing.field.string, attributes: [.font: editing.field.font ?? figure.font])
            let height = words.boundingRect(with: CGSize(width: box.width, height: 10_000), options: [.usesLineFragmentOrigin]).height
            editing.field.frame = CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: max(height, 20))
        }
    }

    func textDidChange(_ notification: Notification) {
        placeField()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(cancelOperation(_:)) || (selector == #selector(insertNewline(_:)) && NSEvent.modifierFlags.contains(.command)) {
            endEditing()
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }

    /// Keeps the words of the field. A text figure left empty goes away.
    func endEditing() {
        guard let editing else { return }
        self.editing = nil
        let words = editing.field.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : editing.field.string
        editing.field.removeFromSuperview()
        studio.board.update(editing.id) { $0.text = words }
        if let figure = studio.board[editing.id], figure.kind == .text, words.isEmpty {
            studio.board.figures.removeAll { $0.id == editing.id }
            studio.selection = []
        }
        studio.record(editing.before)
        needsDisplay = true
    }

    // MARK: Keys

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if event.keyCode == 49 {
            if !spaceHeld { NSCursor.openHand.set() }
            spaceHeld = true
            return
        }
        if flags.isEmpty || flags == [.shift] {
            switch event.keyCode {
            case 51, 117:
                studio.remove(studio.selection)
                return
            case 53:
                studio.selection = []
                studio.tool = .select
                needsDisplay = true
                return
            case 36:
                if studio.selection.count == 1, let id = studio.selection.first, let figure = studio.board[id], figure.kind == .shape || figure.kind == .text {
                    beginEditing(id, before: studio.board)
                }
                return
            case 123, 124, 125, 126:
                let step: CGFloat = flags == [.shift] ? 10 : 1
                let delta: CGPoint = switch event.keyCode {
                case 123: CGPoint(x: -step, y: 0)
                case 124: CGPoint(x: step, y: 0)
                case 125: CGPoint(x: 0, y: step)
                default: CGPoint(x: 0, y: -step)
                }
                studio.change { $0.move(studio.selection, by: delta) }
                return
            default:
                break
            }
        }
        if flags.isEmpty, let tool = Tool.allCases.first(where: { String($0.key) == key }) ?? (key == "p" ? .pen : key == "x" ? .eraser : nil) {
            studio.tool = tool
            if tool != .select { studio.selection = [] }
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceHeld = false
            NSCursor.arrow.set()
            return
        }
        super.keyUp(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        pointer.set()
    }

    override func mouseMoved(with event: NSEvent) {
        pointer.set()
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: pointer)
    }

    /// The cursor of the tool, the one cursor over the whole canvas: a caret for the Text tool, a hand to pan, an arrow to
    /// select, and a crosshair for each other tool.
    var pointer: NSCursor {
        if spaceHeld { return .openHand }
        switch studio.tool {
        case .hand: return .openHand
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    // MARK: Images

    /// The image files among the files of a drag or a paste.
    private func pictures(_ pasteboard: NSPasteboard) -> [URL] {
        let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return files.filter { NSImage(contentsOf: $0) != nil }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        pictures(sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = pictures(sender.draggingPasteboard)
        guard !files.isEmpty else { return false }
        let at = board(convert(sender.draggingLocation, from: nil))
        for (index, file) in files.enumerated() {
            studio.insert(picture: file, at: at + CGPoint(x: CGFloat(index) * 24, y: CGFloat(index) * 24))
        }
        window?.makeFirstResponder(self)
        return true
    }

    /// Asks for image files and adds them in the middle of the view.
    @objc func insertPicture(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let middle = board(CGPoint(x: bounds.midX, y: bounds.midY))
        for (index, file) in panel.urls.enumerated() {
            studio.insert(picture: file, at: middle + CGPoint(x: CGFloat(index) * 24, y: CGFloat(index) * 24))
        }
    }

    // MARK: Menu

    @objc func undo(_ sender: Any?) {
        endEditing()
        studio.undo()
    }

    @objc func redo(_ sender: Any?) {
        endEditing()
        studio.redo()
    }

    @objc override func selectAll(_ sender: Any?) {
        studio.selection = Set(studio.board.figures.map(\.id))
        needsDisplay = true
    }

    @objc func delete(_ sender: Any?) {
        studio.remove(studio.selection)
    }

    @objc func copy(_ sender: Any?) {
        let figures = studio.board.figures.filter { studio.selection.contains($0.id) }
        guard !figures.isEmpty, let data = try? JSONEncoder().encode(figures) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: Canvas.figuresType)
    }

    @objc func cut(_ sender: Any?) {
        copy(sender)
        delete(sender)
    }

    @objc func paste(_ sender: Any?) {
        let middle = board(CGPoint(x: bounds.midX, y: bounds.midY))
        if let data = NSPasteboard.general.data(forType: Canvas.figuresType), let figures = try? JSONDecoder().decode([Figure].self, from: data) {
            place(figures, by: CGPoint(x: 24, y: 24))
        } else if let file = pictures(NSPasteboard.general).first {
            studio.insert(picture: file, at: middle)
        } else if let image = NSImage(pasteboard: NSPasteboard.general), let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            studio.insert(png: png, at: middle)
        } else if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            var figure = Figure(kind: .text, points: [board(CGPoint(x: bounds.midX, y: bounds.midY))])
            studio.style.dress(&figure)
            figure.text = text
            let size = figure.words.boundingRect(with: CGSize(width: 600, height: 10_000), options: [.usesLineFragmentOrigin]).size
            figure.points.append(figure.points[0] + CGPoint(x: ceil(size.width) + 4, y: ceil(size.height)))
            studio.change { $0.add(figure) }
            studio.selection = [figure.id]
        }
    }

    @objc func duplicate(_ sender: Any?) {
        place(studio.board.figures.filter { studio.selection.contains($0.id) }, by: CGPoint(x: 24, y: 24))
    }

    /// Adds copies of figures with new ids, keeping the links among them, and selects the copies.
    private func place(_ figures: [Figure], by delta: CGPoint) {
        guard !figures.isEmpty else { return }
        var ids: [UUID: UUID] = [:]
        for figure in figures { ids[figure.id] = UUID() }
        let raw = figures.map { figure -> Figure in
            var copy = figure
            copy.id = ids[figure.id]!
            copy.start = figure.start.flatMap { ids[$0] }
            copy.end = figure.end.flatMap { ids[$0] }
            copy.points = figure.points.map { $0 + delta }
            if figure.kind == .arrow {
                let line = studio.board.path(of: figure)
                if figure.start != nil, copy.start == nil, let first = line.first { copy.points[0] = first + delta }
                if figure.end != nil, copy.end == nil, let last = line.last { copy.points[copy.points.count - 1] = last + delta }
            }
            return copy
        }
        let kept = raw.compactMap { copy -> Figure? in
            var copy = copy
            if copy.kind == .tie {
                copy.members = copy.members.compactMap { ids[$0] }
                return copy.members.count > 1 ? copy : nil
            }
            copy.ties = copy.ties.compactMap { ids[$0] }
            return copy
        }
        let tied = Set(kept.filter { $0.kind == .tie }.map(\.id))
        let copies = kept.map { copy -> Figure in
            var copy = copy
            copy.ties = copy.ties.filter(tied.contains)
            return copy
        }
        studio.change { board in
            for copy in copies { board.add(copy) }
        }
        studio.selection = Set(copies.map(\.id)).filter { studio.board[$0] != nil }
    }

    static let figuresType = NSPasteboard.PasteboardType("dev.openspot.draw.figures")

    @objc func zoomIn(_ sender: Any?) { zoom(to: zoom * 1.25) }
    @objc func zoomOut(_ sender: Any?) { zoom(to: zoom / 1.25) }
    @objc func zoomToFit(_ sender: Any?) { fit() }
    @objc func actualSize(_ sender: Any?) { zoom(to: 1) }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)): studio.canUndo
        case #selector(redo(_:)): studio.canRedo
        case #selector(copy(_:)), #selector(cut(_:)), #selector(delete(_:)), #selector(duplicate(_:)): !studio.selection.isEmpty
        default: true
        }
    }
}
