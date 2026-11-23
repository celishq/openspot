import Foundation

struct SpotList {
    private struct Loaded: PrintedRecord {
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
        let buttons: [Offer]
        let fields: [Offer]
        let openKey: String?
        let float: Bool
        let floatKey: String?
        let menubar: Bool
        let inMenuBar: Bool

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("openKey", openKey), ("float", String(float)), ("floatKey", floatKey), ("menubar", String(menubar)), ("inMenuBar", String(inMenuBar))]]
                + buttons.map { [("button", $0.id), ("title", $0.title), ("icon", $0.icon), ("key", $0.key)] }
                + fields.map { [("field", $0.id), ("title", $0.title), ("icon", $0.icon)] }
        }
    }

    private struct Choice: PrintedRecord {
        let id: String
        let name: String
        let icon: String
        let detail: String?
        let on: Bool
        let own: Bool

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("on", String(on)), ("own", String(own))]]
        }
    }

    private struct Value: PrintedRecord {
        let spot: String
        let key: String
        let value: String

        var blocks: [[(String, String?)]] {
            [[("item", "\(spot).\(key)"), ("key", key), ("spot", spot), ("value", value)]]
        }
    }

    let folder: SpotsFolder
    let config: Config

    func loaded(_ form: PrintForm) throws -> String {
        let scan = try folder.scan()
        let keys = config.keys
        return try form.text(of: scan.scripts.map { script in
            Loaded(
                id: script.id,
                name: script.name,
                icon: Self.picture(of: script),
                detail: script.subtitle,
                buttons: script.offers.map { offer in
                    Loaded.Offer(id: offer.id, title: offer.title ?? "", icon: offer.icon, key: keys.first { $0.spot == script.id && $0.act == .command(offer.id) }?.trigger.text)
                },
                fields: script.settings.map { Loaded.Offer(id: $0.id, title: $0.title, icon: $0.icon, key: nil) },
                openKey: keys.first { $0.spot == script.id && $0.act == .open }?.trigger.text,
                float: true,
                floatKey: keys.first { $0.spot == script.id && $0.act == .float }?.trigger.text,
                menubar: script.canShowInMenuBar,
                inMenuBar: config.arrangement.menuBar.contains(script.id)
            )
        })
    }

    func core(_ form: PrintForm) throws -> String {
        try form.text(of: choices.map { Choice(id: $0.id, name: $0.spot.name, icon: Self.picture(of: $0.spot), detail: $0.spot.subtitle, on: $0.on, own: $0.own) })
    }

    private var choices: [(id: String, spot: Spot, on: Bool, own: Bool)] {
        let own = folder.scanOwnIDs()
        let enabled = config.arrangement.enabled
        return folder.coreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { spot in
            let id = SpotsFolder.coreID(of: spot)
            return (id, spot, own.contains(id) || enabled.contains(id), own.contains(id))
        }
    }

    func values(_ form: PrintForm, secrets: SecretStore.Values) throws -> String {
        let hidden = secrets.sorted { $0.key < $1.key }.flatMap { spot, values in values.keys.sorted().map { Value(spot: spot, key: $0, value: FieldValues.hidden) } }
        return try form.text(of: config.settings.map { Value(spot: $0.spot, key: $0.key, value: $0.value) } + hidden)
    }

    private static func picture(of spot: Spot) -> String {
        spot.image ?? spot.file ?? spot.glyph ?? spot.symbol
    }
}
