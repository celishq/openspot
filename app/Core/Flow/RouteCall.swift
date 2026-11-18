import Foundation

enum RouteCall: NounCall {
    case move(FlowMove, name: String)

    private static let rule = CallRule(read: .changes("moves the panel"), flags: .needsApp)

    static let noun = CommandNoun("route", group: .build, verbs: [
        CommandVerb("push", "<route> [--title <words>] [--replace]", "Shows a route of the spot over the sheet that shows. --replace takes the place of the sheet that shows.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return Self.move(.push(spot: nil, page: fit.rest[0], title: fit.value("--title"), replace: fit.has("--replace")), name: "route push")
        },
        CommandVerb("back", "[--root]", "Goes back one sheet of the spot, or with --root to its first sheet.", rule: rule) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            return Self.move(.pop(all: fit.has("--root")), name: "route back")
        },
        CommandVerb("close", "", "Takes each sheet of the spot off, back to the sheet that opened it or to the grid.", rule: rule) { words in
            words.none ? Self.move(.close, name: "route close") : nil
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .move(let move, let name) = self else { return nil }
        return SpotEffect.route(move).work(in: context, name: name)
    }
}
