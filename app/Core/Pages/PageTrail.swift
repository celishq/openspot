import Foundation

public struct PageTrail<Place: Equatable & Sendable>: Equatable, Sendable {
    @dynamicMemberLookup
    public struct Stop: Equatable, Sendable {
        public let value: Place
        public let visit: Int

        public subscript<Value>(dynamicMember path: KeyPath<Place, Value>) -> Value {
            value[keyPath: path]
        }
    }

    public private(set) var now: Stop
    public private(set) var back: [Stop] = []
    public private(set) var forward: [Stop] = []
    private var visits = 0

    public init(_ place: Place) {
        now = Stop(value: place, visit: 0)
    }

    mutating func go(_ place: Place, remembers: Bool = true) {
        if remembers { back.append(now) }
        forward = []
        now = Stop(value: place, visit: nextVisit())
    }

    @discardableResult
    mutating func goBack() -> Stop? {
        guard let last = back.popLast() else { return nil }
        forward.append(now)
        now = last
        return last
    }

    @discardableResult
    mutating func goForward() -> Stop? {
        guard let next = forward.popLast() else { return nil }
        back.append(now)
        now = next
        return next
    }

    mutating func land(_ place: Place) {
        back = []
        forward = []
        now = Stop(value: place, visit: nextVisit())
    }

    mutating func replace(_ place: Place) {
        now = Stop(value: place, visit: now.visit)
    }

    mutating func keep(where holds: (Place) -> Bool) {
        back.removeAll { !holds($0.value) }
        forward.removeAll { !holds($0.value) }
    }

    private mutating func nextVisit() -> Int {
        visits += 1
        return visits
    }
}
