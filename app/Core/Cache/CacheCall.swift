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
        let env = SpotEnv(spot: spot, cache: runs.cache, runs: runs)
        switch self {
        case .get(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            return { CommandAnswer(output: env.read(name)?.value ?? "") }
        case .age(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            return { CommandAnswer(output: env.read(name).map { "\($0.age)\n" } ?? "") }
        case .set(let name):
            guard SpotCache.isName(name) else { return Self.badName(name) }
            return {
                do {
                    try env.keep(await context.input(), as: name)
                } catch {
                    return CommandAnswer(errors: "\(spot.name) keeps 16 MB at most in its cache. Keep less, or set a smaller value.\n", code: 2)
                }
                return CommandAnswer()
            }
        }
    }

    private static func badName(_ name: String) -> CommandAPI.Work {
        { CommandAnswer(errors: "A cache name takes letters, digits, -, _ and ., such as rates: \(name).\n", code: 2) }
    }
}
