import Foundation

public struct SettingsTrail: Equatable, Sendable {
    public struct Stop: Equatable, Sendable {
        public let page: SettingsPage
        public let mark: SettingsPage
    }

    public private(set) var now = Stop(page: .general, mark: .general)
    public private(set) var back: [Stop] = []
    public private(set) var forward: [Stop] = []

    public init() {}

    mutating func go(_ page: SettingsPage, remembers: Bool) {
        if remembers { back.append(now) }
        forward = []
        now = Stop(page: page, mark: Self.mark(of: page, after: now.mark))
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
        now = Stop(page: page, mark: Self.mark(of: page, after: .access))
    }

    private static func mark(of page: SettingsPage, after mark: SettingsPage) -> SettingsPage {
        if case .accessOf = page { return mark }
        return page
    }
}
