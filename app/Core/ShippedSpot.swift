import Foundation

/// A spot that ships with the app, so that it shows whatever the plugins folder holds.
public enum ShippedSpot: Equatable, Sendable {
    case plugins(PluginGuide)

    /// The commands of the shipped spots, in the order of the grid.
    public static func commands(folder: URL, guide: URL, app: String) -> [PluginCommand] {
        [
            PluginCommand(
                id: "openspot/plugins",
                name: "Plugins",
                url: folder,
                kind: .list,
                symbol: "puzzlepiece.extension",
                subtitle: "Add your own",
                key: CommandKey(name: "p"),
                read: .open,
                order: 1,
                keepsRecent: false,
                shipped: .plugins(PluginGuide(folder: folder, guide: guide, app: app))
            )
        ]
    }
}
