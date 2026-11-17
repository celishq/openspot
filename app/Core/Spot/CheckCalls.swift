import Foundation

struct CheckCalls {
    let input: @Sendable () async -> String
    let environment: [String: String]
    let place: URL
    var tokens: CallerTokens?

    func sheet() -> CommandAPI.Work {
        { [input] in
            let faults = FrameCheck(text: await input()).sheetFaults
            let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
            return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
        }
    }

    func folder(_ path: String?, form: PrintForm) -> CommandAPI.Work {
        { [environment, place, tokens] in
            let folder = path.map { SpotsFolder(url: URL(fileURLWithPath: $0, isDirectory: true, relativeTo: place).absoluteURL) } ?? .standard(environment: environment)
            let findings = await SpotCheck(folder: folder, tokens: tokens).findings()
            return CommandAnswer(output: (try? form.text(of: findings)) ?? "", code: findings.isEmpty ? 0 : 1)
        }
    }
}
