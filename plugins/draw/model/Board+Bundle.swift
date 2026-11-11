import CoreGraphics
import Foundation

/// Bundling: a stroke drawn across arrows that go to one place merges them at a junction, and one arrow goes on from it.
extension Board {
    /// The arrows that a stroke crosses, each with the first point where it crosses.
    func arrows(crossedBy stroke: [CGPoint]) -> [(arrow: Figure, at: CGPoint)] {
        figures.compactMap { figure in
            guard figure.kind == .arrow else { return nil }
            let line = path(of: figure)
            for (a, b) in zip(stroke, stroke.dropFirst()) {
                for (c, d) in zip(line, line.dropFirst()) {
                    if let point = CGPoint.crossing(a, b, c, d) { return (figure, point) }
                }
            }
            return nil
        }
    }

    /// Where an arrow goes: the figure that holds its end, past any junction. A free end goes nowhere.
    private func destination(of arrow: Figure) -> UUID? {
        if let start = arrow.start, self[start]?.kind == .junction { return arrow.end }
        if let end = arrow.end, self[end]?.kind == .junction { return trunk(of: end)?.end }
        return arrow.end
    }

    /// The junction that an arrow already belongs to.
    private func junction(of arrow: Figure) -> UUID? {
        if let start = arrow.start, self[start]?.kind == .junction { return start }
        if let end = arrow.end, self[end]?.kind == .junction { return end }
        return nil
    }

    /// Merges the arrows that a stroke crosses and that go to one place. Arrows that join a bundle the stroke crosses
    /// join its junction; else two or more arrows meet at a new junction where the stroke crossed them. Returns the junction,
    /// or nil when the stroke merged nothing.
    @discardableResult
    mutating func bundle(along stroke: [CGPoint]) -> UUID? {
        let crossed = arrows(crossedBy: stroke)
        var groups: [String: [(arrow: Figure, at: CGPoint)]] = [:]
        var order: [String] = []
        for hit in crossed {
            let key = destination(of: hit.arrow)?.uuidString ?? "free"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(hit)
        }
        let board = self
        let candidates = order.compactMap { key -> (existing: UUID?, loose: [(arrow: Figure, at: CGPoint)])? in
            let hits = groups[key] ?? []
            let existing = hits.compactMap { board.junction(of: $0.arrow) }.first
            let loose = hits.filter { board.junction(of: $0.arrow) == nil }
            if existing != nil ? loose.count >= 1 : loose.count >= 2 { return (existing, loose) }
            return nil
        }
        guard let chosen = candidates.max(by: { $0.loose.count < $1.loose.count }) else { return nil }
        if let existing = chosen.existing, let center = self[existing]?.points[0] {
            for hit in chosen.loose {
                update(hit.arrow.id) { arrow in
                    arrow.end = existing
                    arrow.points[arrow.points.count - 1] = center
                }
            }
            return existing
        }
        let loose = chosen.loose
        let center = loose.map(\.at).reduce(CGPoint.zero, +) * (1 / CGFloat(loose.count))
        let first = loose[0].arrow
        let target = first.end
        let ends = loose.map { path(of: $0.arrow).last ?? $0.at }
        let free = ends.reduce(CGPoint.zero, +) * (1 / CGFloat(ends.count))
        let junction = Figure(kind: .junction, points: [center], ink: first.ink)
        var trunk = Figure(kind: .arrow, points: [center, target.flatMap { self[$0] }.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? free])
        trunk.ink = first.ink
        trunk.weight = first.weight
        trunk.dashed = first.dashed
        trunk.start = junction.id
        trunk.end = target
        for hit in loose {
            update(hit.arrow.id) { arrow in
                arrow.end = junction.id
                arrow.points[arrow.points.count - 1] = center
            }
        }
        add(junction)
        add(trunk)
        return junction.id
    }
}
