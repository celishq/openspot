import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case settings(SettingsSpot)
    case review(ReviewSpot)
    /// The sheet of a file that does not load.
    case fault(FaultSpot)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String, config: ConfigFile = .standard(), core: URL? = nil, login: LoginItem? = nil, link: CommandLink? = nil, offersLogin: Bool = false) -> [Spot] {
        [
            Spot(
                id: Self.settingsID,
                name: "Settings",
                url: config.url,
                kind: .list,
                size: .small,
                symbol: "gearshape",
                subtitle: "Choose your key",
                read: SpotRead(moments: [.panel, .sheet]),
                isGlobal: true,
                order: 2,
                shipped: .settings(SettingsSpot(file: config, folder: folder, core: core, login: login, link: link)),
                setsKeys: true,
                opensWithSettingsKey: true
            )
        ]
    }

    public static let settingsID = "openspot/settings"

    /// The ID of the plugin that holds the cards of the files that do not load.
    public static let faultsID = "openspot/faults"

    /// The ID of the sheet that shows a shared spot, which has no card in the grid.
    public static let installID = "openspot/install"

    /// The sheet that shows a shared spot before a person installs it.
    public static func command(reviewing review: ReviewSpot) -> Spot {
        Spot(
            id: installID,
            name: review.name,
            url: review.folder,
            kind: .list,
            symbol: review.symbol,
            subtitle: review.subtitle,
            read: .sheet,
            order: .max,
            shipped: .review(review)
        )
    }

    /// Whether the row of this run records a key that a shake can be too: a row of Settings that gives a key to a command or
    /// a float (W2).
    public func takesShake(_ run: String) -> Bool {
        if case .settings = self { SettingsSpot.takesShake(run) } else { false }
    }

    /// The action of another spot that Enter on a row of Settings runs to change one of its settings.
    public func settingChange(of run: String) -> (spot: String, action: CommandAction)? {
        if case .settings = self { SettingsSpot.change(of: run) } else { nil }
    }

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        switch self {
        case .settings(let settings): try settings.answer(arguments)
        case .review(let review): try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments)
        }
    }
}
