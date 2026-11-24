import Foundation

enum SpotEffect: Equatable, Sendable {
    case toast(ToastNote)
    case dropToast(String)
    case select(String)
    case route(FlowMove)
    case attachment(AttachmentValue)
}

extension SpotEffect {
    func work(in context: CallContext, name: String) -> CommandAPI.Work {
        guard let runs = context.runs else { return CommandAnswer.notRunning(name) }
        let caller = context.request.caller
        return {
            guard await runs.take(self, from: caller) else {
                return CommandAnswer(errors: "The panel shows no sheet. Open a spot, then run `openspot \(name)` again.\n", code: 1)
            }
            return CommandAnswer()
        }
    }
}
