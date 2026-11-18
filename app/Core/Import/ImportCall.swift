import Foundation

enum ImportCall: NounCall {
    case raycast(String, isDry: Bool, form: PrintForm)

    static let noun = CommandNoun("import", group: .build, verbs: [
        CommandVerb("raycast", "<folder> [--dry-run] [--json]", "Turns each Raycast script command in a folder into a spot of your spots folder, and prints what it added, kept and skipped. A script it imported before stays as it is. --dry-run changes nothing.", rule: CallRule(use: .spots, used: "imported spots", read: .changes("changes your spots"))) { words in
            guard let fit = words.fit, let folder = fit.rest.first, fit.rest.count == 1 else { return nil }
            return Self.raycast(folder, isDry: fit.has("--dry-run"), form: fit.has(PrintForm.jsonWord) ? .json : .frame)
        }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard case .raycast(_, true, _) = self else { return rule }
        var rule = rule
        rule.read = .free
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .raycast(let path, let isDry, let form):
            let folder = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: context.folder).standardizedFileURL
            return CommandAnswer.work { [places = context.places, app = context.app] in
                let spots = places.readSpots()
                let taken = Set(((try? spots.scan().spots) ?? []).map(\.id) + spots.coreChoices().map(SpotsFolder.coreID(of:)))
                let items = try RaycastImport(folder: folder).run(into: spots.url, taken: taken, isDry: isDry)
                if !isDry, items.contains(where: { $0.outcome == .added }) { await app?.spotsChanged() }
                return try form.text(of: items)
            }
        }
    }
}
