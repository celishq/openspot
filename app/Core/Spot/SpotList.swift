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
                + Access.fields(state: state, uses: uses, needs: needs, refused: refused, last: last, byUse: byUse)]
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
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let last: [String: String]
        let byUse: [String: [String: String]]

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("on", String(on)), ("own", String(own))] + Access.fields(state: state, uses: uses, needs: needs, refused: refused, last: last, byUse: byUse)]
        }
    }

    struct Access: Equatable, Sendable {
        struct Use: Equatable, Sendable {
            let needs: [MacAccess]
            let maybe: [MacAccess]
        }

        let readiness: SpotReadiness
        let uses: [SpotUse]
        let needs: [MacAccess]
        let refused: [SpotUse]
        let last: [String: Date]
        let byUse: [SpotUse: Use]

        init(_ spot: Spot, isOn: Bool, statuses: [MacAccess: ReadAccess], last: [String: Date], refused: [SpotUse: Date]) {
            let access = SpotAccess(spot, written: KeptCalls.shared.read(spot), made: Array(last.keys))
            let needs = access.missing(in: statuses)
            let ordered = { (set: Set<MacAccess>) in MacAccess.allCases.filter(set.contains) }
            byUse = access.byUse.mapValues { Use(needs: ordered($0.needs), maybe: ordered($0.maybe)) }
            let refused = SpotUse.allCases.filter { refused[$0] != nil && !spot.uses.contains($0) }
            readiness = SpotReadiness(isOn: isOn, needs: needs, refused: refused)
            self.refused = refused
            uses = spot.uses.sorted { $0.rawValue < $1.rawValue }
            self.needs = needs
            var times: [String: Date] = [:]
            for (call, date) in last {
                guard let use = CommandLineCall.looseRule(of: call.split(separator: " ").map(String.init), spot: spot.id)?.rule.use else { continue }
                times[use.rawValue] = max(times[use.rawValue] ?? date, date)
            }
            self.last = times
        }

        var printed: (state: String, uses: [String], needs: [String], refused: [String], last: [String: String], byUse: [String: [String: String]]) {
            let listed = { (values: [MacAccess]) in values.isEmpty ? nil : values.map(\.rawValue).joined(separator: ",") }
            let byUse = Dictionary(uniqueKeysWithValues: byUse.map { use, found in
                (use.rawValue, ["access": listed(found.needs), "maybe": listed(found.maybe)].compactMapValues { $0 })
            })
            return (readiness.rawValue, uses.map(\.rawValue), needs.map(\.rawValue), refused.map(\.rawValue), last.mapValues { $0.formatted(.iso8601) }, byUse)
        }

        static func fields(state: String, uses: [String], needs: [String], refused: [String], last: [String: String], byUse: [String: [String: String]]) -> [(String, String?)] {
            [("state", state), ("uses", uses.isEmpty ? nil : uses.joined(separator: ",")), ("needs", needs.isEmpty ? nil : needs.joined(separator: ",")), ("refused", refused.isEmpty ? nil : refused.joined(separator: ","))]
                + last.keys.sorted().map { ("last.\($0)", last[$0]) }
                + byUse.keys.sorted().flatMap { use in ["access", "maybe"].map { ("\($0).\(use)", byUse[use]?[$0]) } }
        }
    }

    struct Record: Equatable, Sendable {
        let id: String
        let spot: Spot
        let isOn: Bool
        let isOwn: Bool
        let access: Access

        var picture: String {
            spot.image ?? spot.file ?? spot.glyph ?? spot.symbol
        }
    }

    let folder: SpotsFolder
    let config: Config
    var statuses: [MacAccess: ReadAccess] = [:]
    var lastUses: [String: [String: Date]] = [:]
    var refused: [String: [SpotUse: Date]] = [:]
    var allowed: [SpotLock.Entry] = []

    func loaded(_ form: PrintForm) throws -> String {
        let keys = config.keys
        return try form.text(of: try loadedRecords().map { record in
            let script = record.spot
            let printed = record.access.printed
            return Loaded(
                id: script.id,
                name: script.name,
                icon: record.picture,
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
        try form.text(of: coreRecords().map { record in
            let printed = record.access.printed
            return Choice(
                id: record.id, name: record.spot.name, icon: record.picture, detail: record.spot.subtitle, on: record.isOn, own: record.isOwn,
                state: printed.state, uses: printed.uses, needs: printed.needs, refused: printed.refused, last: printed.last, byUse: printed.byUse
            )
        })
    }

    func loadedRecords() throws -> [Record] {
        try folder.scan().allowing(allowed).scripts.map { script in
            Record(id: script.id, spot: script, isOn: true, isOwn: false, access: access(of: script, isOn: true))
        }
    }

    func coreRecords() -> [Record] {
        let own = folder.scanOwnIDs()
        let enabled = config.arrangement.enabled
        return folder.coreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { spot in
            let id = SpotsFolder.coreID(of: spot)
            let isOn = own.contains(id) || enabled.contains(id)
            return Record(id: id, spot: spot, isOn: isOn, isOwn: own.contains(id), access: access(of: spot, isOn: isOn))
        }
    }

    private func access(of spot: Spot, isOn: Bool) -> Access {
        Access(spot, isOn: isOn, statuses: statuses, last: lastUses[spot.id] ?? [:], refused: refused[spot.id] ?? [:])
    }
}
