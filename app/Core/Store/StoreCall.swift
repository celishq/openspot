import Foundation

enum StoreCall: NounCall {
    case list(PrintForm)
    case get(String, isConfirmed: Bool, clash: SpotClash? = nil)
    case update(String?, isConfirmed: Bool)
    case revert(String, isConfirmed: Bool)
    case publish(String)
    case add(String)
    case remove(String)
    case folders(PrintForm)
    case open(String?, search: String?)

    static let noun = CommandNoun("store", group: .build, verbs: [
        CommandVerb("list", "[--json]", "Prints each spot of the store, and whether you have it. --json prints them as JSON.", rule: CallRule(use: .spots, used: "read the store")) { words in
            words.form.map(Self.list)
        },
        CommandVerb("get", "<id> [--yes] [--replace] [--keep-both]", "Installs a spot of a store: copies its folder into your spots folder, where search finds it, off the grid. A spot that uses something, runs by itself or can do more prints its review and needs --yes. When your spots have its id, --replace moves yours to the Trash first, and --keep-both installs it under a new id, such as ports-2.", rule: CallRule(use: .spots, used: "installed a spot", inShow: .changes("changes your spots"))) { words in
            guard let fit = words.fit, fit.rest.count == 1, !(fit.has("--replace") && fit.has("--keep-both")) else { return nil }
            let clash: SpotClash? = fit.has("--replace") ? .replace : fit.has("--keep-both") ? .keepBoth : nil
            return Self.get(fit.rest[0], isConfirmed: fit.has("--yes"), clash: clash)
        },
        CommandVerb("update", "[<id>] [--yes]", "Updates a spot that store get installed to the newest version of its store, or each such spot with no id. An update that asks for a new use, binding or power prints only what it adds and needs --yes. A spot you edited takes no update.", rule: CallRule(use: .spots, used: "updated a spot", inShow: .changes("changes your spots"))) { words in
            guard let fit = words.fit, fit.rest.count <= 1 else { return nil }
            return Self.update(fit.rest.first, isConfirmed: fit.has("--yes"))
        },
        CommandVerb("revert", "<id> [--yes]", "Moves a spot you edited to the Trash and installs the version of its store in its place. Its data stays. A version that asks for a new use, binding or power prints only what it adds and needs --yes.", rule: CallRule(use: .spots, used: "reverted a spot", inShow: .changes("changes your spots"))) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return Self.revert(fit.rest[0], isConfirmed: fit.has("--yes"))
        },
        CommandVerb("add", "<folder>", "Adds a folder that holds spot folders as a store, so the Store lists its spots.", rule: CallRule(use: .spots, used: "added a store", inShow: .changes("changes your stores"))) { $0.one.map(Self.add) },
        CommandVerb("remove", "<folder>", "Removes a store that store add added. The spots you got from it stay.", rule: CallRule(use: .spots, used: "removed a store", inShow: .changes("changes your stores"))) { $0.one.map(Self.remove) },
        CommandVerb("folders", "[--json]", "Prints the built-in store Openspot, then each store that store add added, with its name and whether its folder is found. --json prints them as JSON.", rule: CallRule(use: .spots, used: "read the stores")) { words in
            words.form.map(Self.folders)
        },
        CommandVerb("open", "[<id>] [--search <text>]", "Opens the Store, at the page of a spot when given its id, or with the words of --search in its search.", rule: CallRule(inShow: .changes("opens the Store"))) { words in
            guard let fit = words.fit, fit.rest.count <= 1 else { return nil }
            return Self.open(fit.rest.first, search: fit.value("--search"))
        },
        CommandVerb("publish", "<id>", "Publishes a spot of your spots folder to the store. Only the Store spot can run it, so a person publishes from the Store spot.", rule: CallRule(use: .account, used: "published a spot", inShow: .changes("changes the store"), flags: .reachesKey)) { $0.one.map(Self.publish) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = StoreCalls(places: context.places, app: context.app)
        return switch self {
        case .list(let form): calls.list(form)
        case .get(let id, let isConfirmed, let clash): calls.get(id, isConfirmed: isConfirmed, clash: clash)
        case .update(let id, let isConfirmed): calls.update(id, isConfirmed: isConfirmed)
        case .revert(let id, let isConfirmed): calls.revert(id, isConfirmed: isConfirmed)
        case .publish(let id): calls.publish(id, account: context.account, caller: context.caller)
        case .add(let path): calls.add(path)
        case .remove(let path): calls.remove(path)
        case .folders(let form): calls.folders(form)
        case .open(let id, let search): calls.open(id, search: search)
        }
    }
}
