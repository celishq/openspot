import AppKit

/// A picture with red arrows and boxes drawn over it. A drag draws the mark of the tool, A picks the arrow and B the box,
/// ⌘Z takes the last mark away, Return saves the picture with its marks, and Escape closes it as it was.
final class Canvas: NSView {
    enum Tool {
        case arrow
        case box
    }

    struct Mark {
        var tool: Tool
        var from: CGPoint
        var to: CGPoint
    }

    private let picture: NSImage
    private let file: URL
    private var marks: [Mark] = []
    private var drawing: Mark?
    private var tool = Tool.arrow

    init(picture: NSImage, file: URL) {
        self.picture = picture
        self.file = file
        super.init(frame: CGRect(origin: .zero, size: picture.size))
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        picture.draw(in: bounds)
        (marks + (drawing.map { [$0] } ?? [])).forEach(Self.draw)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        drawing = Mark(tool: tool, from: point, to: point)
    }

    override func mouseDragged(with event: NSEvent) {
        drawing?.to = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let mark = drawing, hypot(mark.to.x - mark.from.x, mark.to.y - mark.from.y) > 3 { marks.append(mark) }
        drawing = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (key, event.modifierFlags.contains(.command)) {
        case ("a", false): tool = .arrow
        case ("b", false): tool = .box
        case ("z", true):
            _ = marks.popLast()
            needsDisplay = true
        case ("\r", _): finish(saving: true)
        case ("\u{1b}", _): finish(saving: false)
        default: super.keyDown(with: event)
        }
    }

    /// Writes the picture with its marks at the pixels of the file when asked, and ends the editor.
    func finish(saving: Bool) {
        if saving, !marks.isEmpty, let data = rendered() { try? data.write(to: file, options: .atomic) }
        exit(0)
    }

    private func rendered() -> Data? {
        guard let source = picture.representations.first,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: source.pixelsWide, pixelsHigh: source.pixelsHigh, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        bitmap.size = picture.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        picture.draw(in: CGRect(origin: .zero, size: picture.size))
        marks.forEach(Self.draw)
        NSGraphicsContext.restoreGraphicsState()
        let type: NSBitmapImageRep.FileType = ["jpg", "jpeg"].contains(file.pathExtension.lowercased()) ? .jpeg : .png
        return bitmap.representation(using: type, properties: [:])
    }

    private static func draw(_ mark: Mark) {
        NSColor.systemRed.set()
        let path = NSBezierPath()
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        switch mark.tool {
        case .box:
            path.appendRect(CGRect(x: min(mark.from.x, mark.to.x), y: min(mark.from.y, mark.to.y), width: abs(mark.to.x - mark.from.x), height: abs(mark.to.y - mark.from.y)))
        case .arrow:
            let angle = atan2(mark.to.y - mark.from.y, mark.to.x - mark.from.x)
            path.move(to: mark.from)
            path.line(to: mark.to)
            for side in [-0.5, 0.5] {
                path.move(to: mark.to)
                path.line(to: CGPoint(x: mark.to.x - 18 * cos(angle + side), y: mark.to.y - 18 * sin(angle + side)))
            }
        }
        path.stroke()
    }
}

let file = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "")
guard let picture = NSImage(contentsOf: file) else {
    FileHandle.standardError.write(Data("Openspot cannot open \(file.lastPathComponent) to mark it.\n".utf8))
    exit(1)
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let area = NSScreen.main?.visibleFrame.insetBy(dx: 80, dy: 80) ?? CGRect(x: 0, y: 0, width: 1200, height: 800)
let fit = min(1, area.width / picture.size.width, area.height / picture.size.height)
let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: picture.size.width * fit, height: picture.size.height * fit), styleMask: [.titled, .closable], backing: .buffered, defer: false)
let canvas = Canvas(picture: picture, file: file)
window.title = "Return saves · Escape closes · A arrow · B box · ⌘Z undo"
window.contentView = canvas
canvas.bounds = CGRect(origin: .zero, size: picture.size)
window.center()
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(canvas)
let closing = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in exit(0) }
app.activate()
app.run()
