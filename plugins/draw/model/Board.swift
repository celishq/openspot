import CoreGraphics
import Foundation

/// A drawing that a person keeps: its title and its figures, from the bottom one to the top one.
/// An arrow end that holds a figure follows it, so the board works out the path of each arrow when it is drawn.
struct Board: Codable, Equatable {
    var title = "Untitled board"
    var figures: [Figure] = []

    /// The gap between the tip of an arrow and the outline of the box that it holds.
    static let gap: CGFloat = 8

    init(title: String = "Untitled board", figures: [Figure] = []) {
        self.title = title
        self.figures = figures
    }

    static func load(from url: URL) throws -> Board {
        try JSONDecoder().decode(Board.self, from: Data(contentsOf: url))
    }

    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    subscript(id: UUID) -> Figure? {
        figures.first { $0.id == id }
    }

    mutating func add(_ figure: Figure) {
        figures.append(figure)
    }

    /// Changes the figure with this id in place.
    mutating func update(_ id: UUID, _ change: (inout Figure) -> Void) {
        guard let index = figures.firstIndex(where: { $0.id == id }) else { return }
        change(&figures[index])
    }

    // MARK: Paths

    /// The anchor of one end of a link: the centre of the figure that holds it, or its own point.
    private func anchor(_ figure: Figure, start: Bool) -> CGPoint {
        let held = start ? figure.start : figure.end
        if let held, let other = self[held] {
            return other.kind == .junction ? other.points[0] : CGPoint(x: other.frame.midX, y: other.frame.midY)
        }
        return start ? figure.points[0] : figure.points[figure.points.count - 1]
    }

    /// The arrow that leaves a junction.
    func trunk(of junction: UUID) -> Figure? {
        figures.first { $0.kind == .arrow && $0.start == junction }
    }

    /// The arrows that end at a junction.
    func branches(of junction: UUID) -> [Figure] {
        figures.filter { $0.kind == .arrow && $0.end == junction }
    }

