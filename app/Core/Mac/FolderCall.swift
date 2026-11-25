import Foundation

public enum FolderCall: NounCall {
    case pick

    static let noun = CommandNoun("folder", group: .mac, verbs: [
        CommandVerb("pick", "", "Prints the folder the person picks, or nothing after Cancel.", rule: CallRule(inShow: .waits, flags: .events)) { $0.none ? Self.pick : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { [pick = context.mac.pickFolder, app = context.app] in
            guard let pick else { return CommandAnswer(output: "") }
            let folder = if let app { await app.pickFolder(pick) } else { await pick() }
            return CommandAnswer(output: folder.map { $0.path + "\n" } ?? "")
        }
    }
}
