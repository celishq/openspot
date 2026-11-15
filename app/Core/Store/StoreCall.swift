import Foundation

enum StoreCall: NounCall {
    case list(PrintForm)
    case get(String)
    case publish(String)

    static let noun = CommandNoun("store", verbs: [
        CommandVerb("list", "[--frame]", "Prints each spot of the store, and whether you have it.", rule: CallRule(use: .spots, used: "read the store")) { words in
            words.form.map(Self.list)
        },
        CommandVerb("get", "<id>", "Gets a spot of the store: turns it on, or adds it to your spots folder.", rule: CallRule(use: .spots, used: "added a spot", read: .changes("changes your spots"))) { $0.one.map(Self.get) },
        CommandVerb("publish", "<id>", "Publishes a spot of your spots folder to the store. Only the Store spot can run it, so a person publishes from the Store spot.", rule: CallRule(use: .account, used: "published a spot", read: .changes("changes the store"), flags: .reachesKey)) { $0.one.map(Self.publish) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = StoreCalls(environment: context.environment, app: context.app)
        return switch self {
        case .list(let form): calls.list(form)
        case .get(let id): calls.get(id)
        case .publish(let id): calls.publish(id, account: context.account, caller: context.keyCaller)
        }
    }
}
