import AppKit

/// Draws the figures of a board into the current graphics context, which is flipped so that y goes down.
struct Painting {
    let board: Board
    /// Figures drawn faint, such as those the eraser has passed over.
    var faint: Set<UUID> = []
    /// Figures whose words are not drawn, because a field edits them.
    var wordless: Set<UUID> = []

    func draw(in context: CGContext) {
        for figure in board.figures.filter({ $0.kind != .junction }) + board.figures.filter({ $0.kind == .junction }) {
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
        case .rectangle, .ellipse:
            let box = figure.frame
            let path = figure.kind == .rectangle
                ? CGPath(roundedRect: box, cornerWidth: min(10, box.width / 2), cornerHeight: min(10, box.height / 2), transform: nil)
                : CGPath(ellipseIn: box, transform: nil)
            if figure.filled {
                context.setFillColor(figure.ink.tint.cgColor)
                context.addPath(path)
                context.fillPath()
            }
            context.addPath(path)
            context.strokePath()
            if !wordless.contains(figure.id) { label(figure) }
        case .text:
            if !wordless.contains(figure.id) { figure.words.draw(in: figure.frame) }
        case .pen:
            context.addPath(Painting.smooth(figure.points))
            context.strokePath()
        case .line:
            let line = board.path(of: figure)
            context.addLines(between: line)
            context.strokePath()
        case .arrow:
            let line = board.path(of: figure)
            context.addLines(between: line)
            context.strokePath()
            let joined = figure.end.flatMap { board[$0] }?.kind == .junction
            if !joined, line.count > 1 {
                context.setLineDash(phase: 0, lengths: [])
                head(at: line[line.count - 1], from: line[max(0, line.count - 4)], width: width, in: context)
            }
        case .junction:
            junction(figure, in: context)
        }
    }

    /// The words inside a box, wrapped and centred.
    private func label(_ figure: Figure) {
        guard !figure.text.isEmpty else { return }
        let box = figure.frame.insetBy(dx: 10, dy: 8)
        let words = figure.words
        let size = words.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).size
        words.draw(with: CGRect(x: box.minX, y: box.midY - size.height / 2, width: box.width, height: size.height), options: [.usesLineFragmentOrigin])
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

    /// The pill where the arrows of a bundle meet, turned along the arrow that leaves it.
    private func junction(_ figure: Figure, in context: CGContext) {
        let center = figure.points[0]
        var angle: CGFloat = 0
        if let trunk = board.trunk(of: figure.id) {
            let line = board.path(of: trunk)
            if line.count > 1 {
                let way = line[1] - line[0]
                angle = atan2(way.y, way.x)
            }
        }
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [])
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)
        let pill = CGPath(roundedRect: CGRect(x: -6, y: -11, width: 12, height: 22), cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(pill)
        context.fillPath()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(2.5)
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
        let shown = board.figures.filter { $0.kind != .junction }
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
