import Foundation

public enum FolderCall: NounCall {
    case pick

    static let noun = CommandNoun("folder", verbs: [
        CommandVerb("pick", "", "Prints the folder the person picks, or nothing after Cancel.", rule: CallRule(read: .waits, flags: .events)) { $0.none ? Self.pick : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { [pick = context.mac.pickFolder] in CommandAnswer(output: await pick?().map { $0.path + "\n" } ?? "") }
    }
}
