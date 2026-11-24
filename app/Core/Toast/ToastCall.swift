import Foundation

enum ToastCall: NounCall {
    case show(String)
    case blocks
    case remove(String)

    static let noun = CommandNoun("toast", group: .build, verbs: [
        CommandVerb("remove", "<id>", "Takes the toast of the spot with the id away.", rule: CallRule(flags: .needsApp)) { $0.one.map(Self.remove) },
        CommandVerb("", "[words...]", "Shows a short message, even when the panel is closed. With no words, it reads a block on stdin: `toast=<id>`, its `title`, `keep=true` to keep it until a click, and `action`, the action of the spot that a click runs. It works in a show too.", rule: CallRule(flags: .needsApp)) { words in
            words.none ? Self.blocks : Self.show(words.rest.joined(separator: " "))
        }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard self == .blocks else { return rule }
        var rule = rule
        rule.flags.insert(.readsInput)
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .show(let text):
            return SpotEffect.toast(ToastNote(words: text)).work(in: context, name: "toast")
        case .remove(let id):
            return SpotEffect.dropToast(id).work(in: context, name: "toast remove")
        case .blocks:
            return {
                let note: ToastNote
                do {
                    note = try ToastNote(blocks: await context.input())
                    if let action = note.action {
                        guard let spot = context.caller else { throw SpotError.fault("`action` of a toast runs an action of its spot, so send the toast from a spot.") }
                        _ = try spot.action(action)
                    }
                } catch {
                    return CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 2)
                }
                return await SpotEffect.toast(note).work(in: context, name: "toast")()
            }
        }
    }
}
