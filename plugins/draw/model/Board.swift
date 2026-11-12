import CoreGraphics
import Foundation

/// A drawing that a person keeps: its title and its figures, from the bottom one to the top one.
/// An arrow end that holds a shape follows it, and an arrow that passes ties runs through each of them beside the other
/// arrows of that tie, so the board works out the path of each arrow when it is drawn.
struct Board: Codable, Equatable {
    var title = "Untitled board"
    var figures: [Figure] = []

    private enum CodingKeys: String, CodingKey {
        case title, figures
    }

    /// The gap between the tip of an arrow and the outline of the shape that it holds.
    static let gap: CGFloat = 8

    init(title: String = "Untitled board", figures: [Figure] = []) {
        self.title = title
        self.figures = figures
    }

    /// Reads a board, and turns each junction of an older board, where arrows merged into one, into a tie.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "Untitled board"
        figures = try values.decode([Figure].self, forKey: .figures)
        for junction in figures where junction.kind == .tie && junction.members.isEmpty {
            let branches = figures.filter { $0.kind == .arrow && $0.end == junction.id }
            guard let trunk = figures.first(where: { $0.kind == .arrow && $0.start == junction.id }), branches.count > 1 else {
                figures.removeAll { $0.id == junction.id }
                continue
            }
            for branch in branches {
                update(branch.id) { arrow in
                    arrow.end = trunk.end
                    arrow.points[arrow.points.count - 1] = trunk.points[trunk.points.count - 1]
                    arrow.ties = [junction.id]
                }
            }
            update(junction.id) { $0.members = branches.map(\.id) }
            figures.removeAll { $0.id == trunk.id }
        }
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

    /// The anchor of one end of an arrow: the centre of the shape that holds it, or its own point.
    func anchor(_ figure: Figure, start: Bool) -> CGPoint {
        let held = start ? figure.start : figure.end
        if let held, let other = self[held], other.isBox {
            return CGPoint(x: other.frame.midX, y: other.frame.midY)
        }
        return start ? figure.points[0] : figure.points[figure.points.count - 1]
    }

    /// The way the arrows run through a tie, as a unit vector: the sum of the ways they run, where an arrow that runs
    /// against the others counts turned round. Wires that meet from many sides still give their common way.
    func direction(of tie: Figure) -> CGPoint {
        let ways = tie.members.compactMap { id -> CGPoint? in
            guard let arrow = self[id], let place = arrow.ties.firstIndex(of: tie.id) else { return nil }
            let before = place == 0 ? anchor(arrow, start: true) : self[arrow.ties[place - 1]]?.points[0] ?? anchor(arrow, start: true)
            let after = place == arrow.ties.count - 1 ? anchor(arrow, start: false) : self[arrow.ties[place + 1]]?.points[0] ?? anchor(arrow, start: false)
            return (after - before).unit
        }
        guard let first = ways.first else { return CGPoint(x: 1, y: 0) }
        var common = ways.reduce(CGPoint.zero, +)
        if common.length < 0.5 { common = first }
        let sum = ways.reduce(CGPoint.zero) { total, way in
            total + (way.x * common.x + way.y * common.y < 0 ? way * -1 : way)
        }
        return sum.unit == .zero ? CGPoint(x: 1, y: 0) : sum.unit
    }

    /// The space between two arrows in a tie.
    func spacing(of tie: Figure) -> CGFloat {
        (tie.members.compactMap { self[$0]?.weight.width }.max() ?? 3.5) + 4
    }

    /// The place where an arrow passes a tie: its own lane beside the others.
    func lane(of arrow: Figure, in tie: Figure) -> CGPoint {
        let index = CGFloat(tie.members.firstIndex(of: arrow.id) ?? 0)
        let offset = (index - CGFloat(tie.members.count - 1) / 2) * spacing(of: tie)
        return tie.points[0] + direction(of: tie).normal * offset
    }

