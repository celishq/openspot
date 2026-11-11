import Foundation

/// The call of `openspot check --sheet` that Core answers: the faults of a sheet on stdin.
struct CheckCalls {
    let input: @Sendable () async -> String

    func sheet() -> CommandAPI.Work {
        { [input] in
            let faults = SpotOutput(text: await input()).sheetFaults
            let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
            return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
        }
    }
}
