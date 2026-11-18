import Foundation

@MainActor
final class OnceLink: ScriptLink {
    weak var run: SpotRun?
    private let runs: SpotRuns
    private var asking: [ScriptCall] = []

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asking.contains { !$0.isStopped }
    }

    func send(_ call: OpenCall) -> Bool {
        guard let run else { return false }
        let request = call.request
        let made = call.made
        let id = run.spot.id
        let values = run.fieldValues
        let (stream, halt, process) = runs.frames(of: run.spot, request.action, input: run.message(of: request, values: values), limit: request.limit, reason: request.reason?.rawValue, call: call)
        made.halt = halt
        if case .ask(let ask) = request.purpose, !ask.isAnswer { asking.append(made) }
        run.track(made)
        Task { [weak self, weak run, runs] in
            var end = ScriptCall.End.ended
            do {
                for try await frame in stream {
                    guard !made.isStopped else { break }
                    runs.add(frame, to: &call.frames)
                    let next = await FrameStream.next(frame, after: call.drawn)
                    call.drawn = next.drawn
                    let lines = await runs.intake(next.text, of: id)
                    guard !made.isStopped else { break }
                    guard let run else { continue }
                    await run.take(next.text, lines, of: call)
                    if case .ask(.read) = request.purpose, lines.isPicture, !run.isWanted, !made.isStopped { run.stop(made) }
                }
            } catch {
                end = .failed(error)
            }
            runs.dropFinished()
            if let failed = process?.failedFrame { call.frames.append(failed) }
            let last = made.isStopped ? .stopped : end
            await run?.takeEnd(of: call, last)
            self?.asking.removeAll { $0 === made }
            run?.finish(call, last, errors: process?.errors ?? "")
        }
        return true
    }
}
