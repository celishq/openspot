import Foundation

/// The spots that `openspot spot list` prints as JSON: each script that the app loads, with its commands, its settings and
/// their keys, or with `core` each spot that comes with the app and that the person turns on or off. It also prints the
/// values that the spots keep, for `openspot setting list`.
struct SpotList {
    private struct Loaded: Encodable {
        struct Offer: Encodable {
            let id: String
            let title: String
            let icon: String?
            let key: String?
        }

        let id: String
        let name: String
        let icon: String
        let detail: String?
        let commands: [Offer]
        let settings: [Offer]
        let float: Bool
        let floatKey: String?
        let menubar: Bool
        let inMenuBar: Bool
    }

    private struct Choice: Encodable {
        let id: String
        let name: String
        let icon: String
        let detail: String?
        let on: Bool
        let own: Bool
    }

    let folder: SpotFolder
    let config: Config

    /// Each script of the scan, in its order.
    func loaded() throws -> String {
        let scan = try folder.keptScan()
        let keys = config.keys
        return try Self.json(scan.scripts.map { script in
            Loaded(
                id: script.id,
                name: script.name,
                icon: Self.picture(of: script),
                detail: script.subtitle,
                commands: script.offers.map { offer in
                    Loaded.Offer(id: offer.id, title: offer.title, icon: offer.icon, key: keys.first { $0.spot == script.id && $0.act == .command(offer.id) }?.trigger.text)
                },
                settings: script.settings.map { Loaded.Offer(id: $0.id, title: $0.title, icon: $0.icon, key: nil) },
                float: script.offersFloat,
                floatKey: keys.first { $0.spot == script.id && $0.act == .float }?.trigger.text,
                menubar: script.canShowInMenuBar,
                inMenuBar: config.arrangement.menuBar.contains(script.id)
            )
        })
    }

    /// Each core spot that a person can turn on, by name. A file of the plugins folder with its ID is always on.
    func core() throws -> String {
        let own = folder.ownIDs
        let enabled = config.arrangement.enabled
        let choices = folder.keptCoreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return try Self.json(choices.map { command in
            let id = SpotFolder.coreID(of: command)
            return Choice(id: id, name: command.name, icon: Self.picture(of: command), detail: command.subtitle, on: own.contains(id) || enabled.contains(id), own: own.contains(id))
        })
    }

    /// Each value that a spot keeps, in the order of the file.
    func values() throws -> String {
        try Self.json(config.settings.map { ["spot": $0.spot, "key": $0.key, "value": $0.value] })
    }

    /// The picture that its header names, or else its symbol.
    private static func picture(of spot: Spot) -> String {
        spot.image ?? spot.file ?? spot.glyph ?? spot.symbol
    }

    private static func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self) + "\n"
    }
}
