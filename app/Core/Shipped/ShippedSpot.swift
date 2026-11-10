import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case spots(CatalogSpot)
    case new(NewSpot)
    case settings(SettingsSpot)
    case updates(UpdateSpot)
    case review(ReviewSpot)
    /// The sheet of a file that does not load.
    case fault(FaultSpot)
    case quit(QuitSpot)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String, config: ConfigFile = .standard(), update: UpdateSpot? = nil, core: URL? = nil, login: LoginItem? = nil, link: CommandLink? = nil, offersLogin: Bool = false, quit: QuitSpot? = nil) -> [Spot] {
        var commands = [
            Spot(
                id: spotsID,
                name: "Spots",
                url: folder,
                kind: .list,
                size: .small,
                symbol: "puzzlepiece.extension",
                subtitle: "Turn on",
                key: CommandKey(name: "p"),
                read: .sheet,
                order: 1,
                shipped: .spots(CatalogSpot(folder: folder, core: core, config: config, login: offersLogin ? login : nil))
            ),
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
                setsKeys: true
            ),
            Spot(
                id: newID,
                name: "New spot",
                url: folder,
                kind: .list,
                size: .small,
                symbol: "plus",
                subtitle: "Make your own",
                read: .sheet,
                order: 3,
                shipped: .new(NewSpot(folder: folder, guide: guide, prompt: AgentPrompt(folder: folder, guide: guide, app: app)))
            )
        ]
        if let update {
            commands.insert(
                Spot(
                    id: "openspot/updates",
                    name: "Updates",
                    url: folder,
                    symbol: "arrow.triangle.2.circlepath",
                    read: .panel,
                    order: .min,
                    shipped: .updates(update),
                    isOnGrid: false,
                    sizes: SpotSize.all.filter { $0.columns > 1 },
                    readsOnUpdate: true
                ),
                at: 0
            )
        }
        if let quit {
            commands.append(Spot(id: quitID, name: "Quit", url: folder, symbol: "power", subtitle: "Openspot", shipped: .quit(quit), isOnGrid: false))
        }
        return commands
    }

    /// The ID of the list of spots that a person can turn on.
    public static let spotsID = "openspot/spots"
    public static let settingsID = "openspot/settings"

    /// The ID of the sheet that makes a new spot, which ⌘N opens.
    public static let newID = "openspot/new"

    /// The ID of the plugin that holds the cards of the files that do not load.
    public static let faultsID = "openspot/faults"

    /// The ID of the command that ends the app.
    public static let quitID = "openspot/quit"

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

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        switch self {
        case .spots(let catalog): try catalog.answer(arguments)
        case .new(let new): try await new.answer(arguments, input: input)
        case .settings(let settings): try settings.answer(arguments)
        case .updates(let update): try await update.answer(arguments)
        case .review(let review): try review.answer(arguments)
        case .fault(let fault): try await fault.answer(arguments)
        case .quit(let quit): await quit.answer()
        }
    }
}
