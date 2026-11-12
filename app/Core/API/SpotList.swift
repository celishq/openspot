import Foundation

/// The spots that `openspot spot list` prints as JSON or as blocks: each script that the app loads, with its commands, its
/// settings and their keys, or with `core` each spot that comes with the app and that the person turns on or off. It also
/// prints the values that the spots keep, for `openspot setting list`.
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

    /// Each script of the scan as a `spot` block, with a `button` block for each of its commands and a `field` block for
    /// each of its settings after it (protocol: The openspot command).
    func loadedFrame() throws -> String {
        let scan = try folder.keptScan()
        let keys = config.keys
        return scan.scripts.map { script in
            let spot = Self.block([
                ("spot", script.id), ("name", script.name), ("icon", Self.picture(of: script)), ("detail", script.subtitle),
                ("float", String(script.offersFloat)), ("floatKey", keys.first { $0.spot == script.id && $0.act == .float }?.trigger.text),
                ("menubar", String(script.canShowInMenuBar)), ("inMenuBar", String(config.arrangement.menuBar.contains(script.id)))
            ])
            let commands = script.offers.map { offer in
                Self.block([("button", offer.id), ("title", offer.title), ("icon", offer.icon), ("key", keys.first { $0.spot == script.id && $0.act == .command(offer.id) }?.trigger.text)])
            }
            let settings = script.settings.map { Self.block([("field", $0.id), ("title", $0.title), ("icon", $0.icon)]) }
            return ([spot] + commands + settings).joined()
        }.joined()
    }

    /// Each core spot that a person can turn on, by name. A file of the plugins folder with its ID is always on.
    func core() throws -> String {
        try Self.json(choices.map { Choice(id: $0.id, name: $0.spot.name, icon: Self.picture(of: $0.spot), detail: $0.spot.subtitle, on: $0.on, own: $0.own) })
    }

    /// Each core spot that a person can turn on, as a `spot` block (protocol: The openspot command).
    func coreFrame() -> String {
        choices.map { choice in
            Self.block([("spot", choice.id), ("name", choice.spot.name), ("icon", Self.picture(of: choice.spot)), ("detail", choice.spot.subtitle), ("on", String(choice.on)), ("own", String(choice.own))])
        }.joined()
    }

    /// The core spots by name, each with its ID and whether it is on and a file of the plugins folder.
    private var choices: [(id: String, spot: Spot, on: Bool, own: Bool)] {
        let own = folder.ownIDs
        let enabled = config.arrangement.enabled
        return folder.keptCoreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { spot in
            let id = SpotFolder.coreID(of: spot)
            return (id, spot, own.contains(id) || enabled.contains(id), own.contains(id))
        }
    }

    /// Each value that a spot keeps, in the order of the file.
    func values() throws -> String {
        try Self.json(config.settings.map { ["spot": $0.spot, "key": $0.key, "value": $0.value] })
    }

    /// Each value that a spot keeps as a `field` block, in the order of the file (protocol: The openspot command).
    func valuesFrame() -> String {
        config.settings.map { Self.block([("field", $0.key), ("spot", $0.spot), ("value", $0.value)]) }.joined()
    }

    /// One block of the lines that have a value, and a blank line after it.
    private static func block(_ pairs: [(String, String?)]) -> String {
        TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text + "\n"
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
