import Foundation

enum StoreCall: NounCall {
    case list(PrintForm)
    case get(String, isConfirmed: Bool)
    case publish(String)
    case add(String)
    case remove(String)
    case folders(PrintForm)

    static let noun = CommandNoun("store", group: .build, verbs: [
        CommandVerb("list", "[--json]", "Prints each spot of the store, and whether you have it. --json prints them as JSON.", rule: CallRule(use: .spots, used: "read the store")) { words in
            words.form.map(Self.list)
        },
        CommandVerb("get", "<id> [--yes]", "Installs a spot of a store: copies its folder into your spots folder, where search finds it, off the grid. A spot that uses something, runs by itself or can do more prints its review and needs --yes.", rule: CallRule(use: .spots, used: "installed a spot", inShow: .changes("changes your spots"))) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return Self.get(fit.rest[0], isConfirmed: fit.has("--yes"))
        },
        CommandVerb("add", "<folder>", "Adds a folder that holds spot folders as a store, so the Store lists its spots.", rule: CallRule(use: .spots, used: "added a store", inShow: .changes("changes your stores"))) { $0.one.map(Self.add) },
        CommandVerb("remove", "<folder>", "Removes a store that store add added. The spots you got from it stay.", rule: CallRule(use: .spots, used: "removed a store", inShow: .changes("changes your stores"))) { $0.one.map(Self.remove) },
        CommandVerb("folders", "[--json]", "Prints the built-in store Openspot, then each store that store add added, with its name and whether its folder is found. --json prints them as JSON.", rule: CallRule(use: .spots, used: "read the stores")) { words in
            words.form.map(Self.folders)
        },
        CommandVerb("publish", "<id>", "Publishes a spot of your spots folder to the store. Only the Store spot can run it, so a person publishes from the Store spot.", rule: CallRule(use: .account, used: "published a spot", inShow: .changes("changes the store"), flags: .reachesKey)) { $0.one.map(Self.publish) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = StoreCalls(places: context.places, app: context.app)
        return switch self {
        case .list(let form): calls.list(form)
        case .get(let id, let isConfirmed): calls.get(id, isConfirmed: isConfirmed)
        case .publish(let id): calls.publish(id, account: context.account, caller: context.caller)
        case .add(let path): calls.add(path)
        case .remove(let path): calls.remove(path)
        case .folders(let form): calls.folders(form)
        }
    }
}
