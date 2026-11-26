import Foundation

public struct SettingsTrail: Equatable, Sendable {
    public struct Stop: Equatable, Sendable {
        public let page: SettingsPage
        public let mark: SettingsPage
        public let visit: Int
    }

    public private(set) var now = Stop(page: .general, mark: .general, visit: 0)
    public private(set) var back: [Stop] = []
    public private(set) var forward: [Stop] = []
    private var visits = 0

    public init() {}

    mutating func go(_ page: SettingsPage, remembers: Bool) {
        if remembers { back.append(now) }
        forward = []
        now = Stop(page: page, mark: Self.mark(of: page, after: now.mark), visit: nextVisit())
    }

    mutating func goBack() -> Bool {
        guard let last = back.popLast() else { return false }
        forward.append(now)
        now = last
        return true
    }

    mutating func goForward() -> Bool {
        guard let next = forward.popLast() else { return false }
        back.append(now)
        now = next
        return true
    }

    mutating func land(_ page: SettingsPage) {
        back = []
        forward = []
        now = Stop(page: page, mark: Self.mark(of: page, after: .access), visit: nextVisit())
    }

    private mutating func nextVisit() -> Int {
        visits += 1
        return visits
    }

    private static func mark(of page: SettingsPage, after mark: SettingsPage) -> SettingsPage {
        if case .accessOf = page { return mark }
        return page
    }
}
