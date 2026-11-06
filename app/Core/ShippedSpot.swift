import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case plugins(PluginGuide)
    case settings(Settings)
    case updates(UpdateSpot)
    case review(SpotReview)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String, config: ConfigFile = .standard(), update: UpdateSpot? = nil) -> [PluginCommand] {
        var commands = [
            PluginCommand(
                id: "openspot/plugins",
                name: "Plugins",
                url: folder,
                kind: .list,
                size: .small,
                symbol: "puzzlepiece.extension",
                subtitle: "Add your own",
                key: CommandKey(name: "p"),
                read: .panel,
                order: 1,
                shipped: .plugins(PluginGuide(folder: folder, guide: guide, app: app))
            ),
            PluginCommand(
                id: "openspot/settings",
                name: "Settings",
                url: config.url,
                kind: .list,
                size: .small,
                symbol: "gearshape",
                subtitle: "Choose your key",
                read: .sheet,
                order: 2,
                shipped: .settings(Settings(file: config))
            )
        ]
        if let update {
            commands.append(
                PluginCommand(
                    id: "openspot/updates",
                    name: "Updates",
                    url: folder,
                    symbol: "arrow.triangle.2.circlepath",
                    read: .panel,
                    order: 3,
                    shipped: .updates(update)
                )
            )
        }
        return commands
    }

    /// The ID of the sheet that shows a shared spot, which has no card in the grid.
    public static let installID = "openspot/install"

    /// The sheet that shows a shared spot before a person installs it.
    public static func command(reviewing review: SpotReview) -> PluginCommand {
        PluginCommand(
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

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        switch self {
        case .plugins(let guide): try await guide.answer(arguments, input: input)
        case .settings(let settings): try settings.answer(arguments)
        case .updates(let update): try await update.answer(arguments)
        case .review(let review): try review.answer(arguments)
        }
    }
}
