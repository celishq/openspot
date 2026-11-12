import Foundation

/// The calls of `openspot check`: the faults of a sheet on stdin, and the faults of a spots folder.
struct CheckCalls {
    let input: @Sendable () async -> String
    let environment: [String: String]
    /// The record of the app, which knows each read of a check as its spot's, or nil in a process of its own.
    var tokens: CallerTokens?

    func sheet() -> CommandAPI.Work {
        { [input] in
            let faults = SpotOutput(text: await input()).sheetFaults
            let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
            return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
        }
    }

    /// Reports the faults of a folder, or of the standard one, in lines or as JSON, and exits with 1 when there are any. A
    /// relative folder starts in the working folder of the caller. `careful` is the most uses that Careful mode leaves each
    /// read, or nil to run each one as the person (protocol: Trust).
    func folder(_ path: String?, json: Bool, careful: Set<SpotUse>?) -> CommandAPI.Work {
        { [environment, tokens] in
            let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
            let folder = path.map { SpotFolder(url: URL(fileURLWithPath: $0, isDirectory: true, relativeTo: place).absoluteURL) } ?? .standard(environment: environment)
            let findings = await SpotCheck(folder: folder, careful: careful, tokens: tokens).findings()
            guard !json else { return CommandAnswer(output: SpotCheck.json(findings), code: findings.isEmpty ? 0 : 1) }
            let summary = findings.isEmpty ? "No faults in \(folder.url.path)." : "\(findings.count) faults in \(folder.url.path)."
            return CommandAnswer(output: findings.map { $0.line + "\n" }.joined() + summary + "\n", code: findings.isEmpty ? 0 : 1)
        }
    }
}
