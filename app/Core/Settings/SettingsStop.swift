import Foundation

public struct SettingsStop: Equatable, Sendable {
    public let page: SettingsPage
    public let mark: SettingsPage

    public init(page: SettingsPage, mark: SettingsPage) {
        self.page = page
        self.mark = mark
    }

    func going(to page: SettingsPage) -> SettingsStop {
        SettingsStop(page: page, mark: Self.mark(of: page, after: mark))
    }

    static func landing(on page: SettingsPage) -> SettingsStop {
        SettingsStop(page: page, mark: mark(of: page, after: .access))
    }

    private static func mark(of page: SettingsPage, after mark: SettingsPage) -> SettingsPage {
        if case .accessOf = page { return mark }
        return page
    }
}
