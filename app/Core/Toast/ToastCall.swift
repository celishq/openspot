import Foundation

enum ToastCall: NounCall {
    case show(ToastNote.Source)
    case remove(String)

    static let noun = CommandNoun("toast", group: .build, verbs: [
        CommandVerb("--remove", "<id>", "Takes the toast of the spot with the id away.", rule: CallRule(flags: .needsApp)) { $0.one.map(Self.remove) },
        CommandVerb(
            "", "[--id <id>] [--action <name>] [--class <classes>] [--view <blocks>] <words>...",
            "Shows a short message, even when the panel is closed. --id names it, so a later toast with the same id changes it in place. It leaves 5 seconds after it shows, or 5 seconds after the pointer leaves it. --action names the action of the spot that a click runs. --view draws Openspot's own blocks in place of the words, and --class lays them out. It works in a show too.",
            rule: CallRule(flags: .needsApp)
        ) { words in
            guard let fit = words.fit, !fit.rest.isEmpty else { return nil }
            return Self.show(ToastNote.Source(
                words: fit.rest.joined(separator: " "), id: fit.value("--id"),
                action: fit.value("--action"), classes: fit.value("--class"), view: fit.value("--view")
            ))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .remove(let id):
            return SpotEffect.dropToast(id).work(in: context, name: "toast --remove")
        case .show(let source):
            let note: ToastNote
            do {
                note = try ToastNote(source)
                if let action = note.action {
                    guard let spot = context.caller else { throw SpotError.fault("`--action` of a toast runs an action of its spot, so send the toast from a spot.") }
                    _ = try spot.action(action)
                }
            } catch {
                return { CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 2) }
            }
            return SpotEffect.toast(note).work(in: context, name: "toast")
        }
    }
}
