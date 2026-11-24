import Foundation

extension ScriptProcess {
    static let appVariables: Set<String> = ["OPENSPOT_EDIT", "OPENSPOT_EDIT_FILE", "OPENSPOT_EDIT_FAILURE", "OPENSPOT_CONFIG", "OPENSPOT_SPOTS"]

    convenience init(spot: Spot, program: URL, swift: SwiftProgram, sending message: Message?, limit: TimeInterval?, stopPause: TimeInterval = 2, variables: [String: String] = [:], errorLimit: Int? = 64 * 1024, careful: Set<SpotUse>?, base: [String: String]?, folder: URL? = nil, clock: RunClock = RunClock()) {
        self.init(
            url: program, name: spot.url.path, arguments: message.map { [$0.handler] } ?? [], mode: message.map { .once(input: $0.text) } ?? .stays,
            limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: variables.merging([CallWords.spotVariable: spot.id]) { given, _ in given },
            withheld: spot.isBuiltIn ? [] : Self.appVariables,
            errorLimit: errorLimit, careful: careful, base: base, folder: folder, clock: clock, build: swift.build(of: spot)
        )
    }
}
