import CoreGraphics

/// The outline of each form inside a frame, with y going down.
extension Figure.Form {
    func path(in frame: CGRect) -> CGPath {
        let w = frame.width
        let h = frame.height
        switch self {
        case .rectangle, .xBox, .checkBox:
            let corner = Self.corner(of: frame)
            return CGPath(roundedRect: frame, cornerWidth: corner, cornerHeight: corner, transform: nil)
        case .ellipse:
            return CGPath(ellipseIn: frame, transform: nil)
        case .oval:
            let corner = min(w, h) / 2
            return CGPath(roundedRect: frame, cornerWidth: corner, cornerHeight: corner, transform: nil)
        case .triangle:
            return polygon([(0.5, 0), (1, 1), (0, 1)], in: frame)
        case .diamond:
            return polygon([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)], in: frame)
        case .hexagon:
            return polygon([(0.25, 0), (0.75, 0), (1, 0.5), (0.75, 1), (0.25, 1), (0, 0.5)], in: frame)
        case .parallelogram:
            return polygon([(0.2, 0), (1, 0), (0.8, 1), (0, 1)], in: frame)
        case .star:
            let corners = (0..<10).map { index -> (CGFloat, CGFloat) in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
                let reach: CGFloat = index.isMultiple(of: 2) ? 0.5 : 0.21
                return (0.5 + cos(angle) * reach, 0.53 + sin(angle) * reach * 1.05)
            }
            return polygon(corners, in: frame)
        case .arrowRight, .arrowLeft, .arrowUp, .arrowDown:
            let right: [(CGFloat, CGFloat)] = [(0, 0.3), (0.6, 0.3), (0.6, 0), (1, 0.5), (0.6, 1), (0.6, 0.7), (0, 0.7)]
            let turned = right.map { u, v -> (CGFloat, CGFloat) in
                switch self {
                case .arrowLeft: (1 - u, v)
                case .arrowUp: (v, 1 - u)
                case .arrowDown: (v, u)
                default: (u, v)
                }
            }
            return polygon(turned, in: frame)
        case .heart:
            let path = CGMutablePath()
            let at = { (u: CGFloat, v: CGFloat) in CGPoint(x: frame.minX + u * w, y: frame.minY + v * h) }
            path.move(to: at(0.5, 1))
            path.addCurve(to: at(0, 0.32), control1: at(0.2, 0.8), control2: at(0, 0.58))
            path.addCurve(to: at(0.5, 0.16), control1: at(0, 0.02), control2: at(0.4, -0.04))
            path.addCurve(to: at(1, 0.32), control1: at(0.6, -0.04), control2: at(1, 0.02))
            path.addCurve(to: at(0.5, 1), control1: at(1, 0.58), control2: at(0.8, 0.8))
            path.closeSubpath()
            return path
        case .cloud:
            let puffs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0, 0.38, 0.34, 0.44), (0.18, 0.12, 0.38, 0.52), (0.42, 0, 0.4, 0.55), (0.66, 0.3, 0.34, 0.46), (0.12, 0.45, 0.76, 0.55)
            ]
            return puffs.map { x, y, width, height in
                CGPath(ellipseIn: CGRect(x: frame.minX + x * w, y: frame.minY + y * h, width: width * w, height: height * h), transform: nil)
            }.reduce(CGPath(rect: .null, transform: nil)) { $0.union($1) }
        }
    }

    /// The lines drawn inside a form, such as the cross of a crossed box.
    func marks(in frame: CGRect) -> CGPath? {
        let path = CGMutablePath()
        let at = { (u: CGFloat, v: CGFloat) in CGPoint(x: frame.minX + u * frame.width, y: frame.minY + v * frame.height) }
        switch self {
        case .xBox:
            let inset = Self.corner(of: frame) * (1 - 1 / 2.squareRoot())
            let box = frame.insetBy(dx: inset, dy: inset)
            path.move(to: CGPoint(x: box.minX, y: box.minY))
            path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
            path.move(to: CGPoint(x: box.maxX, y: box.minY))
            path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        case .checkBox:
            path.move(to: at(0.25, 0.52))
            path.addLine(to: at(0.43, 0.7))
            path.addLine(to: at(0.76, 0.3))
        default:
            return nil
        }
        return path
    }

    /// The radius of the corners of a box: small beside its size, and at most 10.
    private static func corner(of frame: CGRect) -> CGFloat {
        min(10, min(frame.width, frame.height) * 0.15)
    }

    private func polygon(_ corners: [(CGFloat, CGFloat)], in frame: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: corners.map { CGPoint(x: frame.minX + $0.0 * frame.width, y: frame.minY + $0.1 * frame.height) })
        path.closeSubpath()
        return path
    }
}
