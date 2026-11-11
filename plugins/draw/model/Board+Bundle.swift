import CoreGraphics
import Foundation

/// Bundling: a stroke drawn across two or more arrows ties them where it crossed them, like a cable tie on wires. Each
/// arrow keeps its own ends, and runs through the tie beside the others.
extension Board {
    /// The arrows that a stroke crosses, each with the first point where it crosses and the index of that point on its path.
    func arrows(crossedBy stroke: [CGPoint]) -> [(arrow: Figure, at: CGPoint, step: Int)] {
        figures.compactMap { figure in
            guard figure.kind == .arrow else { return nil }
            let line = path(of: figure)
            for (a, b) in zip(stroke, stroke.dropFirst()) {
                for (step, (c, d)) in zip(line, line.dropFirst()).enumerated() {
                    if let point = CGPoint.crossing(a, b, c, d) { return (figure, point, step) }
                }
            }
            return nil
        }
    }

    /// Ties the arrows that a stroke crosses, where it crossed them, side by side in the order the stroke met them across
    /// their way. Returns the tie, or nil when the stroke crossed fewer than two arrows.
    @discardableResult
    mutating func bundle(along stroke: [CGPoint]) -> UUID? {
        let crossed = arrows(crossedBy: stroke)
        guard crossed.count > 1 else { return nil }
        let center = crossed.map(\.at).reduce(CGPoint.zero, +) * (1 / CGFloat(crossed.count))
        var way = CGPoint.zero
        for hit in crossed {
            let line = path(of: hit.arrow)
            var own = (line[min(hit.step + 1, line.count - 1)] - line[hit.step]).unit
            if way != .zero, own.x * way.x + own.y * way.y < 0 { own = own * -1 }
            way = way == .zero ? own : way + own
        }
        let across = way.unit.normal
        let order = crossed.sorted { ($0.at - center).x * across.x + ($0.at - center).y * across.y < ($1.at - center).x * across.x + ($1.at - center).y * across.y }
        var tie = Figure(kind: .tie, points: [center])
        tie.members = order.map(\.arrow.id)
        for hit in crossed {
            let line = path(of: hit.arrow)
            let before = hit.arrow.ties.filter { id in
                guard let other = self[id] else { return false }
                let nearest = line.indices.min { line[$0].distance(to: other.points[0]) < line[$1].distance(to: other.points[0]) } ?? 0
                return nearest <= hit.step
            }.count
            update(hit.arrow.id) { $0.ties.insert(tie.id, at: before) }
        }
        add(tie)
        return tie.id
    }
}
