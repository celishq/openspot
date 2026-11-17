import Foundation

@MainActor
final class OpenCall {
    var request: SpotRun.Call
    let made: ScriptCall
    let begin = Date()
    var frames: [String] = []
    var hasAnswer = false
    var answered: TimeInterval?
    var showedPicture = false
    var lastHead: SpotOutput?
    var pushed: SpotOutput?
    var selected: String?
    var form = SpotOutput.empty

    init(_ request: SpotRun.Call, started: Date) {
        self.request = request
        made = ScriptCall(action: request.action, key: request.key, started: started)
    }

    nonisolated deinit {}
}
