import AppKit

/// Draws the figures of a board into the current graphics context, which is flipped so that y goes down.
@MainActor
struct Painting {
    let board: Board
    /// The folder of the board's images.
    var assets: URL?
    /// Figures drawn faint, such as those the eraser has passed over.
    var faint: Set<UUID> = []
    /// Figures whose words are not drawn, because a field edits them.
    var wordless: Set<UUID> = []

    func draw(in context: CGContext) {
        for figure in board.figures.filter({ $0.kind != .tie }) + board.figures.filter({ $0.kind == .tie }) {
            context.saveGState()
            if faint.contains(figure.id) { context.setAlpha(0.25) }
            draw(figure, in: context)
            context.restoreGState()
        }
    }

    private func draw(_ figure: Figure, in context: CGContext) {
        let width = figure.weight.width
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(figure.ink.color.cgColor)
        if figure.dashed { context.setLineDash(phase: 0, lengths: [width * 2.2, width * 2.2]) }
        switch figure.kind {
        case .shape:
            let box = figure.frame
            let path = figure.form.path(in: box)
            if figure.filled {
                context.setFillColor(figure.ink.tint.cgColor)
                context.addPath(path)
                context.fillPath()
            }
            context.addPath(path)
            context.strokePath()
            if let marks = figure.form.marks(in: box) {
                context.addPath(marks)
                context.strokePath()
            }
            if !wordless.contains(figure.id) { label(figure) }
        case .text:
            if !wordless.contains(figure.id) { label(figure) }
        case .image:
            if let assets, let image = Painting.image(assets.appendingPathComponent(figure.source)) {
                image.draw(in: figure.frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } else {
                context.setFillColor(NSColor(white: 0.94, alpha: 1).cgColor)
                context.fill(figure.frame)
            }
        case .pen:
            context.addPath(Painting.smooth(figure.points))
            context.strokePath()
        case .arrow:
            let line = board.path(of: figure)
            context.addLines(between: line)
            context.strokePath()
            guard line.count > 1 else { return }
            context.setLineDash(phase: 0, lengths: [])
            if figure.heads != .none {
                head(at: line[line.count - 1], from: Painting.back(line.reversed(), by: 10 + width * 2.2), width: width, in: context)
            }
            if figure.heads == .both {
                head(at: line[0], from: Painting.back(line, by: 10 + width * 2.2), width: width, in: context)
            }
        case .tie:
            tie(figure, in: context)
        }
    }

    /// The words of a shape or a text, wrapped, and placed as the figure aligns them.
    private func label(_ figure: Figure) {
        guard !figure.text.isEmpty else { return }
        let box = figure.kind == .text ? figure.frame : figure.frame.insetBy(dx: 10, dy: 8)
        let words = figure.words
        let size = words.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).size
        let top: CGFloat = switch figure.place {
        case .top: box.minY
        case .middle: box.midY - size.height / 2
        case .bottom: box.maxY - size.height
        }
        words.draw(with: CGRect(x: box.minX, y: top, width: box.width, height: size.height), options: [.usesLineFragmentOrigin])
    }

    /// The images read so far, by file.
    private static var images: [URL: NSImage] = [:]

    static func image(_ file: URL) -> NSImage? {
        if let image = images[file] { return image }
        guard let image = NSImage(contentsOf: file) else { return nil }
        images[file] = image
        return image
    }

    private func head(at tip: CGPoint, from back: CGPoint, width: CGFloat, in context: CGContext) {
        let way = (tip - back).unit
        guard way != .zero else { return }
        let length = 10 + width * 2.2
        let side = way.normal * (length * 0.55)
        let base = tip - way * length
        context.move(to: base + side)
        context.addLine(to: tip)
        context.addLine(to: base - side)
        context.strokePath()
    }

    /// The first point of a line that lies this far from its first point, so a head points along the end of a curve.
    static func back(_ line: some Collection<CGPoint>, by reach: CGFloat) -> CGPoint {
        guard let tip = line.first else { return .zero }
        return line.first { $0.distance(to: tip) >= reach } ?? line.reversed().first ?? tip
    }

    /// The pill of a tie, laid across the arrows that it holds, in the tie's ink.
    private func tie(_ figure: Figure, in context: CGContext) {
        let center = figure.points[0]
        let way = board.direction(of: figure)
        let reach = board.reach(of: figure)
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [])
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: atan2(way.y, way.x))
        let pill = CGPath(roundedRect: CGRect(x: -5, y: -reach, width: 10, height: reach * 2), cornerWidth: 5, cornerHeight: 5, transform: nil)
        context.setFillColor(figure.ink.color.blended(withFraction: 0.65, of: .white)?.cgColor ?? NSColor.white.cgColor)
        context.addPath(pill)
        context.fillPath()
        context.setStrokeColor(figure.ink.color.cgColor)
        context.setLineWidth(2)
        context.addPath(pill)
        context.strokePath()
        context.restoreGState()
    }

    /// A curve through the middles of a stroke's steps, so the pen draws smooth.
    static func smooth(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count < 3 {
            for point in points.dropFirst() { path.addLine(to: point) }
            if points.count == 1 { path.addLine(to: first) }
            return path
        }
        for index in 1..<(points.count - 1) {
            let middle = (points[index] + points[index + 1]) * 0.5
            path.addQuadCurve(to: middle, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }

    /// A PNG of the whole board on white, fitted into this size.
    func picture(width: CGFloat, height: CGFloat) -> Data? {
        let shown = board.figures.filter { $0.kind != .tie }
        var area = shown.map { board.bounds(of: $0) }.reduce(CGRect.null) { $0.union($1) }
        if area.isNull { area = CGRect(x: 0, y: 0, width: width, height: height) }
        area = area.insetBy(dx: -24, dy: -24)
        let scale = min(width / area.width, height / area.height, 1.5)
        let image = NSImage(size: CGSize(width: width, height: height), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.translateBy(x: (width - area.width * scale) / 2, y: (height - area.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -area.minX, y: -area.minY)
            draw(in: context)
            return true
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
