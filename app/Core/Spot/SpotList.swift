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
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let last: [String: String]
        let byUse: [String: [String: String]]

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("openKey", openKey), ("float", String(float)), ("floatKey", floatKey), ("menubar", String(menubar)), ("inMenuBar", String(inMenuBar))]
                + Printed.fields(state: state, uses: uses, needs: needs, refused: refused, last: last, byUse: byUse)]
                + buttons.map { [("button", $0.id), ("title", $0.title), ("icon", $0.icon), ("key", $0.key)] }
                + fields.map { [("field", $0.id), ("title", $0.title), ("icon", $0.icon)] }
        }
    }

    private struct Picked: PrintedRecord {
        let id: String
        let name: String
        let icon: String
        let detail: String?
        let on: Bool
        let own: Bool
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let last: [String: String]
        let byUse: [String: [String: String]]

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("on", String(on)), ("own", String(own))] + Printed.fields(state: state, uses: uses, needs: needs, refused: refused, last: last, byUse: byUse)]
        }
    }

    private struct Printed {
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let last: [String: String]
        let byUse: [String: [String: String]]

        init(_ standing: SpotStanding) {
            let listed = { (values: [MacAccess]) in values.isEmpty ? nil : values.map(\.rawValue).joined(separator: ",") }
            state = standing.readiness.rawValue
            uses = standing.uses.map(\.id.rawValue)
            needs = standing.missing.map(\.rawValue)
            refused = standing.refused.map(\.rawValue)
            last = Dictionary(uniqueKeysWithValues: standing.last.map { ($0.key.rawValue, $0.value.formatted(.iso8601)) })
            byUse = Dictionary(uniqueKeysWithValues: standing.byUse.map { use in
                (use.id.rawValue, ["access": listed(use.needs), "maybe": listed(use.maybe)].compactMapValues { $0 })
            })
        }

        static func fields(state: String, uses: [String], needs: [String], refused: [String], last: [String: String], byUse: [String: [String: String]]) -> [(String, String?)] {
            [("state", state), ("uses", uses.isEmpty ? nil : uses.joined(separator: ",")), ("needs", needs.isEmpty ? nil : needs.joined(separator: ",")), ("refused", refused.isEmpty ? nil : refused.joined(separator: ","))]
                + last.keys.sorted().map { ("last.\($0)", last[$0]) }
                + byUse.keys.sorted().flatMap { use in ["access", "maybe"].map { ("\($0).\(use)", byUse[use]?[$0]) } }
        }
    }

    struct Choice: Equatable, Sendable {
        let standing: SpotStanding
        let isOwn: Bool
    }

    let folder: SpotsFolder
    let config: Config
    let scan: Result<ScanResult, Error>
    var statuses: [MacAccess: AccessStatus] = [:]
    var apps: [TextBlock] = []
    var lastUses: [String: [String: Date]] = [:]
    var refused: [String: [SpotUse: Date]] = [:]
    var allowed: [SpotLock.Entry] = []

    init(folder: SpotsFolder, config: Config) {
        self.folder = folder
        self.config = config
        scan = Result { try folder.scan() }
    }

    func loaded(_ form: PrintForm) throws -> String {
        let keys = config.keys
        return try form.text(of: try loaded().map { standing in
            let script = standing.spot
            let printed = Printed(standing)
            return Loaded(
                id: script.id,
                name: script.name,
                icon: Self.picture(of: script),
                detail: script.subtitle,
                buttons: script.commands.map { offer in
                    Loaded.Offer(id: offer.id, title: offer.title ?? "", icon: offer.icon, key: keys.first { $0.spot == script.id && $0.act == .command(offer.id) }?.trigger.text)
                },
                fields: script.settings.map { Loaded.Offer(id: $0.id, title: $0.title, icon: $0.icon, key: nil) },
                openKey: keys.first { $0.spot == script.id && $0.act == .open }?.trigger.text,
                float: true,
                floatKey: keys.first { $0.spot == script.id && $0.act == .float }?.trigger.text,
                menubar: script.canShowInMenuBar,
                inMenuBar: config.arrangement.menuBar.contains(script.id),
                state: printed.state,
                uses: printed.uses,
                needs: printed.needs,
                refused: printed.refused,
                last: printed.last,
                byUse: printed.byUse
            )
        })
    }

    func core(_ form: PrintForm) throws -> String {
        try form.text(of: core().map { choice in
            let (standing, printed) = (choice.standing, Printed(choice.standing))
            return Picked(
                id: standing.id, name: standing.title, icon: Self.picture(of: standing.spot), detail: standing.spot.subtitle, on: !standing.isOff, own: choice.isOwn,
                state: printed.state, uses: printed.uses, needs: printed.needs, refused: printed.refused, last: printed.last, byUse: printed.byUse
            )
        })
    }

    func loaded() throws -> [SpotStanding] {
        try scan.get().allowing(allowed).scripts.map { readStanding(of: $0) }
    }

    func core() -> [Choice] {
        let own = folder.scanOwnIDs()
        let enabled = config.arrangement.enabled
        return folder.coreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { spot in
            let id = SpotsFolder.coreID(of: spot)
            return Choice(standing: readStanding(of: spot, id: id, isOn: own.contains(id) || enabled.contains(id)), isOwn: own.contains(id))
        }
    }

    private func readStanding(of spot: Spot, id: String? = nil, isOn: Bool = true) -> SpotStanding {
        SpotStanding(spot, id: id, isOn: isOn, written: KeptCalls.shared.read(spot), statuses: statuses, last: lastUses[spot.id] ?? [:], refused: refused[spot.id] ?? [:])
    }

    private static func picture(of spot: Spot) -> String {
        spot.image ?? spot.file ?? spot.glyph ?? spot.symbol
    }
}
