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
    /// the tie by where each comes from, so each wire keeps its side and none crosses another. Returns the tie, or nil when the
    /// stroke crossed fewer than two arrows.
    @discardableResult
    mutating func bundle(along stroke: [CGPoint]) -> UUID? {
        let crossed = arrows(crossedBy: stroke)
        guard crossed.count > 1 else { return nil }
        let center = crossed.map(\.at).reduce(CGPoint.zero, +) * (1 / CGFloat(crossed.count))
        var tie = Figure(kind: .tie, points: [center])
        tie.ink = .blue
        tie.members = crossed.map(\.arrow.id)
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
        sortLanes()
        return tie.id
    }

    /// Puts the arrows of each tie side by side by where each comes from, the ties nearest the starts of their arrows first,
    /// so each wire keeps its side through every tie and none crosses another.
    mutating func sortLanes() {
        let board = self
        let rank = { (tie: Figure) in tie.members.compactMap { board[$0]?.ties.firstIndex(of: tie.id) }.min() ?? 0 }
        let ties = figures.filter { $0.kind == .tie }.sorted { rank($0) < rank($1) }
        for tie in ties {
            guard let current = self[tie.id] else { continue }
            let way = direction(of: current)
            let across = way.normal
            let center = current.points[0]
            let side = Dictionary(uniqueKeysWithValues: current.members.map { id -> (UUID, CGFloat) in
                let from = source(of: id, into: tie.id, along: way)
                return (id, (from - center).x * across.x + (from - center).y * across.y)
            })
            update(tie.id) { $0.members.sort { side[$0, default: 0] < side[$1, default: 0] } }
        }
    }

    /// Where an arrow comes from on its way into a tie: its own lane in the tie before, or its start. An arrow that runs
    /// the other way comes from its end, or from the tie after.
    private func source(of arrowID: UUID, into tieID: UUID, along way: CGPoint) -> CGPoint {
        guard let arrow = self[arrowID], let place = arrow.ties.firstIndex(of: tieID) else { return .zero }
        let before = place == 0 ? anchor(arrow, start: true) : self[arrow.ties[place - 1]].map { lane(of: arrow, in: $0) } ?? anchor(arrow, start: true)
        let after = place == arrow.ties.count - 1 ? anchor(arrow, start: false) : self[arrow.ties[place + 1]].map { lane(of: arrow, in: $0) } ?? anchor(arrow, start: false)
        let travel = after - before
        return travel.x * way.x + travel.y * way.y >= 0 ? before : after
    }
}
