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
        let last: [String: String]

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("openKey", openKey), ("float", String(float)), ("floatKey", floatKey), ("menubar", String(menubar)), ("inMenuBar", String(inMenuBar))]
                + Access.fields(state: state, uses: uses, needs: needs, last: last)]
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
        let last: [String: String]

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", detail), ("on", String(on)), ("own", String(own))] + Access.fields(state: state, uses: uses, needs: needs, last: last)]
        }
    }

    private struct Access {
        let state: String
        let uses: [String]
        let needs: [String]
        let last: [String: String]

        init(_ spot: Spot, isOn: Bool, statuses: [MacAccess: ReadAccess], last: [String: Date]) {
            let needs = SpotAccess(spot, written: KeptCalls.shared.read(spot), made: Array(last.keys)).missing(in: statuses)
            state = SpotReadiness(isOn: isOn, needs: needs).rawValue
            uses = spot.uses.map(\.rawValue).sorted()
            self.needs = needs.map(\.rawValue)
            var times: [String: Date] = [:]
            for (call, date) in last {
                guard let use = CommandLineCall.looseRule(of: call.split(separator: " ").map(String.init), spot: spot.id)?.rule.use else { continue }
                times[use.rawValue] = max(times[use.rawValue] ?? date, date)
            }
            self.last = times.mapValues { $0.formatted(.iso8601) }
        }

        static func fields(state: String, uses: [String], needs: [String], last: [String: String]) -> [(String, String?)] {
            [("state", state), ("uses", uses.isEmpty ? nil : uses.joined(separator: ",")), ("needs", needs.isEmpty ? nil : needs.joined(separator: ","))]
                + last.keys.sorted().map { ("last.\($0)", last[$0]) }
        }
    }

    let folder: SpotsFolder
    let config: Config
    var statuses: [MacAccess: ReadAccess] = [:]
    var lastUses: [String: [String: Date]] = [:]

    func loaded(_ form: PrintForm) throws -> String {
        let scan = try folder.scan()
        let keys = config.keys
        return try form.text(of: scan.scripts.map { script in
            let access = Access(script, isOn: true, statuses: statuses, last: lastUses[script.id] ?? [:])
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
                last: access.last
            )
        })
    }

    func core(_ form: PrintForm) throws -> String {
        try form.text(of: choices.map { choice in
            let access = Access(choice.spot, isOn: choice.on, statuses: statuses, last: lastUses[choice.id] ?? [:])
            return Choice(
                id: choice.id, name: choice.spot.name, icon: Self.picture(of: choice.spot), detail: choice.spot.subtitle, on: choice.on, own: choice.own,
                state: access.state, uses: access.uses, needs: access.needs, last: access.last
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
