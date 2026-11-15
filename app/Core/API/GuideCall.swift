import Foundation

enum GuideCall: NounCall {
    case text

    static let noun = CommandNoun("guide", verbs: [
        CommandVerb("", "", "Prints the guide to building a spot. Read it before you write one.") { $0.none ? Self.text : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        CommandAnswer.work { [mac = context.mac] in
            guard let guide = mac.guide else { throw SpotError.fault("This copy of Openspot has no guide. Install Openspot again.") }
            return try String(contentsOf: guide, encoding: .utf8)
        }
    }
}
