import Foundation

public struct CommandVerb: Sendable {
    public let words: [String]
    public let form: String
    public let about: String
    public let rule: CallRule
    let slots: [CommandSlot]
    let shape: CommandForm
    let parse: @Sendable (CallWords) -> (any NounCall)?

    init(_ words: String = "", _ form: String = "", _ about: String = "", rule: CallRule = CallRule(), parse: @escaping @Sendable (CallWords) -> (any NounCall)?) {
        self.words = words.split(separator: " ").map(String.init)
        self.form = form
        self.about = about
        self.rule = rule
        slots = CommandSlot.slots(of: form)
        shape = CommandForm(slots)
        self.parse = parse
    }

    func matches(_ rest: [String]) -> Bool {
        rest.count >= words.count && Array(rest.prefix(words.count)) == words
    }
}
