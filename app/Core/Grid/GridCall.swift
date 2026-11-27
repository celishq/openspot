import Foundation

enum GridCall: NounCall {
    case edit
    case list(PrintForm)
    case pin(String)
    case push(String)

    static let noun = CommandNoun("grid", group: .app, verbs: [
        CommandVerb("edit", "", "Opens Arrange, where you pin your spots to the grid and take them off.", rule: CallRule(inShow: .changes("opens the panel"))) { $0.none ? Self.edit : nil },
        CommandVerb("list", "[--json]", "Prints an item, an item=<id> block, for each of your spots, the ones off the grid first, each with grid=true or grid=false.") { words in
            words.fit.flatMap { $0.rest.isEmpty ? Self.list($0.form) : nil }
        },
        CommandVerb("pin", "<id>", "Puts a spot of yours that is off the grid in the first free slot of the grid.", rule: CallRule(inShow: .changes("changes the grid"))) { $0.one.map(Self.pin) },
        CommandVerb("push", "<id>", "Puts a spot of yours at the top of the grid, and the other spots move along after it, as a drop in Arrange does.", rule: CallRule(inShow: .changes("changes the grid"))) { $0.one.map(Self.push) },
    ])

    private struct Listed: PrintedRecord {
        let id: String
        let name: String
        let icon: String
        let grid: Bool

        var blocks: [[(String, String?)]] {
            [[("item", id), ("title", name), ("icon", icon), ("detail", grid ? "On the grid" : "Off the grid"), ("grid", String(grid))]]
        }
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .edit:
            return SpotCalls(context).editGrid()
        case .list(let form):
            guard let app = context.app else { return CommandAnswer.notRunning("grid list") }
            return CommandAnswer.work {
                try form.text(of: await app.gridSpots().map { Listed(id: $0.id, name: $0.name, icon: $0.icon, grid: $0.isOnGrid) })
            }
        case .pin(let id):
            guard let app = context.app else { return CommandAnswer.notRunning("grid pin") }
            return CommandAnswer.work {
                let name = await app.gridSpots().first { $0.id == id }?.name ?? id
                switch await app.pin(id) {
                case .pinned: return "\(name) is on the grid.\n"
                case .onGrid: throw SpotError.failed(1, "\(name) is on the grid already.")
                case .full: throw SpotError.failed(1, "The grid has no free slot for \(name). Take a spot off it in Arrange first.")
                case .unknown: throw SpotError.failed(1, "You have no spot `\(id)` to pin. Run `openspot grid list` to see each one.")
                }
            }
        case .push(let id):
            guard let app = context.app else { return CommandAnswer.notRunning("grid push") }
            return CommandAnswer.work {
                await app.spotsChanged()
                let name = await app.gridSpots().first { $0.id == id }?.name ?? id
                switch await app.push(id) {
                case .pinned, .onGrid: return "\(name) is at the top of the grid.\n"
                case .full: throw SpotError.failed(1, "The grid has no room for \(name) at its top. Take a spot off it in Arrange first.")
                case .unknown: throw SpotError.failed(1, "You have no spot `\(id)` to push. Run `openspot grid list` to see each one.")
                }
            }
        }
    }
}
