import AppKit

/// A block of cells in a grid of `columns` by `rows`, from one corner cell to the opposite one, either way round.
/// Cells count from the top left, as the windows of the Mac count their points.
struct Pick: Equatable {
    let columns: Int
    let rows: Int
    let left: Int
    let top: Int
    let width: Int
    let height: Int

    init(columns: Int, rows: Int, from: (Int, Int), to: (Int, Int)) {
        self.columns = columns
        self.rows = rows
        let first = (min(max(from.0, 0), columns - 1), min(max(from.1, 0), rows - 1))
        let last = (min(max(to.0, 0), columns - 1), min(max(to.1, 0), rows - 1))
        left = min(first.0, last.0)
        top = min(first.1, last.1)
        width = abs(first.0 - last.0) + 1
        height = abs(first.1 - last.1) + 1
    }

    /// The block as `openspot window move` reads it: parts of the usable area of the screen.
    var text: String {
        func part(_ count: Int, _ whole: Int) -> String { count == 0 ? "0" : count == whole ? "1" : "\(count)/\(whole)" }
        return [part(left, columns), part(top, rows), part(width, columns), part(height, rows)].joined(separator: " ")
    }

    /// The block inside this rectangle, whose origin is its bottom left, as AppKit draws.
    func rect(in area: CGRect) -> CGRect {
        let cell = CGSize(width: area.width / CGFloat(columns), height: area.height / CGFloat(rows))
        return CGRect(
            x: area.minX + CGFloat(left) * cell.width,
            y: area.maxY - CGFloat(top + height) * cell.height,
            width: CGFloat(width) * cell.width,
            height: CGFloat(height) * cell.height
        ).integral
    }
}

/// The front app and the usable area of the screen that holds its front window, in AppKit points.
struct Front {
    let app: NSRunningApplication?
    let area: CGRect

    /// Reads the window list, which needs no permission, so the grid shows before any call to Openspot.
    static func read() -> Front {
        let app = NSWorkspace.shared.frontmostApplication
        let screens = NSScreen.screens
        let top = screens.first?.frame.maxY ?? 0
        var centre = NSEvent.mouseLocation
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        if let pid = app?.processIdentifier,
           let window = list.first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
           let bounds = window[kCGWindowBounds as String] as! CFDictionary?,
           let frame = CGRect(dictionaryRepresentation: bounds) {
            centre = CGPoint(x: frame.midX, y: top - frame.midY)
        }
        let screen = screens.first { $0.frame.contains(centre) } ?? NSScreen.main ?? screens.first
        return Front(app: app, area: screen?.visibleFrame ?? .zero)
    }
}

/// The grey block on the desktop that shows where the window goes.
final class Shade {
    private let window: NSWindow
    private let block = CALayer()
    private let area: CGRect

    init(area: CGRect) {
        self.area = area
        window = NSWindow(contentRect: area, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let content = NSView(frame: CGRect(origin: .zero, size: area.size))
        content.wantsLayer = true
        block.backgroundColor = NSColor(white: 0.85, alpha: 0.28).cgColor
        block.borderColor = NSColor(white: 1, alpha: 0.45).cgColor
        block.borderWidth = 1
        block.cornerRadius = 12
        block.cornerCurve = .continuous
        block.opacity = 0
        content.layer?.addSublayer(block)
        window.contentView = content
    }

    /// Moves the block to this pick, and shows it the first time. Only the layer moves, so each step costs one composite.
    func show(_ pick: Pick?) {
        guard let pick else {
            block.opacity = 0
            return
        }
        let target = pick.rect(in: CGRect(origin: .zero, size: area.size)).insetBy(dx: 6, dy: 6)
        CATransaction.begin()
        if block.opacity == 0 {
            CATransaction.setDisableActions(true)
            block.frame = target
            CATransaction.commit()
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.12)
            block.opacity = 1
        } else {
            CATransaction.setAnimationDuration(0.14)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            block.frame = target
        }
        CATransaction.commit()
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}

/// The cells of the grid, which the person hovers, presses and drags over.
final class Cells: NSView {
    let columns: Int
    let rows: Int
    var change: (Pick?, Bool) -> Void = { _, _ in }
    private let gap: CGFloat = 5
    private var layers: [CALayer] = []
    private var anchor: (Int, Int)?
    private var hover: (Int, Int)?

