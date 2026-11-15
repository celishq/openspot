import Foundation

public enum FolderCall: NounCall {
    case pick

    static let noun = CommandNoun("folder", verbs: [
        CommandVerb("pick", "", "Prints the folder the person picks, or nothing after Cancel.", rule: CallRule(read: .waits)) { $0.none ? Self.pick : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { [mac = context.mac] in CommandAnswer(output: await mac.pickFolder()) }
    }
}