    /// The points of a figure's line, from its start to its end. A held end stops at the outline of its box.
    func path(of figure: Figure) -> [CGPoint] {
        switch figure.kind {
        case .pen:
            return figure.points
        case .line, .arrow:
            break
        default:
            let box = figure.frame
            return [box.origin, CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY), box.origin]
        }
        let a = anchor(figure, start: true)
        let b = anchor(figure, start: false)
        guard figure.kind == .arrow else { return [a, b] }
        let middle = (a + b) * 0.5 + (b - a).unit.normal * (figure.bend * 2)
        var curve: [CGPoint]
        if let end = figure.end, self[end]?.kind == .junction, let trunk = trunk(of: end), trunk.id != figure.id {
            let way = (anchor(trunk, start: false) - b).unit
            let reach = a.distance(to: b) * 0.45
            let first = a + (middle - a) * 0.6
            let second = b - way * reach
            curve = (0...48).map { step in
                let t = CGFloat(step) / 48
                let u = 1 - t
                return a * (u * u * u) + first * (3 * u * u * t) + second * (3 * u * t * t) + b * (t * t * t)
            }
        } else {
            curve = (0...48).map { step in
                let t = CGFloat(step) / 48
                let u = 1 - t
                return a * (u * u) + middle * (2 * u * t) + b * (t * t)
            }
        }
        if let start = figure.start, let box = self[start], box.isBox {
            while curve.count > 2, box.holds(curve[1], pad: Self.gap) { curve.removeFirst() }
            if box.holds(curve[0], pad: Self.gap) { curve[0] = edge(of: box, from: curve[1], to: curve[0]) }
        }
        if let end = figure.end, let box = self[end], box.isBox {
            while curve.count > 2, box.holds(curve[curve.count - 2], pad: Self.gap) { curve.removeLast() }
            let last = curve.count - 1
            if box.holds(curve[last], pad: Self.gap) { curve[last] = edge(of: box, from: curve[last - 1], to: curve[last]) }
        }
        return curve
    }

    /// The point where the step from `outside` to `inside` meets the grown outline of a box.
    private func edge(of box: Figure, from outside: CGPoint, to inside: CGPoint) -> CGPoint {
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<20 {
            let middle = (low + high) / 2
            if box.holds(outside + (inside - outside) * middle, pad: Self.gap) { high = middle } else { low = middle }
        }
        return outside + (inside - outside) * low
    }

    /// The smallest rectangle around a figure.
    func bounds(of figure: Figure) -> CGRect {
        if figure.kind == .junction {
            return CGRect(x: figure.points[0].x - 8, y: figure.points[0].y - 8, width: 16, height: 16)
        }
        let points = path(of: figure)
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    // MARK: Finding

    /// The top figure under a point, within `tolerance` of a line.
    func figure(at point: CGPoint, tolerance: CGFloat = 6) -> Figure? {
        figures.last { figure in
            switch figure.kind {
            case .junction:
                return point.distance(to: figure.points[0]) <= 10 + tolerance
            case .rectangle, .ellipse, .text:
                return figure.holds(point, pad: tolerance)
            case .arrow, .line, .pen:
                let line = path(of: figure)
                let reach = tolerance + figure.weight.width / 2
                if line.count == 1 { return point.distance(to: line[0]) <= reach }
                return zip(line, line.dropFirst()).contains { point.distance(toSegment: $0, $1) <= reach }
            }
        }
    }

    /// The box or junction that an arrow end at this point would hold.
    func target(at point: CGPoint, except: Set<UUID> = []) -> UUID? {
        figures.last { figure in
            guard !except.contains(figure.id) else { return false }
            if figure.kind == .junction { return point.distance(to: figure.points[0]) <= 14 }
            return figure.isBox && figure.holds(point)
        }?.id
    }

    /// The figures that lie wholly inside a rectangle.
    func figures(in rect: CGRect) -> [UUID] {
        figures.filter { rect.contains(bounds(of: $0)) }.map(\.id)
    }

    // MARK: Changing

    /// Moves figures. A link end that holds a figure which stays lets go of it where it is.
    mutating func move(_ ids: Set<UUID>, by delta: CGPoint) {
        for index in figures.indices where ids.contains(figures[index].id) {
            let figure = figures[index]
            if figure.isLink {
                let line = path(of: figure)
                if let start = figure.start, !ids.contains(start) {
                    figures[index].points[0] = line[0]
                    figures[index].start = nil
                }
                if let end = figure.end, !ids.contains(end) {
                    figures[index].points[figure.points.count - 1] = line[line.count - 1]
                    figures[index].end = nil
                }
            }
            figures[index].points = figures[index].points.map { $0 + delta }
        }
        settle()
    }

    /// Removes figures. Removing a junction or the arrow that leaves it splits its bundle back into arrows, and an
    /// arrow that held a removed figure keeps its end where it was.
    mutating func remove(_ ids: Set<UUID>) {
        var gone = ids
        for id in ids {
            if let figure = self[id], figure.kind == .arrow, let start = figure.start, self[start]?.kind == .junction {
                gone.remove(id)
                gone.insert(start)
            }
        }
        for junction in gone where self[junction]?.kind == .junction {
            split(junction)
        }
        for index in figures.indices where figures[index].isLink {
            let line = path(of: figures[index])
            if let start = figures[index].start, gone.contains(start) {
                figures[index].points[0] = line[0]
                figures[index].start = nil
            }
            if let end = figures[index].end, gone.contains(end) {
                figures[index].points[figures[index].points.count - 1] = line[line.count - 1]
                figures[index].end = nil
            }
        }
        figures.removeAll { gone.contains($0.id) }
        settle()
    }

    /// Sends each branch of a junction to where its trunk goes, and removes the junction and the trunk.
    mutating func split(_ junction: UUID) {
        guard let trunk = trunk(of: junction) else {
            for branch in branches(of: junction) {
                update(branch.id) { $0.end = nil }
            }
            figures.removeAll { $0.id == junction }
            return
        }
        for branch in branches(of: junction) {
            update(branch.id) { arrow in
                arrow.end = trunk.end
                arrow.points[arrow.points.count - 1] = trunk.points[trunk.points.count - 1]
            }
        }
        figures.removeAll { $0.id == junction || $0.id == trunk.id }
    }

    /// Splits each junction that no longer joins two arrows.
    private mutating func settle() {
        for junction in figures.filter({ $0.kind == .junction }) {
            let branches = branches(of: junction.id)
            let trunk = trunk(of: junction.id)
            if trunk == nil {
                for branch in branches {
                    update(branch.id) { arrow in
                        arrow.end = nil
                        arrow.points[arrow.points.count - 1] = junction.points[0]
                    }
                }
                figures.removeAll { $0.id == junction.id }
            } else if branches.count < 2 {
                split(junction.id)
            }
        }
    }
}
