import Foundation

public enum ColorCall: NounCall {
    case pick

    static let noun = CommandNoun("color", verbs: [
        CommandVerb("pick", "", "Prints the colour the person picks.", rule: CallRule(use: .screen, used: "picked a colour on the screen", read: .waits, flags: .events)) { $0.none ? Self.pick : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        { [pick = context.mac.pickColor] in CommandAnswer(output: await pick?().map { $0.text + "\n" } ?? "") }
    }
}
