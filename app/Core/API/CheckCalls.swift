import Foundation

struct CheckCalls {
    let input: @Sendable () async -> String
    let environment: [String: String]
    var tokens: CallerTokens?

    func sheet() -> CommandAPI.Work {
        { [input] in
            let faults = SpotOutput(text: await input()).sheetFaults
            let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
            return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
        }
    }

    func folder(_ path: String?, json: Bool, careful: Set<SpotUse>?) -> CommandAPI.Work {
        { [environment, tokens] in
            let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
            let folder = path.map { SpotsFolder(url: URL(fileURLWithPath: $0, isDirectory: true, relativeTo: place).absoluteURL) } ?? .standard(environment: environment)
            let findings = await SpotCheck(folder: folder, careful: careful, tokens: tokens).findings()
            guard !json else { return CommandAnswer(output: SpotCheck.json(findings), code: findings.isEmpty ? 0 : 1) }
            let summary = findings.isEmpty ? "No faults in \(folder.url.path)." : "\(findings.count) faults in \(folder.url.path)."
            return CommandAnswer(output: findings.map { $0.line + "\n" }.joined() + summary + "\n", code: findings.isEmpty ? 0 : 1)
        }
    }
}
