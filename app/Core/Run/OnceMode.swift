import Foundation

@MainActor
class OnceMode: ScriptMode {
    weak var run: SpotRun?
    private let runs: SpotRuns
    private let asking = AskingCalls()

    required init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asking.isAsking
    }

    class var answersInApp: Bool {
        false
    }

    class func frames(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables: [String: String], call: OpenCall?, in runs: SpotRuns) -> Frames {
        runs.process(of: spot, message, limit: limit, reason: reason, variables: variables, call: call)
    }

    func send(_ call: OpenCall) -> Bool {
        guard let run else { return false }
        let request = call.request
        let made = call.made
        let spot = run.spot
        let values = run.fieldValues
        let (stream, halt, process) = runs.mode(of: run.spot).frames(of: run.spot, run.message(of: request, values: values), limit: request.limit, reason: request.event?.rawValue, variables: [:], call: call, in: runs)
        made.halt = halt
        asking.open(call, in: run)
        Task { [weak run, runs, asking] in
            var end = ScriptCall.End.ended
            do {
                for try await frame in stream {
                    guard !made.isStopped else { break }
                    runs.add(frame, to: &call.frames)
                    let next = await FrameStream.next(frame, after: call.drawn)
                    call.drawn = next.drawn
                    let lines = await runs.intake(next.text, of: spot)
                    guard !made.isStopped else { break }
                    guard let run else { continue }
                    await run.take(next.text, lines, of: call)
                    if case .ask(.show) = request.purpose, lines.isPicture, !run.isWanted, !made.isStopped { run.stop(made) }
                }
            } catch {
                end = .failed(error)
            }
            runs.dropFinished()
            if let failed = process?.failedFrame { call.frames.append(failed) }
            await asking.close(call, made.isStopped ? .stopped : end, errors: process?.errors ?? "", in: run)
        }
        return true
    }
}