    init(frame: CGRect, columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        super.init(frame: frame)
        wantsLayer = true
        for row in 0..<rows {
            for column in 0..<columns {
                let cell = CALayer()
                cell.frame = rect(column, row)
                cell.cornerRadius = 6
                cell.cornerCurve = .continuous
                cell.actions = ["backgroundColor": NSNull()]
                layer?.addSublayer(cell)
                layers.append(cell)
            }
        }
        paint(nil)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func rect(_ column: Int, _ row: Int) -> CGRect {
        let width = (bounds.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let height = (bounds.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        return CGRect(x: CGFloat(column) * (width + gap), y: CGFloat(row) * (height + gap), width: width, height: height)
    }

    private func cell(at event: NSEvent) -> (Int, Int) {
        let point = convert(event.locationInWindow, from: nil)
        let column = Int(point.x / (bounds.width + gap) * CGFloat(columns))
        let row = Int(point.y / (bounds.height + gap) * CGFloat(rows))
        return (min(max(column, 0), columns - 1), min(max(row, 0), rows - 1))
    }

    private func paint(_ pick: Pick?) {
        for (index, cell) in layers.enumerated() {
            let column = index % columns, row = index / columns
            let inside = pick.map { column >= $0.left && column < $0.left + $0.width && row >= $0.top && row < $0.top + $0.height } ?? false
            cell.backgroundColor = NSColor(white: 1, alpha: inside ? 0.72 : 0.14).cgColor
        }
    }

    private func show(_ pick: Pick?, final: Bool = false) {
        paint(pick)
        change(pick, final)
    }

    override func mouseMoved(with event: NSEvent) {
        guard anchor == nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return mouseExited(with: event) }
        let now = cell(at: event)
        guard hover.map({ $0 != now }) ?? true else { return }
        hover = now
        show(Pick(columns: columns, rows: rows, from: now, to: now))
    }

    override func mouseExited(with event: NSEvent) {
        guard anchor == nil, hover != nil else { return }
        hover = nil
        show(nil)
    }

    override func mouseDown(with event: NSEvent) {
        let now = cell(at: event)
        anchor = now
        hover = now
        show(Pick(columns: columns, rows: rows, from: now, to: now))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let now = cell(at: event)
        guard hover.map({ $0 != now }) ?? true else { return }
        hover = now
        show(Pick(columns: columns, rows: rows, from: anchor, to: now))
    }

    override func mouseUp(with event: NSEvent) {
        guard let anchor else { return }
        show(Pick(columns: columns, rows: rows, from: anchor, to: cell(at: event)), final: true)
    }
}

/// A panel that takes keys without making its app active, so the front app and its window stay in front.
final class Board: NSPanel {
    var cancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { cancel() } else { super.keyDown(with: event) }
    }

    override func cancelOperation(_ sender: Any?) { cancel() }
}

/// The grid at the centre of the screen of the front window, with the shade behind it on the desktop.
/// Once, it prints the pick on release and quits. Staying, it waits for SIGUSR1 to show, and moves the window itself
/// with `openspot window move`. Escape, the close button or a click elsewhere hides it with no pick.
final class Grid: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let columns = 6
    private let rows = 6
    private let width: CGFloat = 300
    private let stays: Bool
    private let host: pid_t?
    private var board: Board?
    private var shade: Shade?
    private var monitor: Any?
    private var sources: [DispatchSourceProtocol] = []

    init(stays: Bool, host: pid_t?) {
        self.stays = stays
        self.host = host
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard stays else { return show() }
        signal(SIGUSR1, SIG_IGN)
        let press = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        press.setEventHandler { [unowned self] in show() }
        press.resume()
        sources.append(press)
        if let host {
            let end = DispatchSource.makeProcessSource(identifier: host, eventMask: .exit, queue: .main)
            end.setEventHandler { exit(0) }
            end.resume()
            sources.append(end)
            if kill(host, 0) != 0 { exit(0) }
        }
        show(visible: false)
        finish(nil)
    }

