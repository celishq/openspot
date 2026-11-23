import Foundation

@MainActor
final class HostMode: OnceMode {
    override class var answersInApp: Bool {
        true
    }

    override class func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames {
        let (sheet, id, base) = (spot.host, spot.id, runs.environment)
        let (stream, halt) = runs.answered { [weak runs] in
            guard let sheet else { return "" }
            let answer = try await sheet.answer(message.words.arguments, input: message.text, base: base)
            for effect in answer.effects { await runs?.take(effect, of: id, call: call) }
            return answer.frame
        }
        return (stream, halt, nil)
    }
}
