import Foundation

extension ScriptProcess {
    convenience init(spot: Spot, program: URL, swift: SwiftProgram, sending action: SpotAction?, input: String?, limit: TimeInterval?, stopPause: TimeInterval = 2, variables: [String: String] = [:], errorLimit: Int? = 64 * 1024, careful: Set<SpotUse>?, base: [String: String]?, folder: URL? = nil) {
        let sent = action?.sent(input: input)
        self.init(
            url: program, name: spot.url.path, arguments: sent?.arguments ?? [], mode: sent.map { .once(input: $0.input) } ?? .stays,
            limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: variables.merging([CallWords.spotVariable: spot.id]) { given, _ in given },
            errorLimit: errorLimit, careful: careful, base: base, folder: folder, build: swift.build(of: spot)
        )
    }
}