    /// Builds the grid for the screen of the front window and shows it, or does nothing while it shows.
    /// A grid that is not visible draws once out of sight, so that the first press finds AppKit warm.
    private func show(visible: Bool = true) {
        guard board == nil else { return }
        let front = Front.read()
        let area = front.area
        let pad: CGFloat = 16, head: CGFloat = 78
        let cellsWidth = width - pad * 2
        let cellsHeight = (cellsWidth * area.height / max(area.width, 1)).rounded()
        let size = CGSize(width: width, height: head + cellsHeight + pad)
        let origin = CGPoint(x: (area.midX - size.width / 2).rounded(), y: (area.midY - size.height / 2).rounded())

        let shade = Shade(area: area)
        let board = Board(contentRect: CGRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        board.isOpaque = false
        board.backgroundColor = .clear
        board.hasShadow = true
        board.level = .floating
        board.isFloatingPanel = true
        board.hidesOnDeactivate = false
        board.isReleasedWhenClosed = false
        board.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        board.appearance = NSAppearance(named: .vibrantDark)
        board.cancel = { [unowned self] in finish(nil) }

        let glass = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.maskImage = Self.mask(radius: 22)

        let icon = NSImageView(frame: CGRect(x: (size.width - 32) / 2, y: size.height - 14 - 32, width: 32, height: 32))
        icon.image = front.app?.icon
        glass.addSubview(icon)

        let name = NSTextField(labelWithString: front.app?.localizedName ?? "")
        name.font = .systemFont(ofSize: 12, weight: .semibold)
        name.textColor = .labelColor
        name.alignment = .center
        name.frame = CGRect(x: pad, y: size.height - 14 - 32 - 22, width: size.width - pad * 2, height: 16)
        glass.addSubview(name)

        let close = NSButton(title: "✕", target: self, action: #selector(closeGrid))
        close.isBordered = false
        close.font = .systemFont(ofSize: 11, weight: .medium)
        close.contentTintColor = .secondaryLabelColor
        close.frame = CGRect(x: 10, y: size.height - 30, width: 20, height: 20)
        glass.addSubview(close)

        let cells = Cells(frame: CGRect(x: pad, y: pad, width: cellsWidth, height: cellsHeight), columns: columns, rows: rows)
        cells.change = { [unowned self] pick, final in
            if final { finish(pick) } else { self.shade?.show(pick) }
        }
        glass.addSubview(cells)
        board.contentView = glass

        self.board = board
        self.shade = shade
        guard visible else {
            board.alphaValue = 0
            board.orderFrontRegardless()
            board.display()
            return
        }
        board.delegate = self
        board.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [unowned self] _ in finish(nil) }
    }

    /// A stretchable rounded shape, so the blur, the window's shape and its shadow all keep the same corners.
    private static func mask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: CGSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    @objc private func closeGrid() { finish(nil) }

    func windowDidResignKey(_ notification: Notification) { finish(nil) }

    private func finish(_ pick: Pick?) {
        guard let board else { return }
        self.board = nil
        board.delegate = nil
        board.orderOut(nil)
        shade?.hide()
        shade = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard stays else {
            if let pick { FileHandle.standardOutput.write(Data((pick.text + "\n").utf8)) }
            exit(0)
        }
        guard let pick else { return }
        let move = Process()
        move.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        move.arguments = ["openspot", "window", "move", pick.text]
        try? move.run()
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "pick" {
    let numbers = arguments.dropFirst().compactMap { Int($0) }
    guard numbers.count == 6, numbers[0] > 0, numbers[1] > 0 else {
        FileHandle.standardError.write(Data("Use: grid pick <columns> <rows> <column> <row> <column> <row>\n".utf8))
        exit(2)
    }
    print(Pick(columns: numbers[0], rows: numbers[1], from: (numbers[2], numbers[3]), to: (numbers[4], numbers[5])).text)
    exit(0)
}

let app = NSApplication.shared
let grid = Grid(stays: arguments.first == "stay", host: arguments.count > 1 ? pid_t(arguments[1]) : nil)
app.setActivationPolicy(.accessory)
app.delegate = grid
app.run()
