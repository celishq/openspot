import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case plugins(PluginGuide)
    case settings(Settings)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String, config: ConfigFile = .standard()) -> [PluginCommand] {
        [
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
    }

    /// Answers one call with the text a script would print.
    func answer(_ arguments: [String], input: String?, timeout: TimeInterval) async throws -> String {
        switch self {
        case .plugins(let guide): try await guide.answer(arguments, input: input, timeout: timeout)
        case .settings(let settings): try settings.answer(arguments)
        }
    }
}