    /// The points of a figure's line, from its start to its end. A held end stops at the outline of its shape.
    func path(of figure: Figure) -> [CGPoint] {
        switch figure.kind {
        case .pen:
            return figure.points
        case .arrow:
            break
        default:
            let box = figure.frame
            return [box.origin, CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY), box.origin]
        }
        var a = anchor(figure, start: true)
        var b = anchor(figure, start: false)
        let ties = figure.ties.compactMap { self[$0] }
        if let first = ties.first, figure.start != nil { a = a + (lane(of: figure, in: first) - first.points[0]) }
        if let last = ties.last, figure.end != nil { b = b + (lane(of: figure, in: last) - last.points[0]) }
        var curve: [CGPoint]
        if ties.isEmpty {
            let middle = (a + b) * 0.5 + (b - a).unit.normal * (figure.bend * 2)
            curve = (0...48).map { step in
                let t = CGFloat(step) / 48
                let u = 1 - t
                return a * (u * u) + middle * (2 * u * t) + b * (t * t)
            }
        } else {
            let stops = [a] + ties.map { lane(of: figure, in: $0) } + [b]
            var ways = [(stops[1] - a).unit]
            for (index, tie) in ties.enumerated() {
                let way = direction(of: tie)
                let own = stops[index + 2] - stops[index]
                ways.append(way.x * own.x + way.y * own.y < 0 ? way * -1 : way)
            }
            ways.append((b - stops[stops.count - 2]).unit)
            curve = [a]
            for index in 0..<(stops.count - 1) {
                let from = stops[index]
                let to = stops[index + 1]
                let reach = from.distance(to: to) / 3
                let first = from + ways[index] * reach
                let second = to - ways[index + 1] * reach
                for step in 1...24 {
                    let t = CGFloat(step) / 24
                    let u = 1 - t
                    curve.append(from * (u * u * u) + first * (3 * u * u * t) + second * (3 * u * t * t) + to * (t * t * t))
                }
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

    /// The point where the step from `outside` to `inside` meets the grown outline of a shape.
    private func edge(of box: Figure, from outside: CGPoint, to inside: CGPoint) -> CGPoint {
        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<20 {
            let middle = (low + high) / 2
            if box.holds(outside + (inside - outside) * middle, pad: Self.gap) { high = middle } else { low = middle }
        }
        return outside + (inside - outside) * low
    }

    /// Half the length of the pill of a tie, across its arrows.
    func reach(of tie: Figure) -> CGFloat {
        CGFloat(max(tie.members.count - 1, 0)) * spacing(of: tie) / 2 + 9
    }

    /// The smallest rectangle around a figure.
    func bounds(of figure: Figure) -> CGRect {
        if figure.kind == .tie {
            let reach = reach(of: figure)
            return CGRect(x: figure.points[0].x - reach, y: figure.points[0].y - reach, width: reach * 2, height: reach * 2)
        }
        let points = path(of: figure)
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    // MARK: Finding

    /// The top figure under a point, within `tolerance` of a line. A tie lies above all else.
    func figure(at point: CGPoint, tolerance: CGFloat = 6) -> Figure? {
        let tie = figures.last { figure in
            guard figure.kind == .tie else { return false }
            let across = direction(of: figure).normal
            let reach = reach(of: figure)
            let center = figure.points[0]
            return point.distance(toSegment: center - across * reach, center + across * reach) <= 7 + tolerance
        }
        if let tie { return tie }
        return figures.last { figure in
            switch figure.kind {
            case .tie:
                return false
            case .shape, .text, .image:
                return figure.holds(point, pad: tolerance)
            case .arrow, .pen:
                let line = path(of: figure)
                let reach = tolerance + figure.weight.width / 2
                if line.count == 1 { return point.distance(to: line[0]) <= reach }
                return zip(line, line.dropFirst()).contains { point.distance(toSegment: $0, $1) <= reach }
            }
        }
    }

    /// The shape or text that an arrow end at this point would hold.
    func target(at point: CGPoint, except: Set<UUID> = []) -> UUID? {
        figures.last { !except.contains($0.id) && $0.isBox && $0.holds(point) }?.id
    }

    /// The figures that lie wholly inside a rectangle.
    func figures(in rect: CGRect) -> [UUID] {
        figures.filter { rect.contains(bounds(of: $0)) }.map(\.id)
    }

    // MARK: Changing

    /// Moves figures. An arrow end that holds a shape which stays lets go of it where it is.
    mutating func move(_ ids: Set<UUID>, by delta: CGPoint) {
        for index in figures.indices where ids.contains(figures[index].id) {
            let figure = figures[index]
            if figure.kind == .arrow {
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
        sortLanes()
    }

    /// Removes figures. Removing a tie unties its arrows, a tie left with one arrow goes too, and an arrow that held a
    /// removed shape keeps its end where it was.
    mutating func remove(_ ids: Set<UUID>) {
        for index in figures.indices where figures[index].kind == .arrow {
            let line = path(of: figures[index])
            if let start = figures[index].start, ids.contains(start) {
                figures[index].points[0] = line[0]
                figures[index].start = nil
            }
            if let end = figures[index].end, ids.contains(end) {
                figures[index].points[figures[index].points.count - 1] = line[line.count - 1]
                figures[index].end = nil
            }
        }
        figures.removeAll { ids.contains($0.id) }
        var gone = ids
        for index in figures.indices where figures[index].kind == .tie {
            figures[index].members.removeAll { gone.contains($0) }
            if figures[index].members.count < 2 { gone.insert(figures[index].id) }
        }
        figures.removeAll { $0.kind == .tie && gone.contains($0.id) }
        for index in figures.indices where figures[index].kind == .arrow {
            figures[index].ties.removeAll { gone.contains($0) }
        }
    }
}
