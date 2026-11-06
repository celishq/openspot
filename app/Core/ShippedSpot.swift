import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case plugins(PluginGuide)
    case updates(UpdateSpot)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String, update: UpdateSpot? = nil) -> [PluginCommand] {
        var commands = [
            PluginCommand(
                id: "openspot/plugins",
                name: "Plugins",
                url: folder,
                kind: .list,
                symbol: "puzzlepiece.extension",
                subtitle: "Add your own",
                key: CommandKey(name: "p"),
                read: .panel,
                order: 1,
                shipped: .plugins(PluginGuide(folder: folder, guide: guide, app: app))
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
                    order: 2,
                    shipped: .updates(update)
                )
            )
        }
        return commands
    }

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?) async throws -> String {
        switch self {
        case .plugins(let guide): try await guide.answer(arguments, input: input)
        case .updates(let update): try await update.answer(arguments)
        }
    }
}
