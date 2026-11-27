import Foundation

public struct SessionWindow: Equatable, Sendable {
    public static let size = 5
    public static let reach = 2

    public struct Stop: Equatable, Sendable {
        public let place: SessionPlace
        public let at: Date
    }

    public enum Step: Equatable, Sendable {
        case stop(Stop)
        case present
    }

    public private(set) var stops: [Stop] = []
    public private(set) var index: Int?
    public private(set) var isWhole = false

    public var isWalking: Bool {
        index != nil
    }

    var needsOlder: Bool {
        !isWhole && stops.count - ((index ?? -1) + 1) <= Self.reach
    }

    var oldest: Date? {
        stops.last?.at
    }

    mutating func add(_ place: SessionPlace, at: Date) {
        if let first = stops.first, first.place.merges(with: place) { stops.removeFirst() }
        stops.insert(Stop(place: place, at: at), at: 0)
        stopWalking()
    }

    mutating func stopWalking() {
        index = nil
        guard stops.count > Self.size else { return }
        stops.removeLast(stops.count - Self.size)
        isWhole = false
    }

    mutating func back() -> Stop? {
        let next = (index ?? -1) + 1
        guard next < stops.count else { return nil }
        index = next
        return stops[next]
    }

    mutating func forward() -> Step? {
        guard let index else { return nil }
        guard index > 0 else {
            self.index = nil
            return .present
        }
        self.index = index - 1
        return .stop(stops[index - 1])
    }

    mutating func take(newest read: [Stop], isWhole whole: Bool) {
        guard !isWalking else { return }
        let unread = stops.filter { stop in read.first.map { stop.at > $0.at } ?? true }
        stops = Array((unread + read).prefix(Self.size))
        isWhole = whole && unread.count + read.count <= Self.size
    }

    mutating func take(older read: [Stop], before: Date?, isWhole whole: Bool) {
        guard oldest == before else { return }
        stops += read.filter { stop in before.map { stop.at < $0 } ?? true }
        isWhole = whole
    }
}
