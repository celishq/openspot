import Foundation

enum ImportCall: NounCall {
    case raycast(String, isDry: Bool, form: PrintForm, skip: [String])
    case rayconfig(String, isDry: Bool, form: PrintForm, skip: [String])

    static let noun = CommandNoun("import", group: .build, verbs: [
        CommandVerb("raycast", "<folder> [--skip <file>]... [--dry-run] [--json]", "Turns each Raycast script command in a folder into a spot of your spots folder, and prints what it added, kept and skipped. A script it imported before stays as it is, and --skip leaves out a file by its path in the folder. --dry-run changes nothing.", rule: CallRule(use: .spots, used: "imported spots", read: .changes("changes your spots"))) { words in
            guard let fit = words.fit, let folder = fit.rest.first, fit.rest.count == 1 else { return nil }
            return Self.raycast(folder, isDry: fit.has("--dry-run"), form: fit.has(PrintForm.jsonWord) ? .json : .frame, skip: fit.values("--skip"))
        },
        CommandVerb("rayconfig", "<file> [--skip links|snippets]... [--dry-run] [--json]", "Opens a Raycast export with the passphrase on stdin, adds its quicklinks to Links and its snippets to Snippets, and prints a row for each kind of data it holds. --skip leaves out a kind. --dry-run changes nothing.", rule: CallRule(use: .spots, used: "imported Raycast data", read: .changes("changes your links and snippets"), flags: .readsInput)) { words in
            guard let fit = words.fit, let file = fit.rest.first, fit.rest.count == 1 else { return nil }
            return Self.rayconfig(file, isDry: fit.has("--dry-run"), form: fit.has(PrintForm.jsonWord) ? .json : .frame, skip: fit.values("--skip"))
        }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        switch self {
        case .raycast(_, true, _, _), .rayconfig(_, true, _, _): break
        default: return rule
        }
        var rule = rule
        rule.read = .free
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .raycast(let path, let isDry, let form, let skip):
            let folder = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: context.folder).standardizedFileURL
            return CommandAnswer.work { [places = context.places, app = context.app] in
                let spots = places.readSpots()
                let taken = Set(((try? spots.scan().spots) ?? []).map(\.id) + spots.coreChoices().map(SpotsFolder.coreID(of:)))
                let items = try RaycastImport(folder: folder).run(into: spots.url, taken: taken, isDry: isDry, skip: Set(skip))
                if !isDry, items.contains(where: { $0.outcome == .added }) { await app?.spotsChanged() }
                return try form.text(of: items)
            }
        case .rayconfig(let path, let isDry, let form, let skip):
            let file = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, relativeTo: context.folder).standardizedFileURL
            return CommandAnswer.work { [places = context.places, app = context.app, input = context.input] in
                let passphrase = String(await input().split(separator: "\n", omittingEmptySubsequences: false).first ?? "")
                let items = try await RaycastDataImport(file: file, passphrase: passphrase).run(in: places.readSpots(), environment: places.environment, isDry: isDry, skip: Set(skip))
                if !isDry { await app?.spotsChanged() }
                return try form.text(of: items)
            }
        }
    }
}
