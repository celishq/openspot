import Foundation

struct CheckCalls {
    let input: @Sendable () async -> String
    let places: AppPlaces
    let place: URL
    var callers: SpotCallers?

    func sheet() -> CommandAPI.Work {
        { [input] in
            let faults = FrameCheck(text: await input()).sheetFaults
            let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
            return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
        }
    }

    func folder(_ path: String?, form: PrintForm, careful: Set<SpotUse>?) -> CommandAPI.Work {
        { [places, place, callers] in
            let folder = path.map { SpotsFolder(url: URL(fileURLWithPath: $0, isDirectory: true, relativeTo: place).absoluteURL) } ?? places.spots
            let findings = await SpotCheck(folder: folder, careful: careful, callers: callers).findings()
            return CommandAnswer(output: (try? form.text(of: findings)) ?? "", code: findings.isEmpty ? 0 : 1)
        }
    }
}
