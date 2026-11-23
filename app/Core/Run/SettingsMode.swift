import Foundation

@MainActor
final class SettingsMode: OnceMode {
    override class var answersInApp: Bool {
        true
    }

    override class func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames {
        let settings = spot.settingsSheet
        let (stream, halt) = runs.answered { try settings?.answer(message.words.arguments, input: message.text) ?? "" }
        return (stream, halt, nil)
    }
}
