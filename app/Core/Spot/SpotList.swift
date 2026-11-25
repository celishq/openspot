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

    private struct Access {
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let last: [String: String]
        let byUse: [String: [String: String]]

        init(_ spot: Spot, isOn: Bool, statuses: [MacAccess: ReadAccess], last: [String: Date], refused: [SpotUse: Date]) {
            let access = SpotAccess(spot, written: KeptCalls.shared.read(spot), made: Array(last.keys))
            let needs = access.missing(in: statuses)
            let listed = { (set: Set<MacAccess>) in set.isEmpty ? nil : MacAccess.allCases.filter(set.contains).map(\.rawValue).joined(separator: ",") }
            byUse = Dictionary(uniqueKeysWithValues: access.byUse.map { use, found in
                (use.rawValue, ["access": listed(found.needs), "maybe": listed(found.maybe)].compactMapValues { $0 })
            })
            let refused = SpotUse.allCases.filter { refused[$0] != nil && !spot.uses.contains($0) }
            state = SpotReadiness(isOn: isOn, needs: needs, refused: refused).rawValue
            self.refused = refused.map(\.rawValue)
            uses = spot.uses.map(\.rawValue).sorted()
            self.needs = needs.map(\.rawValue)
            var times: [String: Date] = [:]
            for (call, date) in last {
                guard let use = CommandLineCall.looseRule(of: call.split(separator: " ").map(String.init), spot: spot.id)?.rule.use else { continue }
                times[use.rawValue] = max(times[use.rawValue] ?? date, date)
            }
            self.last = times.mapValues { $0.formatted(.iso8601) }
        }

        static func fields(state: String, uses: [String], needs: [String], refused: [String], last: [String: String], byUse: [String: [String: String]]) -> [(String, String?)] {
            [("state", state), ("uses", uses.isEmpty ? nil : uses.joined(separator: ",")), ("needs", needs.isEmpty ? nil : needs.joined(separator: ",")), ("refused", refused.isEmpty ? nil : refused.joined(separator: ","))]
                + last.keys.sorted().map { ("last.\($0)", last[$0]) }
                + byUse.keys.sorted().flatMap { use in ["access", "maybe"].map { ("\($0).\(use)", byUse[use]?[$0]) } }
        }
    }

    let folder: SpotsFolder
    let config: Config
    var statuses: [MacAccess: ReadAccess] = [:]
    var lastUses: [String: [String: Date]] = [:]
    var refused: [String: [SpotUse: Date]] = [:]
    var allowed: [SpotLock.Entry] = []

    func loaded(_ form: PrintForm) throws -> String {
        let scan = try folder.scan().allowing(allowed)
        let keys = config.keys
        return try form.text(of: scan.scripts.map { script in
            let access = Access(script, isOn: true, statuses: statuses, last: lastUses[script.id] ?? [:], refused: refused[script.id] ?? [:])
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
                state: access.state,
                uses: access.uses,
                needs: access.needs,
                refused: access.refused,
                last: access.last,
                byUse: access.byUse
            )
        })
    }

    func core(_ form: PrintForm) throws -> String {
        try form.text(of: choices.map { choice in
            let access = Access(choice.spot, isOn: choice.on, statuses: statuses, last: lastUses[choice.id] ?? [:], refused: refused[choice.spot.id] ?? [:])
            return Choice(
                id: choice.id, name: choice.spot.name, icon: Self.picture(of: choice.spot), detail: choice.spot.subtitle, on: choice.on, own: choice.own,
                state: access.state, uses: access.uses, needs: access.needs, refused: access.refused, last: access.last, byUse: access.byUse
            )
        })
    }

    private var choices: [(id: String, spot: Spot, on: Bool, own: Bool)] {
        let own = folder.scanOwnIDs()
        let enabled = config.arrangement.enabled
        return folder.coreChoices().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { spot in
            let id = SpotsFolder.coreID(of: spot)
            return (id, spot, own.contains(id) || enabled.contains(id), own.contains(id))
        }
    }

    private static func picture(of spot: Spot) -> String {
        spot.image ?? spot.file ?? spot.glyph ?? spot.symbol
    }
}
