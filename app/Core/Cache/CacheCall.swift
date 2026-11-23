import Foundation

enum CacheCall: NounCall {
    case get(String)
    case age(String)
    case set(String)

    static let noun = CommandNoun("cache", group: .build, verbs: [
        CommandVerb(
            "get", "<name>",
            "Prints the value the calling spot keeps as <name>, or nothing. When it is missing, or older than the age of cache.<name> in the spot's [on], Openspot runs that handler in the background. It runs only in a run of a spot.",
            rule: CallRule(flags: .needsApp)
        ) { $0.one.map(Self.get) },
        CommandVerb("age", "<name>", "Prints the seconds since the calling spot kept <name>, or nothing.", rule: CallRule(flags: .needsApp)) { $0.one.map(Self.age) },
        CommandVerb(
            "set", "<name>",
            "Keeps the text on stdin as <name> of the calling spot, and asks the spot again for the text in the panel's search. A spot keeps 16 MB at most.",
            rule: CallRule(flags: [.needsApp, .readsInput])
        ) { $0.one.map(Self.set) },
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let spot = context.caller, let runs = context.runs else {
            return { CommandAnswer(errors: "`openspot cache` runs only in a run of a spot.\n", code: 2) }
        }
        let cache = context.places.cache
        let owner = spot.dataName ?? spot.id
        switch self {
        case .get(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            let fills = spot.triggers.fills[name]
            return {
                let entry = cache.read(name, of: owner)
                if let fills, entry.map({ Date().timeIntervalSince($0.saved) >= fills }) ?? true {
                    Task { @MainActor in runs.fill(name, of: spot.id) }
                }
                return CommandAnswer(output: entry?.value ?? "")
            }
        case .age(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            return {
                let entry = cache.read(name, of: owner)
                return CommandAnswer(output: entry.map { "\(Int(Date().timeIntervalSince($0.saved).rounded(.down)))\n" } ?? "")
            }
        case .set(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            return {
                let isChanged: Bool
                do {
                    isChanged = try cache.keep(await context.input(), as: name, of: owner, at: Date())
                } catch {
                    return CommandAnswer(errors: "\(spot.name) keeps 16 MB at most in its cache. Keep less, or set a smaller value.\n", code: 2)
                }
                if isChanged { Task { @MainActor in runs.cacheChanged(spot.id) } }
                return CommandAnswer()
            }
        }
    }

    private static func badName(_ name: String) -> CommandAPI.Work {
        { CommandAnswer(errors: "A cache name takes letters, digits, -, _ and ., such as rates: \(name).\n", code: 2) }
    }
}
